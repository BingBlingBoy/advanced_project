= New Redirection
I have made a lot of changes to make it more optimised.

== Spatial Interleaving (Eliminating the "Capacity Funnel")
An OS page is 4KiB, so one page consists of 64 Cache blocks.
The original design when a 4KiB page was redirected all 64 blocks were mapped to a single `base_set` and forced to walk within a tiny 4-set and 8-set window.
Since a 16-way associative cache can only hold 64 blocks across 4 sets, 100% of the page's traffic into a space that exactly fit, it causes massive hardware bank contention and capacity thrashing.

Changes include `addressToCacheSet`, `findTagInSet` and `findTagInSetPermissions`
```c++
// 1. Extract the specific block's offset within the 4KiB page (values 0 to 63)
int block_offset = (address >> 6) & 0x3F;

// 2. Multiply by a prime number (7) to distribute the blocks mathematically 
// across the entire zone_size, rather than clumping them together.
int scatter_offset = (redir_it->second + (block_offset * 7)) % zone_size;

if (default_set >= m_thresholds[2]) {
  base_set = m_thresholds[0] + scatter_offset; 
} else if (default_set >= m_thresholds[1]) {
  base_set = scatter_offset; 
}
```

== $Omega(1)$ Fast-Path Cache Misses
Performing hashmap lookups, `std::unordered_map::find`, and modulo arithmetic inside `for` loop takes millions of CPU cycles on the host machine.
Cache misses happen constantly, your search functions were executing 8 expensive loop iterations figuring out if the data isn't there.

Changes include `findTagInSet` and `findTagInSetPermissions`
```c++
int CacheMemory::findTagInSet(int64_t &cacheSet, Addr tag) const {
  assert(tag == makeLineAddress(tag));

  // OPTIMIZATION: O(1) Fast-Path Miss
  auto it = m_tag_index.find(tag);
  if (it == m_tag_index.end()) {
    return -1; // Instantly abort. Zero loops, zero math.
  }
  
  // If we survive the check, we already know the 'way' index!
  int way = it->second; 
  // ... proceed with math to verify the physical set ...
```

== The "two-look" pass-by-reference fix (SLICC panics)
Due to lazy migration, newly directed blocks write to the LR zone, but old dirty data stays in the HR zone until it naturally dies.
To find the old data it must look into two zones.
However, originally, `findTagInSet` received `cacheSet` as a value copy.
Even if it found the data in the old zone, it couldn't tell the `lookup()` function the actual physical set it found it in.
SLICC was handed a pointer to the wrong physical set, resulting in a NULL pointer dereference and a Segmentation Fault.

The Code Change:
We changed the function signatures in `CacheMemory.hh` and `CacheMemory.cc` to pass `cacheSet` by reference (`&`), and explicitly updated it upon a successful hit.

```c++
// Passed by reference (&)
int CacheMemory::findTagInSet(int64_t &cacheSet, Addr tag) const {
  // ... target zone loops ...
  
  // 2nd Look: Scanning the ORIGINAL zone
  if (target_base_set != default_set) {
    // ...
    for (int i = 0; i <= 7; i++) {
      int check_set = orig_zone_start + ((orig_local + i) % zone_size);
      
      if (m_cache[check_set][way] != nullptr &&
          m_cache[check_set][way]->m_Address == tag &&
          m_cache[check_set][way]->m_Permission != AccessPermission_NotPresent) {

        cacheSet = check_set; // <--- CRITICAL FIX: Update the caller's variable
        return way;
      }
    }
  }
}
```

== Wide-stride Intra-set Walking
The original design forced a block to step to the next set every 4 writes (`writes / 4`), bounded to a maximum of 4 sets (`i <= 3`).
This provided a very narrow "thermal buffer" for the STT-RAM.

A hot block now migrates across 8 physical sets instead of 4, cutting the localized thermal density in half and severely reducing the chance of intra-set conflict misses.


== The "Busy Zombie" Livelock Protection
When the cache needs to evict a block (`cacheProbe`), it looks for expired blocks or uses LRU.
The standard LRU policy views blocks currently waiting for data from Main Memory (`State: AccessPermission_Busy`) as the "oldest" blocks.
The cache was endlessly evicting blocks that were actively loading, resulting in a 0-instruction Coherence Livelock where the CPU was completely frozen.

Code changes, we explicitly banned `AccessPermission_Busy` from both victim selection pools in `cacheProbe`.

```c++
Addr CacheMemory::cacheProbe(Addr address) const {
  // ...
  // 1. Safe Expired Block Eviction
  for (int i = 0; i < m_cache_assoc; i++) {
    if (m_cache[cacheSet][i] && m_cache[cacheSet][i]->m_is_expired &&
        m_cache[cacheSet][i]->m_Permission != AccessPermission_Busy) { // <-- Excluded
      return m_cache[cacheSet][i]->m_Address;
    }
  }

  // 2. Safe LRU Fallback
  std::vector<ReplaceableEntry *> candidates;
  for (int i = 0; i < m_cache_assoc; i++) {
    // Only push blocks to the LRU pool if they are NOT waiting for memory
    if (m_cache[cacheSet][i] && 
        m_cache[cacheSet][i]->m_Permission != AccessPermission_Busy) { // <-- Excluded
        candidates.push_back(static_cast<ReplaceableEntry *>(m_cache[cacheSet][i]));
    }
  }
  // ...
}
```

The L2 cache strictly respects in-flight memory requests. Blocks are guaranteed to finish loading before they can be evaluated for eviction, breaking the infinite loop and allowing instructions to process.
