/*
 * Copyright (c) 2020-2021 ARM Limited
 * All rights reserved
 *
 * The license below extends only to copyright in the software and shall
 * not be construed as granting a license to any other intellectual
 * property including but not limited to intellectual property relating
 * to a hardware implementation of the functionality of the software
 * licensed hereunder.  You may use the software subject to the license
 * terms below provided that you ensure that this notice is replicated
 * unmodified and in its entirety in all distributions of the software,
 * modified or unmodified, in source code or in binary form.
 *
 * Copyright (c) 1999-2012 Mark D. Hill and David A. Wood
 * Copyright (c) 2013 Advanced Micro Devices, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met: redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer;
 * redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution;
 * neither the name of the copyright holders nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "mem/ruby/structures/CacheMemory.hh"

#include "base/compiler.hh"
#include "base/intmath.hh"
#include "base/logging.hh"
#include "base/sat_counter.hh"
#include "debug/HtmMem.hh"
#include "debug/RubyCache.hh"
#include "debug/RubyCacheTrace.hh"
#include "debug/RubyResourceStalls.hh"
#include "debug/RubyStats.hh"
#include "mem/cache/replacement_policies/weighted_lru_rp.hh"
#include "mem/ruby/protocol/AccessPermission.hh"
#include "mem/ruby/system/RubySystem.hh"
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <iostream>

namespace gem5 {

namespace ruby {

std::ostream &operator<<(std::ostream &out, const CacheMemory &obj) {
  obj.print(out);
  out << std::flush;
  return out;
}

CacheMemory::CacheMemory(const Params &p, const std::string &cache_level_call)
    : SimObject(p), m_ruby_system(p.ruby_system),
      dataArray(p.dataArrayBanks, p.start_index_bit),
      tagArray(p.tagArrayBanks, p.start_index_bit),
      atomicALUArray(p.atomicALUs, p.atomicLatency), cacheMemoryStats(this) {
  m_cache_size = p.size;
  m_cache_assoc = p.assoc;
  m_replacementPolicy_ptr = p.replacement_policy;
  m_start_index_bit = p.start_index_bit;
  m_is_instruction_only_cache = p.is_icache;
  m_resource_stalls = p.resourceStalls;
  m_block_size = p.block_size; // may be 0 at this point. Updated in init()
  m_use_occupancy =
      dynamic_cast<replacement_policy::WeightedLRU *>(m_replacementPolicy_ptr)
          ? true
          : false;

  m_RETENTION_ZONE_1 = p.low_retention_limit;
  m_RETENTION_ZONE_2 = p.mediumlow_retention_limit;
  m_RETENTION_ZONE_3 = p.mediumhigh_retention_limit;
  m_RETENTION_ZONE_4 = p.high_retention_limit;

  m_cache_level_call = cache_level_call;
  std::cout << "Cache Level Call: " << m_cache_level_call << '\n';

  m_is_sttram = p.is_sttram; // Type of hardware
  std::cout << "Is STT-RAM mode enabled: " << (m_is_sttram ? "True" : "False")
            << '\n';

  m_lazy_redirection_scheme = p.lazy_redirection_scheme;
  std::cout << "Is STT-RAM Lazy redirection enabled: "
            << (m_lazy_redirection_scheme ? "True" : "False") << '\n';

  if (m_lazy_redirection_scheme && !m_is_sttram) {
    fatal("Invalid Configuration: You cannot enable lazy redirection "
          "if STT-RAM is disabled. Check your Python flags!");
  }

  std::cout << "RETENTION_ZONE_1: " << m_RETENTION_ZONE_1 << '\n';
  std::cout << "RETENTION_ZONE_2: " << m_RETENTION_ZONE_2 << '\n';
  std::cout << "RETENTION_ZONE_3: " << m_RETENTION_ZONE_3 << '\n';
  std::cout << "RETENTION_ZONE_4: " << m_RETENTION_ZONE_4 << '\n';

  m_num_of_retention_zones = p.num_of_retention_zones;
  if (m_num_of_retention_zones < 1 || m_num_of_retention_zones > 4) {
    fatal("Invalid Flag: num_of_retention_zones must be between 1 and 4. "
          "Provided: %d",
          m_num_of_retention_zones);
  }

  m_low_retention.data.read_latency = p.low_retention_data_read_latency;
  m_low_retention.tag.read_latency = p.low_retention_tag_read_latency;
  m_low_retention.data.write_latency = p.low_retention_data_write_latency;
  m_low_retention.tag.write_latency = p.low_retention_tag_write_latency;
  m_low_retention.time = m_RETENTION_ZONE_1;

  std::cout << "Low retention data read latency: "
            << m_low_retention.data.read_latency << '\n';
  std::cout << "Low retention tag read latency: "
            << m_low_retention.tag.read_latency << '\n';
  std::cout << "Low retention data write latency: "
            << m_low_retention.data.write_latency << '\n';
  std::cout << "Low retention tag write latency: "
            << m_low_retention.tag.write_latency << '\n';
  std::cout << "Low retention time: " << m_low_retention.time << '\n';

  std::cout << '\n';

  m_mediumlow_retention.data.read_latency =
      p.mediumlow_retention_data_read_latency;
  m_mediumlow_retention.tag.read_latency =
      p.mediumlow_retention_tag_read_latency;
  m_mediumlow_retention.data.write_latency =
      p.mediumlow_retention_data_write_latency;
  m_mediumlow_retention.tag.write_latency =
      p.mediumlow_retention_tag_write_latency;
  m_mediumlow_retention.time = m_RETENTION_ZONE_2;

  std::cout << "Mediumlow retention data read latency: "
            << m_mediumlow_retention.data.read_latency << '\n';
  std::cout << "Mediumlow retention tag read latency: "
            << m_mediumlow_retention.tag.read_latency << '\n';
  std::cout << "Mediumlow retention data write latency: "
            << m_mediumlow_retention.data.write_latency << '\n';
  std::cout << "Mediumlow retention tag write latency: "
            << m_mediumlow_retention.tag.write_latency << '\n';
  std::cout << "Mediumlow retention time: " << m_mediumlow_retention.time
            << '\n';
  std::cout << '\n';

  m_mediumhigh_retention.data.read_latency =
      p.mediumhigh_retention_data_read_latency;
  m_mediumhigh_retention.tag.read_latency =
      p.mediumhigh_retention_tag_read_latency;
  m_mediumhigh_retention.data.write_latency =
      p.mediumhigh_retention_data_write_latency;
  m_mediumhigh_retention.tag.write_latency =
      p.mediumhigh_retention_tag_write_latency;
  m_mediumhigh_retention.time = m_RETENTION_ZONE_3;

  std::cout << "Mediumhigh retention data read latency: "
            << m_mediumhigh_retention.data.read_latency << '\n';
  std::cout << "Mediumhigh retention tag read latency: "
            << m_mediumhigh_retention.tag.read_latency << '\n';
  std::cout << "Mediumhigh retention data write latency: "
            << m_mediumhigh_retention.data.write_latency << '\n';
  std::cout << "Mediumhigh retention tag write latency: "
            << m_mediumhigh_retention.tag.write_latency << '\n';
  std::cout << "Mediumhigh retention time: " << m_mediumhigh_retention.time
            << '\n';
  std::cout << '\n';

  m_high_retention.data.read_latency = p.high_retention_data_read_latency;
  m_high_retention.tag.read_latency = p.high_retention_tag_read_latency;
  m_high_retention.data.write_latency = p.high_retention_data_write_latency;
  m_high_retention.tag.write_latency = p.high_retention_tag_write_latency;
  m_high_retention.time = m_RETENTION_ZONE_4;

  std::cout << "High retention data read latency: "
            << m_high_retention.data.read_latency << '\n';
  std::cout << "High retention tag read latency: "
            << m_high_retention.tag.read_latency << '\n';
  std::cout << "High retention data write latency: "
            << m_high_retention.data.write_latency << '\n';
  std::cout << "High retention tag write latency: "
            << m_high_retention.tag.write_latency << '\n';
  std::cout << "High retention time: " << m_high_retention.time << '\n';
  std::cout << '\n';

  // Retention Zone Table tests
  if (m_num_of_retention_zones == 1) {
    m_retention_table.push_back(m_low_retention);
  } else if (m_num_of_retention_zones == 2) {
    m_retention_table.push_back(m_low_retention);
    m_retention_table.push_back(m_high_retention);
  } else if (m_num_of_retention_zones == 3) {
    m_retention_table.push_back(m_low_retention);
    m_retention_table.push_back(m_mediumlow_retention);
    m_retention_table.push_back(m_high_retention);
  } else {
    m_retention_table.push_back(m_low_retention);
    m_retention_table.push_back(m_mediumlow_retention);
    m_retention_table.push_back(m_mediumhigh_retention);
    m_retention_table.push_back(m_high_retention);
  }
}

void CacheMemory::setRubySystem(RubySystem *rs) {
  dataArray.setClockPeriod(rs->clockPeriod());
  tagArray.setClockPeriod(rs->clockPeriod());
  atomicALUArray.setClockPeriod(rs->clockPeriod());
  atomicALUArray.setBlockSize(rs->getBlockSizeBytes());

  if (m_block_size == 0) {
    m_block_size = rs->getBlockSizeBytes();
  }

  m_ruby_system = rs;
}

void CacheMemory::init() {
  dataArray.setClockPeriod(m_ruby_system->clockPeriod());
  tagArray.setClockPeriod(m_ruby_system->clockPeriod());
  atomicALUArray.setClockPeriod(m_ruby_system->clockPeriod());
  atomicALUArray.setBlockSize(m_ruby_system->getBlockSizeBytes());
  m_block_size = m_ruby_system->getBlockSizeBytes();

  assert(m_block_size != 0);

  std::cout << "Cache Level Call: " << m_cache_level_call << '\n';

  m_cache_num_sets = (m_cache_size / m_cache_assoc) / m_block_size;
  std::cout << "Total cache sets: " << m_cache_num_sets << '\n';
  assert(m_cache_num_sets > 1);

  std::cout << "Number of retention zones: " << m_num_of_retention_zones
            << '\n';

  int threshold{m_cache_num_sets / m_num_of_retention_zones};

  int threshold_set{threshold};
  for (std::size_t i{0}; i < m_num_of_retention_zones; i++) {
    m_thresholds.push_back(threshold_set);
    threshold_set += threshold;
  }

  for (auto &i : m_thresholds) {
    std::cout << "m_threshold entry: " << i << '\n';
  }

  assert(m_cache_num_sets >= 0);

  m_cache_num_set_bits = floorLog2(m_cache_num_sets);
  assert(m_cache_num_set_bits > 0);

  m_cache.resize(m_cache_num_sets,
                 std::vector<AbstractCacheEntry *>(m_cache_assoc, nullptr));
  replacement_data.resize(m_cache_num_sets,
                          std::vector<ReplData>(m_cache_assoc, nullptr));

  // instantiate all the replacement_data here
  for (int i = 0; i < m_cache_num_sets; i++) {
    for (int j = 0; j < m_cache_assoc; j++) {
      replacement_data[i][j] = m_replacementPolicy_ptr->instantiateEntry();
    }
  }

  // Assigning sets to chunks
  int num_chunks = m_cache_num_sets / 4;
  m_chunk.resize(num_chunks);
  for (int i = 0; i < num_chunks; i++) {
    m_chunk[i] = {0, 0};
  }
}

CacheMemory::~CacheMemory() {
  if (m_replacementPolicy_ptr)
    delete m_replacementPolicy_ptr;
  for (int i = 0; i < m_cache_num_sets; i++) {
    for (int j = 0; j < m_cache_assoc; j++) {
      delete m_cache[i][j];
    }
  }
}

int CacheMemory::getRetentionZone(int64_t cacheSet) const {
  for (int i{0}; i < m_num_of_retention_zones; i++) {
    if (cacheSet < m_thresholds[i]) {
      return i;
    }
  }
  return m_num_of_retention_zones - 1;
}

Cycles CacheMemory::getRetentionLatency(CacheRequestType requestType,
                                        Addr address) {
  int64_t cacheSet = addressToCacheSet(address);
  Cycles basic_latency;

  int retention_threshold = getRetentionZone(cacheSet);

  if (retention_threshold == -1) {
    warn("CacheMemory access_type not found: %s",
         CacheRequestType_to_string(requestType));
    basic_latency = Cycles(1);

  } else {
    switch (requestType) {
    case CacheRequestType_DataArrayRead:
      basic_latency = m_retention_table[retention_threshold].data.read_latency;
      break;
    case CacheRequestType_DataArrayWrite:
      basic_latency = m_retention_table[retention_threshold].data.write_latency;
      break;
    case CacheRequestType_TagArrayRead:
      basic_latency = m_retention_table[retention_threshold].tag.read_latency;
      break;
    case CacheRequestType_TagArrayWrite:
      basic_latency = m_retention_table[retention_threshold].tag.write_latency;
      break;
    default:
      warn("CacheMemory access_type not found: %s",
           CacheRequestType_to_string(requestType));
      basic_latency = Cycles(1);
    }
  }

  Tick bankFreeTick;
  if (requestType == CacheRequestType_DataArrayRead ||
      requestType == CacheRequestType_DataArrayWrite) {
    bankFreeTick = dataArray.getBankEndTime(cacheSet);
  } else {
    bankFreeTick = tagArray.getBankEndTime(cacheSet);
  }

  Tick currTick = curTick();

  if (bankFreeTick > currTick) {
    cacheMemoryStats.m_data_array_stalls++;
    return m_ruby_system->ticksToCycles(bankFreeTick - currTick);
  } else {
    return basic_latency;
  }
}

// convert a Address to its location in the cache
// int64_t CacheMemory::addressToCacheSet(Addr address) const {
//   assert(address == makeLineAddress(address));
//   return bitSelect(address, m_start_index_bit,
//                    m_start_index_bit + m_cache_num_set_bits - 1);
// }

int64_t CacheMemory::addressToCacheSet(Addr address) const {
  assert(address == makeLineAddress(address));
  int64_t default_set = getDefaultSet(address);

  // If not in 4-retention mode, just use standard routing
  if (!m_lazy_redirection_scheme || m_num_of_retention_zones != 4) {
    return default_set;
  }

  Addr addr_chunk_ID = address >> 12;
  auto redir_it = m_chunk_redirection_table.find(addr_chunk_ID);
  if (redir_it != m_chunk_redirection_table.end()) {

    int64_t redirected_set = default_set;

    if (default_set >= m_thresholds[2]) {
      // High retention to Medium low retention
      redirected_set = m_thresholds[0] + redir_it->second;

    } else if (default_set >= m_thresholds[1]) {
      // Medium-high retention to low retention
      redirected_set = redir_it->second;

    } else {
      // If ata low retention then, don't redirect
      redirected_set = default_set;
    }

    auto tag_it = m_tag_index.find(address);
    if (tag_it != m_tag_index.end()) {
      int way = tag_it->second;

      if (m_cache[default_set][way] != nullptr &&
          m_cache[default_set][way]->m_Address == address) {
        return default_set; // Keep pointing to the zombie until it's evicted
      }
    }

    return redirected_set;
  }

  // if (redir_it != m_chunk_redirection_table.end()) {
  //   int max_lr_set = m_thresholds[1];
  //   int64_t redirected_set = (default_set + redir_it->second) % max_lr_set;
  //
  //   auto tag_it = m_tag_index.find(address);
  //   if (tag_it != m_tag_index.end()) {
  //     int way = tag_it->second;
  //
  //     // SLICC finds its dead blocks to properly process
  //     // coherence snoops and officially evict them.
  //     if (m_cache[default_set][way] != nullptr &&
  //         m_cache[default_set][way]->m_Address == address) {
  //       return default_set;
  //     }
  //   }
  //
  //   // The old block was officially evicted and erased from the tag index.
  //   // Safely route future allocations to the new LR zone!
  //   return redirected_set;
  // }

  return default_set;
}

// Given a cache index: returns the index of the tag in a set.
// returns -1 if the tag is not found.
int CacheMemory::findTagInSet(int64_t cacheSet, Addr tag) const {
  assert(tag == makeLineAddress(tag));
  auto it = m_tag_index.find(tag);
  if (it != m_tag_index.end()) {
    int way = it->second;
    if (m_cache[cacheSet][way] != nullptr &&
        m_cache[cacheSet][way]->m_Address == tag &&
        m_cache[cacheSet][way]->m_Permission != AccessPermission_NotPresent) {
      return way;
    }
  }
  return -1; // Not found
}

// Given a cache index: returns the index of the tag in a set.
// returns -1 if the tag is not found.
int CacheMemory::findTagInSetIgnorePermissions(int64_t cacheSet,
                                               Addr tag) const {
  assert(tag == makeLineAddress(tag));
  auto it = m_tag_index.find(tag);
  if (it != m_tag_index.end()) {
    int way = it->second;
    if (m_cache[cacheSet][way] != nullptr &&
        m_cache[cacheSet][way]->m_Address == tag) {
      return way;
    }
  }
  return -1; // Not found
}

// Given an unique cache block identifier (idx): return the valid address
// stored by the cache block.  If the block is invalid/notpresent, the
// function returns the 0 address
Addr CacheMemory::getAddressAtIdx(int idx) const {
  Addr tmp(0);

  int set = idx / m_cache_assoc;
  assert(set < m_cache_num_sets);

  int way = idx - set * m_cache_assoc;
  assert(way < m_cache_assoc);

  AbstractCacheEntry *entry = m_cache[set][way];
  if (entry == NULL || entry->m_Permission == AccessPermission_Invalid ||
      entry->m_Permission == AccessPermission_NotPresent) {
    return tmp;
  }
  return entry->m_Address;
}

bool CacheMemory::tryCacheAccess(Addr address, RubyRequestType type,
                                 DataBlock *&data_ptr) {
  DPRINTF(RubyCache, "trying to access address: %#x\n", address);
  AbstractCacheEntry *entry = lookup(address);
  if (entry != nullptr) {
    // Do we even have a tag match?
    m_replacementPolicy_ptr->touch(entry->replacementData);
    entry->setLastAccess(curTick());
    data_ptr = &(entry->getDataBlk());

    if (entry->m_Permission == AccessPermission_Read_Write) {
      DPRINTF(RubyCache, "Have permission to access address: %#x\n", address);
      return true;
    }
    if ((entry->m_Permission == AccessPermission_Read_Only) &&
        (type == RubyRequestType_LD || type == RubyRequestType_IFETCH)) {
      DPRINTF(RubyCache, "Have permission to access address: %#x\n", address);
      return true;
    }
    // The line must not be accessible
  }
  DPRINTF(RubyCache, "Do not have permission to access address: %#x\n",
          address);
  data_ptr = NULL;
  return false;
}

bool CacheMemory::testCacheAccess(Addr address, RubyRequestType type,
                                  DataBlock *&data_ptr) {
  DPRINTF(RubyCache, "testing address: %#x\n", address);
  AbstractCacheEntry *entry = lookup(address);
  if (entry != nullptr) {
    // Do we even have a tag match?
    m_replacementPolicy_ptr->touch(entry->replacementData);
    entry->setLastAccess(curTick());
    data_ptr = &(entry->getDataBlk());

    DPRINTF(RubyCache, "have permission for address %#x?: %d\n", address,
            entry->m_Permission != AccessPermission_NotPresent);
    return entry->m_Permission != AccessPermission_NotPresent;
  }

  DPRINTF(RubyCache, "do not have permission for address %#x\n", address);
  data_ptr = NULL;
  return false;
}

// tests to see if an address is present in the cache
bool CacheMemory::isTagPresent(Addr address) const {
  const AbstractCacheEntry *const entry = lookup(address);
  if (entry == nullptr) {
    // We didn't find the tag
    DPRINTF(RubyCache, "No tag match for address: %#x\n", address);
    return false;
  }
  DPRINTF(RubyCache, "address: %#x found\n", address);
  return true;
}

// Returns true if there is:
//   a) a tag match on this address or there is
//   b) an unused line in the same cache "way"
bool CacheMemory::cacheAvail(Addr address) const {
  int64_t cacheSet = addressToCacheSet(address);
  for (int i = 0; i < m_cache_assoc; i++) {
    AbstractCacheEntry *entry = m_cache[cacheSet][i];
    // Expired lines must NOT be treated as available slots until SLICC replaces
    // them.
    if (entry == NULL || entry->m_Permission == AccessPermission_NotPresent) {
      return true;
    }
  }
  return false;
}

AbstractCacheEntry *CacheMemory::allocate(Addr address,
                                          AbstractCacheEntry *entry) {
  int64_t cacheSet = addressToCacheSet(address);
  std::vector<AbstractCacheEntry *> &set = m_cache[cacheSet];

  for (int i = 0; i < m_cache_assoc; i++) {

    // Find an empty or NotPresent slot
    if (!set[i] || set[i]->m_Permission == AccessPermission_NotPresent) {
      if (set[i] != nullptr) {
        // Remove the old address from the tag index before overwriting
        m_tag_index.erase(set[i]->m_Address);

        // Cleanup the new entry pointer provided by SLICC since we reuse
        // set[i]
        if (set[i] != entry) {
          delete entry;
        }
      } else {
        set[i] = entry;
        set[i]->replacementData = replacement_data[cacheSet][i];
      }

      // Initialize new entry
      set[i]->m_Address = address;
      set[i]->m_is_expired = false;
      set[i]->m_Permission = AccessPermission_Invalid;
      m_tag_index[address] = i;

      if (!m_is_sttram) {
        set[i]->m_retention_limit = 0;
      } else {
        int retention_threshold = getRetentionZone(cacheSet);
        Tick total_retention_time = m_retention_table[retention_threshold].time;
        set[i]->m_retention_limit = total_retention_time;
        // std::cout << "Set retention limit: " << set[i]->m_retention_limit
        //           << '\n';
      }

      DPRINTF(RubyCache, "ALLOCATE: Addr %#x assigned retention limit: %llu\n",
              address, set[i]->m_retention_limit);
      set[i]->setLastAccess(curTick());
      set[i]->m_last_refresh_tick = curTick();
      m_replacementPolicy_ptr->reset(set[i]->replacementData);

      return set[i];
    }
  }
  panic("Set %d is full. No expired or invalid blocks to evict.", cacheSet);
}

void CacheMemory::deallocate(Addr address) {
  DPRINTF(RubyCache, "deallocating address: %#x\n", address);
  int64_t cacheSet = addressToCacheSet(address);

  // Find the block physically, ignoring whether it is a "Zombie"
  // (Expired/NotPresent)
  int loc = findTagInSetIgnorePermissions(cacheSet, address);

  // Safely deallocate if found, otherwise do nothing
  if (loc != -1) {
    AbstractCacheEntry *entry = m_cache[cacheSet][loc];
    m_replacementPolicy_ptr->invalidate(entry->replacementData);

    delete entry;
    m_cache[cacheSet][loc] = NULL;
    m_tag_index.erase(address);
  }
}

// Returns with the physical address of the conflicting cache line
Addr CacheMemory::cacheProbe(Addr address) const {
  assert(address == makeLineAddress(address));
  assert(!cacheAvail(address));

  int64_t cacheSet = addressToCacheSet(address);

  // If there is an expired block, evict it
  for (int i = 0; i < m_cache_assoc; i++) {
    if (m_cache[cacheSet][i] && m_cache[cacheSet][i]->m_is_expired) {
      return m_cache[cacheSet][i]->m_Address;
    }
  }

  std::vector<ReplaceableEntry *> candidates;
  for (int i = 0; i < m_cache_assoc; i++) {
    candidates.push_back(static_cast<ReplaceableEntry *>(m_cache[cacheSet][i]));
  }
  return m_cache[cacheSet]
                [m_replacementPolicy_ptr->getVictim(candidates)->getWay()]
                    ->m_Address;
}

void CacheMemory::regStats() {
  // 1. Call parent to register the Stats::Group (cacheMemoryStats)
  SimObject::regStats();

  // 2. Initialize the vector size
  // At this point, init() has run, so m_cache_num_sets is valid!
  cacheMemoryStats.m_accesses_per_set.init(m_cache_num_sets);

  cacheMemoryStats.m_data_array_stalls.name(name() + ".data_array_stalls")
      .desc("Number of times a request stalled due to bank contention");

  int num_chunks = m_cache_num_sets / 4;
  cacheMemoryStats.m_chunk_reads.init(num_chunks);
  cacheMemoryStats.m_chunk_writes.init(num_chunks);
}

AbstractCacheEntry *CacheMemory::lookup(Addr address) {
  int64_t cacheSet = addressToCacheSet(address);
  int loc = findTagInSet(cacheSet, address);
  if (loc == -1)
    return NULL;

  AbstractCacheEntry *entry = m_cache[cacheSet][loc];
  if (entry != NULL) {
    if (entry->m_retention_limit > 0 && !entry->m_is_expired) {

      if (entry->m_Permission != AccessPermission_Busy) {
        if (curTick() >
            (entry->m_last_refresh_tick + entry->m_retention_limit)) {
          entry->m_is_expired = true;
        }
      }
    }
  }
  return entry;
}

const AbstractCacheEntry *CacheMemory::lookup(Addr address) const {
  assert(address == makeLineAddress(address));
  int64_t cacheSet = addressToCacheSet(address);
  int loc = findTagInSet(cacheSet, address);

  if (loc == -1)
    return NULL;

  const AbstractCacheEntry *entry = m_cache[cacheSet][loc];
  if (entry != NULL) {
    // Passive check for expiry
    if (entry->m_retention_limit > 0 &&
        curTick() > (entry->m_last_refresh_tick + entry->m_retention_limit)) {
      // Return the entry anyway so SLICC knows what state it was in
      return entry;
    }
  }
  return entry;
}

// Sets the most recently used bit for a cache block
void CacheMemory::setMRU(Addr address) {
  AbstractCacheEntry *entry = lookup(makeLineAddress(address));
  if (entry != nullptr) {
    m_replacementPolicy_ptr->touch(entry->replacementData);
    entry->setLastAccess(curTick());
  }
}

void CacheMemory::setMRU(AbstractCacheEntry *entry) {
  assert(entry != nullptr);
  m_replacementPolicy_ptr->touch(entry->replacementData);
  entry->setLastAccess(curTick());
}

void CacheMemory::setMRU(Addr address, int occupancy) {
  AbstractCacheEntry *entry = lookup(makeLineAddress(address));
  if (entry != nullptr) {
    // m_use_occupancy can decide whether we are using WeightedLRU
    // replacement policy. Depending on different replacement policies,
    // use different touch() function.
    if (m_use_occupancy) {
      static_cast<replacement_policy::WeightedLRU *>(m_replacementPolicy_ptr)
          ->touch(entry->replacementData, occupancy);
    } else {
      m_replacementPolicy_ptr->touch(entry->replacementData);
    }
    entry->setLastAccess(curTick());
  }
}

int CacheMemory::getReplacementWeight(int64_t set, int64_t loc) {
  assert(set < m_cache_num_sets);
  assert(loc < m_cache_assoc);
  int ret = 0;
  if (m_cache[set][loc] != NULL) {
    ret = m_cache[set][loc]->getNumValidBlocks();
    assert(ret >= 0);
  }

  return ret;
}

void CacheMemory::recordCacheContents(int cntrl, CacheRecorder *tr) const {
  uint64_t warmedUpBlocks = 0;
  [[maybe_unused]] uint64_t totalBlocks =
      (uint64_t)m_cache_num_sets * (uint64_t)m_cache_assoc;

  for (int i = 0; i < m_cache_num_sets; i++) {
    for (int j = 0; j < m_cache_assoc; j++) {
      if (m_cache[i][j] != NULL) {
        AccessPermission perm = m_cache[i][j]->m_Permission;
        RubyRequestType request_type = RubyRequestType_NULL;
        if (perm == AccessPermission_Read_Only) {
          if (m_is_instruction_only_cache) {
            request_type = RubyRequestType_IFETCH;
          } else {
            request_type = RubyRequestType_LD;
          }
        } else if (perm == AccessPermission_Read_Write) {
          request_type = RubyRequestType_ST;
        }

        if (request_type != RubyRequestType_NULL) {
          Tick lastAccessTick;
          lastAccessTick = m_cache[i][j]->getLastAccess();
          tr->addRecord(cntrl, m_cache[i][j]->m_Address, 0, request_type,
                        lastAccessTick, m_cache[i][j]->getDataBlk());
          warmedUpBlocks++;
        }
      }
    }
  }

  DPRINTF(RubyCacheTrace,
          "%s: %lli blocks of %lli total blocks"
          "recorded %.2f%% \n",
          name().c_str(), warmedUpBlocks, totalBlocks,
          (float(warmedUpBlocks) / float(totalBlocks)) * 100.0);
}

void CacheMemory::print(std::ostream &out) const {
  out << "Cache dump: " << name() << std::endl;
  for (int i = 0; i < m_cache_num_sets; i++) {
    for (int j = 0; j < m_cache_assoc; j++) {
      if (m_cache[i][j] != NULL) {
        out << "  Index: " << i << " way: " << j << " entry: " << *m_cache[i][j]
            << std::endl;
      } else {
        out << "  Index: " << i << " way: " << j << " entry: NULL" << std::endl;
      }
    }
  }
}

void CacheMemory::printData(std::ostream &out) const {
  out << "printData() not supported" << std::endl;
}

void CacheMemory::setLocked(Addr address, int context) {
  DPRINTF(RubyCache, "Setting Lock for addr: %#x to %d\n", address, context);
  AbstractCacheEntry *entry = lookup(address);
  assert(entry != nullptr);
  entry->setLocked(context);
}

void CacheMemory::clearLocked(Addr address) {
  DPRINTF(RubyCache, "Clear Lock for addr: %#x\n", address);
  AbstractCacheEntry *entry = lookup(address);
  assert(entry != nullptr);
  entry->clearLocked();
}

void CacheMemory::clearLockedAll(int context) {
  // iterate through every set and way to get a cache line
  for (auto i = m_cache.begin(); i != m_cache.end(); ++i) {
    std::vector<AbstractCacheEntry *> set = *i;
    for (auto j = set.begin(); j != set.end(); ++j) {
      AbstractCacheEntry *line = *j;
      if (line && line->isLocked(context)) {
        DPRINTF(RubyCache, "Clear Lock for addr: %#x\n", line->m_Address);
        line->clearLocked();
      }
    }
  }
}

bool CacheMemory::isLocked(Addr address, int context) {
  AbstractCacheEntry *entry = lookup(address);
  assert(entry != nullptr);
  DPRINTF(RubyCache, "Testing Lock for addr: %#llx cur %d con %d\n", address,
          entry->m_locked, context);
  return entry->isLocked(context);
}

CacheMemory::CacheMemoryStats::CacheMemoryStats(statistics::Group *parent)
    : statistics::Group(parent),
      ADD_STAT(numDataArrayReads, "Number of data array reads"),
      ADD_STAT(numDataArrayWrites, "Number of data array writes"),
      ADD_STAT(numTagArrayReads, "Number of tag array reads"),
      ADD_STAT(numTagArrayWrites, "Number of tag array writes"),
      ADD_STAT(numTagArrayStalls, "Number of stalls caused by tag array"),
      ADD_STAT(numDataArrayStalls, "Number of stalls caused by data array"),
      ADD_STAT(numAtomicALUOperations, "Number of atomic ALU operations"),
      ADD_STAT(numAtomicALUArrayStalls,
               "Number of stalls caused by atomic ALU array"),
      ADD_STAT(htmTransCommitReadSet, "Read set size of a committed "
                                      "transaction"),
      ADD_STAT(htmTransCommitWriteSet, "Write set size of a committed "
                                       "transaction"),
      ADD_STAT(htmTransAbortReadSet, "Read set size of a aborted transaction"),
      ADD_STAT(htmTransAbortWriteSet, "Write set size of a aborted "
                                      "transaction"),
      ADD_STAT(m_demand_hits, "Number of cache demand hits"),
      ADD_STAT(m_demand_misses, "Number of cache demand misses"),
      ADD_STAT(m_demand_accesses, "Number of cache demand accesses",
               m_demand_hits + m_demand_misses),
      ADD_STAT(m_prefetch_hits, "Number of cache prefetch hits"),
      ADD_STAT(m_prefetch_misses, "Number of cache prefetch misses"),
      ADD_STAT(m_prefetch_accesses, "Number of cache prefetch accesses",
               m_prefetch_hits + m_prefetch_misses),
      ADD_STAT(m_accessModeType, ""),
      ADD_STAT(m_accesses_per_set,
               "Number of accesses per individual set index"),
      ADD_STAT(m_chunk_reads, "Number of accesses per individual set index"),
      ADD_STAT(m_chunk_writes, "Number of accesses per individual set index") {
  numDataArrayReads.flags(statistics::nozero);

  numDataArrayWrites.flags(statistics::nozero);

  numTagArrayReads.flags(statistics::nozero);

  numTagArrayWrites.flags(statistics::nozero);

  numTagArrayStalls.flags(statistics::nozero);

  numDataArrayStalls.flags(statistics::nozero);

  numAtomicALUOperations.flags(statistics::nozero);

  numAtomicALUArrayStalls.flags(statistics::nozero);

  htmTransCommitReadSet.init(8).flags(statistics::pdf | statistics::dist |
                                      statistics::nozero | statistics::nonan);

  htmTransCommitWriteSet.init(8).flags(statistics::pdf | statistics::dist |
                                       statistics::nozero | statistics::nonan);

  htmTransAbortReadSet.init(8).flags(statistics::pdf | statistics::dist |
                                     statistics::nozero | statistics::nonan);

  htmTransAbortWriteSet.init(8).flags(statistics::pdf | statistics::dist |
                                      statistics::nozero | statistics::nonan);

  m_prefetch_hits.flags(statistics::nozero);

  m_prefetch_misses.flags(statistics::nozero);

  m_prefetch_accesses.flags(statistics::nozero);

  m_accessModeType.init(RubyRequestType_NUM)
      .flags(statistics::pdf | statistics::total);

  // accessesPerSet.init(static_cast<CacheMemory *>(parent)->getCacheSize());

  for (int i = 0; i < RubyAccessMode_NUM; i++) {
    m_accessModeType.subname(i, RubyAccessMode_to_string(RubyAccessMode(i)))
        .flags(statistics::nozero);
  }
}

// assumption: SLICC generated files will only call this function
// once **all** resources are granted
void CacheMemory::recordRequestType(CacheRequestType requestType, Addr addr) {
  DPRINTF(RubyStats, "Recorded statistic: %s\n",
          CacheRequestType_to_string(requestType));

  int64_t cacheSet = addressToCacheSet(addr);
  cacheMemoryStats.m_accesses_per_set[cacheSet]++;

  // Physical IDs
  int retention_threshold = getRetentionZone(cacheSet);
  int chunkID = getChunkId(cacheSet);

  // Address chunk IDs (4KB page ID)
  Addr addr_chunk_ID = addr >> 12;

  // Find the block physically, even if it is a "Zombie" (expired/invalid)
  int loc = findTagInSetIgnorePermissions(cacheSet, addr);
  AbstractCacheEntry *entry = (loc != -1) ? m_cache[cacheSet][loc] : nullptr;

  if (entry != nullptr) {
    entry->setLastAccess(curTick());
  }

  switch (requestType) {
  case CacheRequestType_DataArrayRead:
    if (m_resource_stalls) {
      Cycles accessLatency =
          m_retention_table[retention_threshold].data.read_latency;
      dataArray.reserve(addressToCacheSet(addr), accessLatency);
    }
    cacheMemoryStats.numDataArrayReads++;
    m_chunk[chunkID].reads++;
    cacheMemoryStats.m_chunk_reads[chunkID]++;
    return;

  case CacheRequestType_DataArrayWrite:
    if (entry != nullptr) {
      // Resets the STT-RAMN, if new write occurs
      entry->m_last_refresh_tick = curTick();
      entry->m_is_expired = false;

      // Acts as a reset, such that newly written data doesn't get expired
      if (!m_is_sttram) {
        entry->m_retention_limit = 0;
      } else {
        Tick total_retention_time = m_retention_table[retention_threshold].time;
        entry->m_retention_limit = total_retention_time;

        // Initialize the saturating counter for this page if it doesn't exist
        if (m_lazy_redirection_scheme) {
          if (m_chunk_counters.find(addr_chunk_ID) == m_chunk_counters.end()) {
            m_chunk_counters.emplace(addr_chunk_ID, SatCounter8(4));
          }

          // If not redirected increment sat counter
          if (m_chunk_redirection_table.find(addr_chunk_ID) ==
              m_chunk_redirection_table.end()) {

            m_chunk_counters.at(addr_chunk_ID)++;

            // Lazy redirection
            if (m_chunk_counters.at(addr_chunk_ID).isSaturated()) {
              DPRINTF(RubyCache, "Page %#x saturated! Lazy redirect to LR.\n",
                      addr_chunk_ID);

              // addressToCacheSet() will safely route to the old blocks until
              // they die naturally.
              int max_lr_set = m_thresholds[1];
              int offset = addr_chunk_ID % max_lr_set;
              m_chunk_redirection_table[addr_chunk_ID] = offset;
            }
          }
        }
      }

      DPRINTF(RubyCache, "ALLOCATE: Addr %#x assigned retention limit: %llu\n",
              addr, entry->m_retention_limit);
      DPRINTF(RubyCache, "RETENTION_RESET: Addr %#x refreshed to tick %lld\n",
              addr, entry->m_last_refresh_tick);
    }

    if (m_resource_stalls) {
      Cycles accessLatency =
          m_retention_table[retention_threshold].data.write_latency;
      dataArray.reserve(addressToCacheSet(addr), accessLatency);
    }
    cacheMemoryStats.numDataArrayWrites++;
    m_chunk[chunkID].writes++;
    cacheMemoryStats.m_chunk_writes[chunkID]++;
    return;

  case CacheRequestType_TagArrayRead:
    if (m_resource_stalls) {
      Cycles accessLatency =
          m_retention_table[retention_threshold].tag.read_latency;
      tagArray.reserve(addressToCacheSet(addr), accessLatency);
    }
    cacheMemoryStats.numTagArrayReads++;
    m_chunk[chunkID].reads++;
    cacheMemoryStats.m_chunk_reads[chunkID]++;
    return;

  case CacheRequestType_TagArrayWrite:
    if (entry != nullptr) {
      // Physical Magnet Reset
      entry->m_last_refresh_tick = curTick();
      entry->m_is_expired = false;

      if (!m_is_sttram) {
        entry->m_retention_limit = 0;
      } else {
        int current_zone = getRetentionZone(cacheSet);
        Tick total_retention_time = m_retention_table[current_zone].time;
        entry->m_retention_limit = total_retention_time;
      }

      // Tag writes usually happen during state transitions; restore stability
      if (entry->m_Permission == AccessPermission_NotPresent) {
        entry->m_Permission = AccessPermission_Invalid;
      }

      DPRINTF(RubyCache, "ALLOCATE: Addr %#x assigned retention limit: %llu\n",
              addr, entry->m_retention_limit);
      DPRINTF(RubyCache, "RETENTION_RESET: Addr %#x refreshed to tick %lld\n",
              addr, entry->m_last_refresh_tick);
    }

    if (m_resource_stalls) {
      Cycles accessLatency =
          m_retention_table[retention_threshold].tag.write_latency;
      tagArray.reserve(addressToCacheSet(addr), accessLatency);
    }
    cacheMemoryStats.numTagArrayWrites++;
    m_chunk[chunkID].writes++;
    cacheMemoryStats.m_chunk_writes[chunkID]++;
    return;

  case CacheRequestType_AtomicALUOperation:
    if (m_resource_stalls)
      atomicALUArray.reserve(addr);
    cacheMemoryStats.numAtomicALUOperations++;
    return;

  default:
    warn("CacheMemory access_type not found: %s",
         CacheRequestType_to_string(requestType));
  }
}

bool CacheMemory::checkResourceAvailable(CacheResourceType res, Addr addr) {
  if (!m_resource_stalls) {
    return true;
  }

  if (res == CacheResourceType_TagArray) {
    if (tagArray.tryAccess(addressToCacheSet(addr)))
      return true;
    else {
      DPRINTF(RubyResourceStalls, "Tag array stall on addr %#x in set %d\n",
              addr, addressToCacheSet(addr));
      cacheMemoryStats.numTagArrayStalls++;
      return false;
    }
  } else if (res == CacheResourceType_DataArray) {
    if (dataArray.tryAccess(addressToCacheSet(addr)))
      return true;
    else {
      DPRINTF(RubyResourceStalls, "Data array stall on addr %#x in set %d\n",
              addr, addressToCacheSet(addr));
      cacheMemoryStats.numDataArrayStalls++;
      return false;
    }
  } else if (res == CacheResourceType_AtomicALUArray) {
    if (atomicALUArray.tryAccess(addr))
      return true;
    else {
      DPRINTF(RubyResourceStalls,
              "Atomic ALU array stall on addr %#x in line address %#x\n", addr,
              makeLineAddress(addr));
      cacheMemoryStats.numAtomicALUArrayStalls++;
      return false;
    }
  } else {
    panic("Unrecognized cache resource type.");
  }
}

bool CacheMemory::isBlockInvalid(int64_t cache_set, int64_t loc) {
  return (m_cache[cache_set][loc]->m_Permission == AccessPermission_Invalid);
}

bool CacheMemory::isBlockNotBusy(int64_t cache_set, int64_t loc) {
  return (m_cache[cache_set][loc]->m_Permission != AccessPermission_Busy);
}

/* hardware transactional memory */

