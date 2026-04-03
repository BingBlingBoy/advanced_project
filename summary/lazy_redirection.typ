= Lazy Redirection

== Core Concept
To transfer writes from high retentions sets into the low retention ones.
Things that were added were:
+ Page-level tracking: divided memory addresses into 4KB chunks and gave each chunk a 4-bit sat counter.
+ Redirection table: `unordered_map` to store offsets.
+ Once the sat counters hit 15 writes, register it in the redirection table. Future traffic for that specific page is shifted from the HR zone to the LR zone.

== Errors

=== Tag Aliasing Bug
`panic: Invalid transition M, Exclusive_Unblock`
A block expired in the HR zone.
Later, an unblock receipt arrived.
The router saw it was expired and said to check the LR zone.
The search function blindly grabbed whatever block was sitting in that LR slot and handed it to the SLICC state machine. SLICC panicked because it handed it a totally random block in the M (Modified) state.

The fix was to strictly verify if `m_cache[cacheSet][way]->m_Address == tag` before returning a pointer.

=== Network Race Condition
`panic: Invalid transition NP, Exclusive_Unblock`
A block was written and the L2 sent data to L1.
It was processed and send an `Exclusive_Unblock` back but it expired in the L2.
It recieved a `Not present` and SLICC didn't know what to do with the late reciept.

The fix was to add `transition(NP, Exclusive_Unblock) { k_popUnblockQueue; }` to the `.sm` file to throw away late reciepts.

=== Deadlock
By allowing L2 blocks to naturally expire and die, we were destroying the directory state. The L1 had data, but the L2 forgot about it.


== Final Functions

=== Lookup
```
  if (m_cache_level_call != "L2cache" &&
      entry->m_Permission != AccessPermission_Busy) {
    if (curTick() > (entry->m_last_refresh_tick + entry->m_retention_limit)) {
      entry->m_is_expired = true;
    }
  }
```
What it does: Acts as the universal physics engine for STT-RAM magnetic decay across all cache levels. Every time a block is touched, it checks the physical retention timer. If the magnetic charge has faded—and the block isn't currently Busy waiting for a network packet—it flags the block as a "zombie" (m_is_expired = true). Because we removed the m_cache_level_call check, the L2 Directory LLC now fully obeys physical expiration timers.

The Error it Prevents / The Purpose: Safe Volatile Expiration for the LLC. Originally, allowing the L2 to expire caused the "L2 Amnesia" deadlock because expired blocks were hidden from SLICC. Because we fixed findTagInSet to keep expired zombies visible, we no longer need the L2 guard band-aid.

=== recordRequestType
```
// Guard check
if (m_lazy_redirection_scheme) {
  // Map Initialization
  if (m_chunk_counters.find(addr_chunk_ID) == m_chunk_counters.end()) {
    m_chunk_counters.emplace(addr_chunk_ID, SatCounter8(4));
  }

  // Count and Trigger
  if (m_chunk_redirection_table.find(addr_chunk_ID) == m_chunk_redirection_table.end()) {
    m_chunk_counters.at(addr_chunk_ID)++;

    if (m_chunk_counters.at(addr_chunk_ID).isSaturated()) {
      int max_lr_set = m_thresholds[1];
      int offset = addr_chunk_ID % max_lr_set;
      m_chunk_redirection_table[addr_chunk_ID] = offset;
    }
  }
}
```
Strictly updating the math offset rather than trying to physically teleport pointers from HR to LR sets mid-cycle, it prevents the OS Spinlock/Deadlock where the CPU loses track of critical locks if the LR set happens to be full.

=== addressToCacheSet
```
if (redir_it != m_chunk_redirection_table.end()) {
    int max_lr_set = m_thresholds[1];
    int64_t redirected_set = (default_set + redir_it->second) % max_lr_set;

    auto tag_it = m_tag_index.find(address);
    if (tag_it != m_tag_index.end()) {
      int way = tag_it->second;

      // 1. The "Find the Dead Body" Check
      if (m_cache[default_set][way] != nullptr &&
          m_cache[default_set][way]->m_Address == address) {
        return default_set;
      }
    }
    // 2. The Clean Redirect
    return redirected_set;
  }
```
What it does: If a page is marked for redirection, it checks the old High Retention (default_set). If the block is physically sitting there, it routes traffic to it. If the block is gone (evicted), it routes all new traffic to the redirected_set.

=== findTagInSet
```
if (m_cache[cacheSet][way] != nullptr &&
m_cache[cacheSet][way]->m_Address == tag) {
  return way;
}
```
What it does: Provides strict address verification. It ensures that the physical address inside the cache block actually matches the tag the CPU is looking for before returning the way-index. Crucially, it returns this location even if the block is expired.

The Error it Prevents: The Tag Aliasing Bug. This prevents the panic: Invalid transition M, Exclusive_Unblock crash. Before this strict check, if the router pointed to the LR zone but the block hadn't been allocated there yet, this function would blindly return whatever random block was sitting in that index. It handed SLICC the wrong block, causing the state machine to panic.
