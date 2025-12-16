# Copyright (c) 2021 The Regents of the University of California
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


class AbstractTwoLevelCacheHierarchy:
    """
    An abstract two-level hierarchy with a configurable L1 and L2 size and
    associativity.
    """

    def __init__(
        self,
        l1i_size: str,
        l1i_assoc: int,
        l1d_size: str,
        l1d_assoc: int,
        l2_size: str,
        l2_assoc: int,
        percentage_of_low_retention_sets: float,
        num_of_retention_zones: int,

        low_retention_data_read_latency: int,
        low_retention_tag_read_latency: int,
        low_retention_data_write_latency: int,
        low_retention_tag_write_latency: int,

        mediumlow_retention_data_read_latency: int,
        mediumlow_retention_tag_read_latency: int,
        mediumlow_retention_data_write_latency: int,
        mediumlow_retention_tag_write_latency: int,

        mediumhigh_retention_data_read_latency: int,
        mediumhigh_retention_tag_read_latency: int,
        mediumhigh_retention_data_write_latency: int,
        mediumhigh_retention_tag_write_latency: int,

        high_retention_data_read_latency: int,
        high_retention_tag_read_latency: int,
        high_retention_data_write_latency: int,
        high_retention_tag_write_latency: int,
    ):
        """
        :param l1i_size: The size of the L1 Instruction cache (e.g. "32KiB").

        :param l1i_assoc:

        :param l1d_size: The size of the L1 Data cache (e.g. "32KiB").

        :param l1d_assoc:

        :param l2_size: The size of the L2 cache (e.g., "256KiB").

        :param l2_assoc:
        """
        self._l1i_size = l1i_size
        self._l1i_assoc = l1i_assoc
        self._l1d_size = l1d_size
        self._l1d_assoc = l1d_assoc
        self._l2_size = l2_size
        self._l2_assoc = l2_assoc
        self._percent_of_low_retention_sets = percentage_of_low_retention_sets
        self._num_of_retention_zones = num_of_retention_zones

        self._low_retention_data_read_latency = low_retention_data_read_latency
        self._low_retention_tag_read_latency = low_retention_tag_read_latency
        self._low_retention_data_write_latency = low_retention_data_write_latency
        self._low_retention_tag_write_latency = low_retention_tag_write_latency

        self._mediumlow_retention_data_read_latency = mediumlow_retention_data_read_latency
        self._mediumlow_retention_tag_read_latency = mediumlow_retention_tag_read_latency
        self._mediumlow_retention_data_write_latency = mediumlow_retention_data_write_latency
        self._mediumlow_retention_tag_write_latency = mediumlow_retention_tag_write_latency

        self._mediumhigh_retention_data_read_latency = mediumhigh_retention_data_read_latency
        self._mediumhigh_retention_tag_read_latency = mediumhigh_retention_tag_read_latency
        self._mediumhigh_retention_data_write_latency = mediumhigh_retention_data_write_latency
        self._mediumhigh_retention_tag_write_latency = mediumhigh_retention_tag_write_latency

        self._high_retention_data_read_latency = high_retention_data_read_latency
        self._high_retention_tag_read_latency = high_retention_tag_read_latency
        self._high_retention_data_write_latency = high_retention_data_write_latency
        self._high_retention_tag_write_latency = high_retention_tag_write_latency