void CacheMemory::htmAbortTransaction() {
  uint64_t htmReadSetSize = 0;
  uint64_t htmWriteSetSize = 0;

  // iterate through every set and way to get a cache line
  for (auto i = m_cache.begin(); i != m_cache.end(); ++i) {
    std::vector<AbstractCacheEntry *> set = *i;

    for (auto j = set.begin(); j != set.end(); ++j) {
      AbstractCacheEntry *line = *j;

      if (line != nullptr) {
        htmReadSetSize += (line->getInHtmReadSet() ? 1 : 0);
        htmWriteSetSize += (line->getInHtmWriteSet() ? 1 : 0);
        if (line->getInHtmWriteSet()) {
          line->invalidateEntry();
        }
        line->setInHtmWriteSet(false);
        line->setInHtmReadSet(false);
        line->clearLocked();
      }
    }
  }

  cacheMemoryStats.htmTransAbortReadSet.sample(htmReadSetSize);
  cacheMemoryStats.htmTransAbortWriteSet.sample(htmWriteSetSize);
  DPRINTF(HtmMem, "htmAbortTransaction: read set=%u write set=%u\n",
          htmReadSetSize, htmWriteSetSize);
}

void CacheMemory::htmCommitTransaction() {
  uint64_t htmReadSetSize = 0;
  uint64_t htmWriteSetSize = 0;

  // iterate through every set and way to get a cache line
  for (auto i = m_cache.begin(); i != m_cache.end(); ++i) {
    std::vector<AbstractCacheEntry *> set = *i;

    for (auto j = set.begin(); j != set.end(); ++j) {
      AbstractCacheEntry *line = *j;
      if (line != nullptr) {
        htmReadSetSize += (line->getInHtmReadSet() ? 1 : 0);
        htmWriteSetSize += (line->getInHtmWriteSet() ? 1 : 0);
        line->setInHtmWriteSet(false);
        line->setInHtmReadSet(false);
        line->clearLocked();
      }
    }
  }

  cacheMemoryStats.htmTransCommitReadSet.sample(htmReadSetSize);
  cacheMemoryStats.htmTransCommitWriteSet.sample(htmWriteSetSize);
  DPRINTF(HtmMem, "htmCommitTransaction: read set=%u write set=%u\n",
          htmReadSetSize, htmWriteSetSize);
}

void CacheMemory::profileDemandHit() { cacheMemoryStats.m_demand_hits++; }

void CacheMemory::profileDemandMiss() { cacheMemoryStats.m_demand_misses++; }

void CacheMemory::profilePrefetchHit() { cacheMemoryStats.m_prefetch_hits++; }

void CacheMemory::profilePrefetchMiss() {
  cacheMemoryStats.m_prefetch_misses++;
}

} // namespace ruby
} // namespace gem5
