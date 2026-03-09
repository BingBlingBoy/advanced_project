#let code-box(title: "", body) = {
  figure(
    block(
      width: 100%,
      fill: luma(240),
      inset: 10pt,
      radius: 4pt,
      stroke: 0.5pt + luma(200),
      align(left, body)
    ),
    caption: title,
    kind: "code",
    supplement: [Listing],
  )
}

= Custom Latencies


== Core Concept
gem5 by default always holds the data forever unless the cache gets full or a MESI protocol (`Shared`, `Modified`, `Invalid`) is called.
In order to simulate the magnetic tunnel junction (MTJ) and its properties these lines of code has to be implemented:
- `m_is_expired` - A boolean flag that acts as the physical health of the magnet. `false` indicates it's holding a strong charge and `true` is when the magnet has lost alignment and the data is corrupt.
- `m_retention_limit` - The maximum lifespan of the block based on it's Set-Partition zone.
- `m_last_refresh_tick` - The exact time the magnet was last zapped with write current.

== Functions

=== `lookup()`
Since gem5 SRAM doesn't decay, it doesn't need to check the health of a block.
By default, `CacheMemory.cc` searches the tag array and returns the pointer to the data. If the data is there, the data is good.

#code-box(title: "Default lookup()")[
  ```cpp
  int loc = findTagInSet(cacheSet, address);
  if (loc == -1) return NULL;
  return m_cache[cacheSet][loc];
  ```
]

We need to implement passive decay, which is done by seeing if the current tick (`curTick()`) exceeds `m_last_refresh_tick + m_retention_limit`.
If it evaluates to true, it will flag `m_is_expired = true`, which makes that block dead.

=== `allocate()`
The default code had the job of initialising the physics of the new block, and cleans up any bad ones.
When SLICC requested a new block, that block will start it's decay timer.
#code-box(title: "New allocate")[
  ```cpp
  // 1. Give it a retention limit based on its physical Set Location
  int retention_threshold = getRetentionZone(cacheSet);
  set[i]->m_retention_limit = m_retention_table[retention_threshold].time;

  // 2. Start the clock!
  set[i]->m_last_refresh_tick = curTick();
  set[i]->m_is_expired = false;
  ```
]

To handle garbage collection, I change the if statement such that if the block is expired, overwrite it.
#code-box(title: "New garbage collection")[
  ```cpp 
  // Your original search loop
  if (!set[i] || set[i]->m_is_expired || set[i]->m_Permission == AccessPermission_NotPresent) {
      // Overwrite the block!
  }
  ```
]

=== `cacheAvail()`
In the default code, `cacheAvail` is a capacity checker during a cache miss.
When the CPU requests data that isn't valid in the cache, the SLICC state machine must allocate space for it. Before fetching the data, SLICC calls `cacheAvail`.
- If `true`, then the cache has an empty slot for that specific set and allocates a temporary buffer (TBE) and requests data from memory.
- If `false`, then it must call `cacheProbe` to find a victim and trigger the formal replacement event to evict the victim to the Directory.

The old code worked by seeing if there is a slot in the cache (`NotPresent` or `NULL`) or if the address is already in the cache.
However, with my custom retention time, a miss can happen when the address is in the cache due to being it marked as dead.
SLICC overwrote the dead set without sending an eviction message to the directory.

#code-box(title: "Old cacheAvail")[
  ```cpp 
  // Old Code Snippet
  if (entry->m_Address == address || entry->m_Permission == AccessPermission_NotPresent) {
    return true;
  }
  ```
]

The new code removes `entry->m_address == address` in the case that the cache set is expired, so it only evaluates to true if the cache actually has space.
Otherwise, it will call `cacheProbe`

#code-box(title: "New cacheAvail")[
  ```cpp 
  if (entry->m_Permission == AccessPermission_NotPresent) {
    return true;
  }
  ```
]



=== `recordCacheContents()`
By default this function is for profiling and updating stats.

We need to change this such that it reflects STT-RAM properties.
Whenever a write occurs, we must reset the decay timer by changing `m_is_expired = false` and `m_last_refresh_tick` and applying the custom latencies.

== SLICC
There were a lot of issues when converting gem5 to custom latencies between the C++ and .sm files.


=== `deallocate`
After I changed the C++ code, a common error faced was this `assert` error, where it returned `NULL` if a block had decayed.
This meant that `isTagPresent(address)` returned `false` for expired blocks.
When `L1Cache.sm` tried to evict the expired block, it failed the `assert` since it got marked as dead.

#code-box(title: "Default Deallocate")[
  ```cpp
  // In C++ CacheMemory.cc
  AbstractCacheEntry *entry = lookup(address);
  assert(entry != nullptr); // <--- CRASHED HERE
  ```
]

#code-box(title: "Default L1Cache.sm")[
  ```cpp
  // In SLICC L1Cache.sm
  if (L1Dcache.isTagPresent(address)) { L1Dcache.deallocate(address); }
  else { L1Icache.deallocate(address); }
  ```
]

The new code now searches the hardware tag allowing it to find and delete dead STT-RAM cells.

#code-box(title: "New Deallocate")[
  ```cpp
  // In C++ CacheMemory.cc
  int loc = findTagInSetIgnorePermissions(cacheSet, address);
  if (loc != -1) { /* Safely delete without asserts */ }
  ```
]

#code-box(title: "New L1Cache.sm")[
  ```cpp
  // In SLICC L1Cache.sm
  L1Dcache.deallocate(address);
  L1Icache.deallocate(address);
  ```
]

=== TBE Corruption
In the default code, my changes caused it to copy invalid memory states during cache misses.
The TBE's roles is to temporarily hold data while the network routes request, so the original copied `DataBlk` into the TBE.
If `m_is_expired = true` or if it is a brand `State:NP` for that block, so the controller was copying mathematical garbage.

#code-box(title: "Default L1Cache.sm and L2Cache.sm")[
  ```cpp
  action(i_allocateTBE, "i", desc="Allocate TBE") {
    // ...
    tbe.DataBlk := cache_entry.DataBlk; // <--- DANGEROUS COPY
    tbe.Dirty := cache_entry.Dirty;
  }
  ```
]

=== `Protocol Deadlock`
The directory thought the L2 cache owned a block, but the C++ STT-RAM had decayed and dropped it.
When the Directory sent a recall request (`MEM_Inv`), the L2 was already to re-fetch the data (State `IM`).
The L2 was in a state of recycling the invalidation request from the Directory and this caused it to infinitely loop.

#code-box(title: "Default L2Cache.sm")[
  ```cpp
  transition({IM, IS, ISS, SS_MB, MT_MB, MT_IIB, MT_IB, MT_SB}, MEM_Inv) {
    zn_recycleResponseNetwork;
  }
  ```
]

We needed to change this, such that the L2 can handle these "Ghosts Recalls".
If the Directory asks for a block that's decayed or currently being fetched, the L2 sends a dummy acknowledgement (`c_exclusiveCleanReplacement`).
This untangles the Directory, allowing it to send the real data.


#code-box(title: "New L2Cache.sm")[
  ```cpp
  // Send a "Fast ACK" if we don't have the data
  transition({NP, IM, IS, ISS}, MEM_Inv) {
    c_exclusiveCleanReplacement; 
    o_popIncomingResponseQueue;
  }

  // Safely drop the Directory's "Thank you" message to the Fast ACK
  transition({NP, IM, IS, ISS}, Mem_Ack) {
    o_popIncomingResponseQueue;
  }
  ```
]

