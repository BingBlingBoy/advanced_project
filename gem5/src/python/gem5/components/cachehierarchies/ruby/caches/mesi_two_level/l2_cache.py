# Copyright (c) 2021 The Regents of the University of California
# All Rights Reserved.
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

import math

from m5.objects import (
    MESI_Two_Level_L2Cache_Controller,
    MessageBuffer,
    L2CacheMemory,
)


class L2Cache(MESI_Two_Level_L2Cache_Controller):

    _version = 0

    @classmethod
    def versionCount(cls):
        cls._version += 1  # Use count for this particular type
        return cls._version - 1

    def __init__(
        self,
        l2_size,
        l2_assoc,
        network,
        num_l2Caches,
        cache_line_size,
        percentage_of_low_retention_sets,
        num_of_retention_zones,
        is_sttram,
        lazy_redirection_scheme,

        low_retention_data_read_latency,
        low_retention_tag_read_latency,
        low_retention_data_write_latency,
        low_retention_tag_write_latency,
        low_retention_limit,

        mediumlow_retention_data_read_latency,
        mediumlow_retention_tag_read_latency,
        mediumlow_retention_data_write_latency,
        mediumlow_retention_tag_write_latency,
        mediumlow_retention_limit,

        mediumhigh_retention_data_read_latency,
        mediumhigh_retention_tag_read_latency,
        mediumhigh_retention_data_write_latency,
        mediumhigh_retention_tag_write_latency,
        mediumhigh_retention_limit,

        high_retention_data_read_latency,
        high_retention_tag_read_latency,
        high_retention_data_write_latency,
        high_retention_tag_write_latency,
        high_retention_limit,
    ):
        super().__init__()

        self.version = self.versionCount()
        self._cache_line_size = cache_line_size
        self.connectQueues(network)

        # print("Python Percentage of Low Retention Sets: ",
        #       percentage_of_low_retention_sets)

        # This is the cache memory object that stores the cache data and tags
        print(f"PYTHON L2 cache Is STT-RAM: {is_sttram}")

        self.L2cache = L2CacheMemory(
            size=l2_size,
            assoc=l2_assoc,
            start_index_bit=self.getIndexBit(num_l2Caches),
            resourceStalls=True,
            percentage_of_low_retention_sets=percentage_of_low_retention_sets,
            num_of_retention_zones=num_of_retention_zones,
            is_sttram=is_sttram,
            lazy_redirection_scheme=lazy_redirection_scheme,

            low_retention_data_read_latency=low_retention_data_read_latency,
            low_retention_tag_read_latency=low_retention_tag_read_latency,
            low_retention_data_write_latency=low_retention_data_write_latency,
            low_retention_tag_write_latency=low_retention_tag_write_latency,
            low_retention_limit=low_retention_limit,

            mediumlow_retention_data_read_latency = mediumlow_retention_data_read_latency,
            mediumlow_retention_tag_read_latency = mediumlow_retention_tag_read_latency,
            mediumlow_retention_data_write_latency = mediumlow_retention_data_write_latency,
            mediumlow_retention_tag_write_latency = mediumlow_retention_tag_write_latency,
            mediumlow_retention_limit=mediumlow_retention_limit,

            mediumhigh_retention_data_read_latency = mediumhigh_retention_data_read_latency,
            mediumhigh_retention_tag_read_latency = mediumhigh_retention_tag_read_latency,
            mediumhigh_retention_data_write_latency = mediumhigh_retention_data_write_latency,
            mediumhigh_retention_tag_write_latency = mediumhigh_retention_tag_write_latency,
            mediumhigh_retention_limit=mediumhigh_retention_limit,

            high_retention_data_read_latency=high_retention_data_read_latency,
            high_retention_tag_read_latency=high_retention_tag_read_latency,
            high_retention_data_write_latency=high_retention_data_write_latency,
            high_retention_tag_write_latency=high_retention_tag_write_latency,
            high_retention_limit=high_retention_limit
        )

        self.transitions_per_cycle = 4

    def getIndexBit(self, num_l2caches):
        l2_bits = int(math.log(num_l2caches, 2))
        bits = int(math.log(self._cache_line_size, 2)) + l2_bits
        return bits

    def connectQueues(self, network):
        self.DirRequestFromL2Cache = MessageBuffer()
        self.DirRequestFromL2Cache.out_port = network.in_port
        self.L1RequestFromL2Cache = MessageBuffer()
        self.L1RequestFromL2Cache.out_port = network.in_port
        self.responseFromL2Cache = MessageBuffer()
        self.responseFromL2Cache.out_port = network.in_port
        self.unblockToL2Cache = MessageBuffer()
        self.unblockToL2Cache.in_port = network.out_port
        self.L1RequestToL2Cache = MessageBuffer()
        self.L1RequestToL2Cache.in_port = network.out_port
        self.responseToL2Cache = MessageBuffer()
        self.responseToL2Cache.in_port = network.out_port
