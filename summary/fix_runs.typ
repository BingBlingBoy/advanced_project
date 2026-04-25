= Fixing Runs

== `hardware_config.py`
Matching `num_cores` with the `.rcS` thread count.

Originally, the `.rcS` ran with 16 threads with a configuration of 4 cores, the OS ran out of thread stack memory resulting in an `Error 5` Linux Segfault.

== `MESI_Two_Level-L1cache.sm`
Removed `!cache_entry.m_is_expired` from the `i_allocate` (Allocate Transient Buffer Entry).
A TBE is a temporary waiting room used to safely hold data while a cache cache block is being evicted.
However, an expired block in the L1 is still the only valid copy of dirty data in the system.
By removing the check, the hardware now correctly rescues the dirty data and writes it back to memory before turning off the physical cache line, completely eliminating the Error 4 (0x00000000 pointer) segfaults.

=== Old Code
```cpp
action(i_allocateTBE, "i", desc="Allocate TBE") {
    check_allocate(TBEs);
    TBEs.allocate(address);
    set_tbe(TBEs[address]);
    tbe.isPrefetch := false;

    if (is_valid(cache_entry)) {
        if (cache_entry.CacheState != State:I && 
            cache_entry.CacheState != State:NP && 
            !cache_entry.m_is_expired) {              // <--- THE FATAL BUG
            tbe.DataBlk := cache_entry.DataBlk;
            tbe.Dirty := cache_entry.Dirty;
        }
    }
}
```

=== New Code
```cpp
action(i_allocateTBE, "i", desc="Allocate TBE") {
    check_allocate(TBEs);
    TBEs.allocate(address);
    set_tbe(TBEs[address]);
    tbe.isPrefetch := false;

    // CRITICAL FIX: ALWAYS copy data. An expired block is still the 
    // ONLY valid copy of dirty data in the system!
    if (is_valid(cache_entry)) {
        if (cache_entry.CacheState != State:I && 
            cache_entry.CacheState != State:NP) {
            tbe.DataBlk := cache_entry.DataBlk;       // <--- ALWAYS SAVED
            tbe.Dirty := cache_entry.Dirty;
        }
    }
}
```

=== Justification
An expired physical magnet in STT-RAM means the data is about to be unreliable, not that it is currently empty.
The hardware must treat expired dirty blocks exactly like normal dirty blocks during eviction to ensure the memory controller receives the user's saved data.

== `MESI_Two_Level-L2cache.sm`
The old code accepted network messages instantly.
But STT-RAM has highly asymmetric write latencies.
If the data array was busy executing a 60-cycle write, it couldn't instantly process a new read request.

=== In-Flight Evictions
When the L2 decides to evict a block (entering transient states `MCT_I` or `MT_I`), it temporarily removes the L1 from its list of "Sharers". If the L1 suddenly decides to write back dirty data (`PUTX`) at that exact millisecond, the L2 thinks the L1 is an imposter (classifying it as `PUTX_old`) and drops the dirty data, resulting in Error 4.

==== OLD CODE
```cpp
transition(MCT_I, L1_PUTX_old) {
  t_sendWBAck;
  jj_popL1RequestQueue;
}
```
==== New Code
```cpp
action(qqr_writeDataToTBEFromPUTX, "\qqr", desc="Write dirty PUTX data to TBE") {
  peek(L1RequestL2Network_in, RequestMsg) {
    assert(is_valid(tbe));
    if (in_msg.Dirty) {
      tbe.DataBlk := in_msg.DataBlk;     // <--- RESCUES THE DIRTY DATA
      tbe.Dirty := true;
    }
  }
}

transition(MCT_I, {L1_PUTX, L1_PUTX_old}, M_I) {
  qqr_writeDataToTBEFromPUTX;      
  ct_exclusiveReplacementFromTBE;  
  t_sendWBAck;
  jj_popL1RequestQueue;
}
```

We grouped both PUTX and PUTX_old together.
If any writeback arrives while the L2 is trying to evict, we use a custom action (`qqr_writeDataToTBEFromPUTX`) to snag the dirty data out of the message and force it into the TBE before it gets sent to memory.

=== Silent Upgrade Bug
When an L1 cache asked the L2 for Write permissions (`GETX`), the L2 passed the request to the Directory but accidentally hardcoded the message type as Read-Only (`GETS`).

==== Old Code
```cpp
action(a_issueFetchToMemory, "a", desc="fetch data from memory") {
      // ...
      out_msg.Type := CoherenceRequestType:GETS; // <--- HARDCODED
      // ...
}
```

=== New Code
```cpp
action(a_issueFetchToMemory, "a", desc="fetch data from memory") {
      // ...
      out_msg.Type := in_msg.Type;               // <--- DYNAMIC
      // ...
}
```

The Directory must know exactly what permission the core is asking for.
Passing the original request type through prevents coherence mismatch panics.


== `MESI_Two_Level-dir.sm`
Added the `transition(I, CleanReplacement)` and `transition(MI, CleanReplacement)` states with `kd_wakeUpDependents`.

Why: In massive 16-thread workloads, L2 caches are rapidly evicting clean data.
Frequently, by the time the `CleanReplacement` notification travels across the network to the Directory, another core has already requested the block shifting the Directory into an I (Idle) or MI (Modified-to-Invalid) state.
Instructing the Directory to acknowledge the late message, drop it, and wake up any stalled network buffers prevents catastrophic simulation panics under heavy load.
