import os
from gem5.components.boards.simple_board import SimpleBoard
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.components.cachehierarchies.ruby.mesi_two_level_cache_hierarchy import (
    MESITwoLevelCacheHierarchy,
)
from gem5.components.memory.single_channel import SingleChannelDDR4_2400
from gem5.components.processors.cpu_types import CPUTypes
from gem5.isas import ISA
from gem5.resources.resource import WorkloadResource
from gem5.simulate.simulator import Simulator


cache_hierarchy = MESITwoLevelCacheHierarchy(
        l1d_size="16KiB",
        l1d_assoc=8,
        l1i_size="16KiB",
        l1i_assoc=8,
        l2_size="1024KiB",
        l2_assoc=32,
        num_l2_banks=2,
        percentage_of_low_retention_sets=1.0,
        low_retention_data_read_latency=2,
        low_retention_tag_read_latency=2,
        low_retention_data_write_latency=2,
        low_retention_tag_write_latency=2,
        high_retention_data_read_latency=4,
        high_retention_tag_read_latency=4,
        high_retention_data_write_latency=4,
        high_retention_tag_write_latency=4,
        )

memory = SingleChannelDDR4_2400()

processor = SimpleProcessor(cpu_type=CPUTypes.TIMING, isa=ISA.X86, num_cores=1)

board = SimpleBoard(
        clk_freq="3GHz",
        processor=processor,
        memory=memory,
        cache_hierarchy=cache_hierarchy
        )

# Just providing the path locally

binary_path = os.path.abspath("./gem5/configs/SRAM/cache_workload")

if not os.path.exists(binary_path):
    raise FileNotFoundError(f"Binary not found at {binary_path}")

binary = WorkloadResource(local_path=binary_path)

board.set_se_binary_workload(binary)


simulator = Simulator(board=board)
simulator.run()
