# Copyright (c) 2009 Advanced Micro Devices, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met: redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer;
# redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution;
# neither the name of the copyright holders nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

from m5.objects.ReplacementPolicies import *
from m5.params import *
from m5.proxy import *
from m5.SimObject import SimObject


class RubyCache(SimObject):
    type = "RubyCache"
    cxx_class = "gem5::ruby::CacheMemory"
    cxx_header = "mem/ruby/structures/CacheMemory.hh"

    abstract = True

    size = Param.MemorySize("capacity in bytes")
    assoc = Param.Int("")
    replacement_policy = Param.BaseReplacementPolicy(TreePLRURP(), "")
    start_index_bit = Param.Int(6, "index start, default 6 for 64-byte line")
    is_icache = Param.Bool(False, "is instruction only cache")
    block_size = Param.MemorySize(
        "0B", "block size in bytes. 0 means default RubyBlockSize"
    )
    ruby_system = Param.RubySystem(Parent.any, "The Ruby system this cache is part of")

    # Atomic parameters only applicable to GPU atomics
    # Zero atomic latency corresponds to instantanous atomic ALU operations
    atomicLatency = Param.Cycles(0, "Cycles for an atomic ALU operation")
    atomicALUs = Param.Int(64, "Number of atomic ALUs")

    dataArrayBanks = Param.Int(1, "Number of banks for the data array")
    tagArrayBanks = Param.Int(1, "Number of banks for the tag array")
    # dataAccessLatency = Param.Cycles(1, "cycles for a data array access")
    # tagAccessLatency = Param.Cycles(1, "cycles for a tag array access")
    resourceStalls = Param.Bool(False, "stall if there is a resource failure")

    percentage_of_low_retention_sets = Param.Float(
            0, "percentage of low retention sets")

    num_of_retention_zones = Param.Int(
            1, "num_of_retention_zones")

    low_retention_data_read_latency = Param.Cycles(
            1, "cycles read access for low retention for data array")
    low_retention_tag_read_latency  = Param.Cycles(
            1, "cycles read access for low retention for tag array")
    low_retention_data_write_latency = Param.Cycles(
            1, "cycles write access for low retention for data array")
    low_retention_tag_write_latency = Param.Cycles(
            1, "cycles write access for low retention for tag array")
    low_retention_type = Param.Int(
            1, "Type of retenzion zone")

    mediumlow_retention_data_read_latency = Param.Cycles(
            1, "cycles read access for mediumlow retention for data array")
    mediumlow_retention_tag_read_latency  = Param.Cycles(
            1, "cycles read access for mediumlow retention for tag array")
    mediumlow_retention_data_write_latency = Param.Cycles(
            1, "cycles write access for mediumlow retention for data array")
    mediumlow_retention_tag_write_latency = Param.Cycles(
            1, "cycles write access for mediumlow retention for tag array")

    mediumhigh_retention_data_read_latency = Param.Cycles(
            1, "cycles read access for mediumhigh retention for data array")
    mediumhigh_retention_tag_read_latency  = Param.Cycles(
            1, "cycles read access for mediumhigh retention for tag array")
    mediumhigh_retention_data_write_latency = Param.Cycles(
            1, "cycles write access for mediumhigh retention for data array")
    mediumhigh_retention_tag_write_latency = Param.Cycles(
            1, "cycles write access for mediumhigh retention for tag array")

    high_retention_data_read_latency = Param.Cycles(
            1, "cycles read access for write retention for data array")
    high_retention_tag_read_latency  = Param.Cycles(
            1, "cycles read access for write retention for tag array")
    high_retention_data_write_latency = Param.Cycles(
            1, "cycles write access for write retention for data array")
    high_retention_tag_write_latency = Param.Cycles(
            1, "cycles write access for write retention for tag array")


class L1CacheMemory(RubyCache):
    type = "L1CacheMemory"
    cxx_class = "gem5::ruby::L1CacheMemory"
    cxx_header = "mem/ruby/structures/L1CacheMemory.hh"


class L2CacheMemory(RubyCache):
    type = "L2CacheMemory"
    cxx_class = "gem5::ruby::L2CacheMemory"
    cxx_header = "mem/ruby/structures/L2CacheMemory.hh"
