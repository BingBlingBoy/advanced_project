= Cache Set

== Physical Silicon ID
This is for physical geometry of the cache, so it is good for our heat maps.
- 1 Cache Block (Line): 64 bytes
- Associativity: 16 ways (blocks) per Set
- 1 Set Capacity: 64×16=1024 bytes (1 KiB)
- Your Target Chunk Size: 4096 bytes (4 KiB)

Because every Set holds exactly 1 KiB of data, it takes exactly 4 Sets to equal a 4KiB chunk of silicon.

== Logical Data ID
Page Coloring: To prevent conflicts in the cache (where two different virtual pages map to the same set), the OS can use "page coloring." This ensures that when physical memory is allocated, the pages are assigned to physical frames that map to different cache sets.

This tracks the data itself, so we can identify the exact cache set ID to the raw physical address.
Operating system pages are 4KiB so the OS stamps it with a unique ID.
By doing the `>> 12` operation, we chop off the bottom 12 bits to get this unique ID.

This is to prevent the example scenario.

Disaster 1: The "Amnesiac Tracker" (If you only use the Physical Set)

Imagine you try to track the saturation counters using the physical cacheSet.

+ The Setup: The OS sends a 4KiB page of data. The default math puts it in Set 800 (High Retention).
+ The Counting: The CPU writes to it 15 times. Your counter for Set 800 hits saturation. You trigger the redirection.
+ The Move: The 4KiB chunk is redirected to Set 15 (Low Retention).
+ The Disaster: The CPU writes to that data again. Because it is now physically in Set 15, your code looks for a counter attached to Set 15. It sees "0 writes" and thinks this is completely cold data!

By tying your tracking to the physical location, the data effectively got "amnesia" the moment it moved. To accurately track a 4KiB chunk of data, the counter must be tied to the data's permanent OS Page ID (addr >> 12), regardless of where the cache hides it.

This is to prevent innocent readers from being marked as a heavy writer due to the natural assignment of set 800 being marked with a saturation counter of 15 and being redirected to a lower zone, even though it only has one write.

= Inter-zone Redirection

== Saturating Counters
Standard integers overflow back to 0 when they max out, causing the cache to "forget" that a block is a heavy writer. gem5's SatCounter8 physically mimics a 4-bit hardware counter that stops at 15. Once a block hits 15 writes, it is permanently flagged as a power-hog until it is explicitly reset.

== Lazy Migration
Moving 4KiB of data across the cache instantly takes massive power and stalls the CPU. Instead, we use "Lazy Migration." We change the mapping rules for future allocations, but for existing data, we tell the cache to look in the new Low Retention set first, and if it misses, take a peek in the old High Retention set.

== Changes Summary
1. CacheMemory.hh (The Trackers)
    - Include: `#include "base/sat_counter.hh"`
    - Add Trackers: Create two std::unordered_map structures. One to hold the SatCounter8 for each OS Page, and one to hold the redirection offsets (the m_chunk_redirection_table).
    - Add Helper: Create a getDefaultSet(address) function that preserves the original bitSelect math so you always know where a block used to live.

2. CacheMemory.cc
- addressToCacheSet(): Completely replace the math. Extract the Logical Data ID (addr >> 12). If it exists in the redirection table, apply the offset and use modulo (%) to force the set into the Low Retention zone. If not, return the getDefaultSet().

- recordRequestType() (Write Case): Extract both the osPageID and the siliconChunkID.

  - Increment the SatCounter8 tied to the osPageID.

  - If it saturates, assign a pseudo-random offset in the m_chunk_redirection_table.

  - Log the physical write stats using siliconChunkID to keep your heatmaps accurate.

- lookup() and deallocate(): Implement the "Two-Look" method. Calculate the current targetSet. If the tag isn't there, calculate the defaultSet. If they are different, check the defaultSet to see if the data is a "ghost" waiting to be migrated or deleted.



