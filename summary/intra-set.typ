= Intra-set Architecture

== Concept
Routing "hot" data to LR zones solves the total power problem, it introduces a power density problem.
When a memory page is heavily written to, it forces all the writes into a single physical cache set.
Getting all the writes into a single physical set generates a massive spike of localised electrical current, leading to thermal hotspot.

Intra-set walking allows the active page to walk across different set across a neighbourhood of physical sets, distributing the thermal load across a wider surface area.

== Mechanism

=== Hardware
A lightweight, 4-bit saturating counter is attached to each 4KB logical memory page.

=== Math
A router calculates a physical offset using integer division, `intra_offset = writes / 4`

=== Example
- Writes 0–3 route to the default set (Offset 0)
- Writes 4–7 step to the next adjacent set (Offset 1)
- Writes 8–11 step again (Offset 2)

=== Fixes
*Eliminating Thrash*. The baseline funnel violently shoved hot pages into the Low Retention zone instantly, causing an eviction storm that choked the CPU to 40,000 instructions.
The "Walk" acts as a pressure buffer.
By forcing the page to walk across four High Retention sets before jumping, it delays the traffic jam, giving the Low Retention blocks time to naturally expire.

The Bug: The routing logic treated the Inter-Zone Jump and the Intra-Zone Walk as mutually exclusive. If a page was redirected to the LR zone, it completely stopped walking.
This caused all the hot pages to violently pile up on Set 0 of the LR zone, triggering the massive eviction storm that choked the CPU to 40,000 instructions.

=== Before
```
// BUG: The router just returned the redirected set instantly. 
// It bypassed the "Walk" logic entirely, causing massive traffic jams.
if (redir_it != m_chunk_redirection_table.end()) {
    int64_t redirected_set = default_set; 
    if (default_set >= m_thresholds[2]) {
        redirected_set = m_thresholds[0] + redir_it->second; 
    }
    return redirected_set; // <--- EXITING TOO EARLY!
}
```

=== After
```
// FIX: Phase 1 only determines the BASE zone. It does not return.
int64_t base_set = default_set;
if (redir_it != m_chunk_redirection_table.end()) {
    if (default_set >= m_thresholds[2]) {
        base_set = m_thresholds[0] + redir_it->second; 
    }
}

// FIX: Phase 2 applies the Walk to EVERY zone, acting as a pressure buffer.
int64_t target_set = base_set;
int intra_offset = writes / 4; 
if (intra_offset > 0) {
    int zone_start = (base_set / zone_size) * zone_size;
    int local_index = base_set % zone_size;
    target_set = zone_start + ((local_index + intra_offset) % zone_size);
}
```


*Solving Coherence Deadlock*. The original router lost track of dirty blocks when they jumped zones while mid-walk.

The Bug: When SLICC asked for a block, the router only checked two static locations: the absolute original set, and the absolute new target set. Because the page was actively "walking" (e.g., it was sitting in step 2 of 4), the router missed it entirely, lost the dirty data, fetched stale memory, and permanently froze the CPU in a lock spinloop.

=== Before
```
auto tag_it = m_tag_index.find(address);
if (tag_it != m_tag_index.end()) {
    int way = tag_it->second;

    // BUG: Only checks two static locations. Completely ignores the "Walk" path!
    if (m_cache[default_set][way] != nullptr && m_cache[default_set][way]->m_Address == address) {
        return default_set; 
    }
    if (m_cache[target_set][way] != nullptr && m_cache[target_set][way]->m_Address == address) {
        return target_set;
    }
}
```

=== After
```
auto tag_it = m_tag_index.find(address);
if (tag_it != m_tag_index.end()) {
    int way = tag_it->second;

    // FIX: The Universal Scan. Actively sweep the entire 4-step walk path 
    // in the original zone so data is NEVER orphaned!
    int orig_zone_start = (default_set / zone_size) * zone_size;
    int orig_local = default_set % zone_size;
    for (int i = 0; i <= 3; i++) {
        int check_set = orig_zone_start + ((orig_local + i) % zone_size);
        if (m_cache[check_set][way] != nullptr && m_cache[check_set][way]->m_Address == address) {
            return check_set; // Found the missing block mid-walk!
        }
    }

    // FIX: Sweep the entire 4-step walk path in the target zone!
    int target_zone_start = (base_set / zone_size) * zone_size;
    int target_local = base_set % zone_size;
    for (int i = 0; i <= 3; i++) {
        int check_set = target_zone_start + ((target_local + i) % zone_size);
        if (m_cache[check_set][way] != nullptr && m_cache[check_set][way]->m_Address == address) {
            return check_set;
        }
    }
}
```


*Fixing the Math Overshoot*. The initial offset math utilized the combined size of multiple zones. This was corrected to bind strictly to a single zone size `(m_thresholds[0])`, ensuring the algorithm perfectly isolates wear to the intended hardware tiers.

The Bug: The math used `m_thresholds[1]` (which is the boundary for Zone 2). Because this modulo was too large, the offset physically overshot the Low Retention zone and dumped hot data back into the delicate High Retention zones.

=== Before
```
// Lazy redirection trigger
if (m_chunk_counters.at(addr_chunk_ID).isSaturated()) {
  
  // BUG: Using threshold[1] allows the offset to be 2x the size of a single zone!
  int max_lr_set = m_thresholds[1]; 
  int offset = addr_chunk_ID % max_lr_set; 
  
  m_chunk_redirection_table[addr_chunk_ID] = offset;
}
```

=== After
```
// Lazy redirection trigger
if (m_chunk_counters.at(addr_chunk_ID).isSaturated()) {
  
  // FIX: Bind the offset strictly to the size of ONE zone (m_thresholds[0])
  int zone_size = m_thresholds[0];
  int offset = addr_chunk_ID % zone_size;
  
  m_chunk_redirection_table[addr_chunk_ID] = offset;
}
```


== C++ Implementation

=== Inter-zones Jump (Base Set)
The router first checks if the page has hit maximum saturation (15 writes).
If it has, it applies a strict threshold boundary (`m_thresholds[0]`) to calculate a macro-level jump, funneling the data into a lower-retention tier.
This establishes the `base_set`.

=== Intra-Zone Walk
The router takes the base_set and applies the micro-level "Walk" offset.
It uses modulo arithmetic `((local_index + intra_offset) % zone_size)` to ensure the step strictly wraps around within its designated retention zone, preventing accidental spillage into other tiers.

