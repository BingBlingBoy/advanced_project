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

= 4 Retention

== Main Code
Implementation was quite simple to integrate with the existing code, since I just need to append the bonus retentions to the `m_retention_table` and identify if the hardware is STT-RAM with this flag `m_is_sttram`.
If `m_is_sttram = false`, then it will default to the original gem5 code for SRAM.

#code-box(title: "New Code")[
  ```cpp
  ...
  // Retention Zone Table tests
  if (m_num_of_retention_zones == 1) {
    m_retention_table.push_back(m_low_retention);
    m_low_retention_zone_type = p.low_retention_type;
  } else if (m_num_of_retention_zones == 2) {
    m_retention_table.push_back(m_low_retention);
    m_low_retention_zone_type = p.low_retention_type;
    m_retention_table.push_back(m_high_retention);
  } else {
    m_retention_table.push_back(m_low_retention);
    m_retention_table.push_back(m_mediumlow_retention);
    m_retention_table.push_back(m_mediumhigh_retention);
    m_retention_table.push_back(m_high_retention);
  }
  ...

  if (!m_is_sttram) {
    set[i]->m_retention_limit = 0;
  } else {
    int retention_threshold = getRetentionZone(cacheSet);
    Tick total_retention_time = m_retention_table[retention_threshold].time;
    set[i]->m_retention_limit = total_retention_time;
    // std::cout << "Set retention limit: " << set[i]->m_retention_limit
    //           << '\n';
  }

  ...
  ```
]

== Error
When expanding my custom retention zone code to 4 retention zones, I encounted another deadlock error where the outputs loop through this `Insts: 0 | Reads: 0 | Writes: 0`.
When the CPU asked SLICC for a piece of data, it checked its records, saw the data was there and went to fetch it.
However, the C++ side had already deleted it, which caused SLICC to freeze.

=== `allocate()`
With very short retention times (1ms), blocks expired instantly so C++ overwrote the blocks whenever a new address came along.
SLICC's Directory thought it still held the physical slot for the old data, but C++ killed it without telling SLICC.

#code-box(title: "Old allocate()")[
  ```cpp
  // BUG: If it's expired, C++ silently overwrites the block!
  if (!set[i] || set[i]->m_is_expired || set[i]->m_Permission == AccessPermission_NotPresent) {
      // ... overwrites the block with new data ...
  }
  ```
]

The new code doesn't do anything if `m_is_expired = true` until SLICC has officially dealt with it.


#code-box(title: "New allocate()")[
  ```cpp
  // FIXED: C++ only overwrites when SLICC officially says it is NotPresent.
  if (!set[i] || set[i]->m_Permission == AccessPermission_NotPresent) {
      // ... overwrites the block safely ...
  }
  ```
]

=== `cacheProbe()`
To officially get rid off expired code blocks, we need to change `cacheProbe` such that the cache doesn't fill up with expired blocks.
#code-box(title: "New cacheProbe()")[
  ```cpp
  // FIXED: C++ intercepts the eviction request and offers up the Zombies first!
  for (int i = 0; i < m_cache_assoc; i++) {
      if (m_cache[cacheSet][i] && m_cache[cacheSet][i]->m_is_expired) {
          return m_cache[cacheSet][i]->m_Address; 
      }
  }
  // (Falls back to LRU only if there are no Zombies)
  ```
]

=== `recordRequestType()`
The old code manually flipped the coherence permissions back to a valid state.
This should only have been kept on the SLICC side.

#code-box(title: "Old recordRequestType")[
  ```cpp
  // BUG: C++ hacks the state machine!
  entry->m_is_expired = false;
  entry->m_Permission = AccessPermission_Read_Write;
  ```
]

#code-box(title: "New recordRequestType")[
  ```cpp
  // FIXED: C++ only resets the physical magnet. It leaves permissions alone.
  entry->m_is_expired = false;
  entry->m_last_refresh_tick = curTick();
  ```
]
