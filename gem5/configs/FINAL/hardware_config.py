import os
import sys
import gzip
import argparse
import m5
from m5.objects import Root

from gem5.coherence_protocol import CoherenceProtocol
from gem5.components.boards.x86_board import X86Board
from gem5.components.cachehierarchies.ruby.mesi_two_level_cache_hierarchy import MESITwoLevelCacheHierarchy
from gem5.components.processors.cpu_types import CPUTypes
from gem5.components.processors.simple_processor import SimpleProcessor
from gem5.components.memory.single_channel import SingleChannelDDR4_2400
from gem5.isas import ISA
from gem5.utils.requires import requires
from gem5.resources.resource import AbstractResource, DiskImageResource

parser = argparse.ArgumentParser()
parser.add_argument("--benchmark", type=str, required=True)
parser.add_argument("--input", type=str, required=True)
parser.add_argument("--hardware", type=str, required=True)
args = parser.parse_args()

l2_size = args.hardware.split("_")[0]
ret_zone = args.hardware[5] if "SRAM" not in args.hardware else ""

parsec_path = os.path.join("/parsec", args.input)
x86_dir = "/x86"
kernel_path = os.path.join(x86_dir,  "binaries", "vmlinux")
disk_image = os.path.join(x86_dir,  "disks", "x86root-parsec.img")

if not os.path.exists(str(kernel_path)): sys.exit(f"Error: {kernel_path} missing")
with open(parsec_path, "r") as f: input_contents = f.read()

requires(isa_required=ISA.X86, coherence_protocol_required=CoherenceProtocol.MESI_TWO_LEVEL)

common_config = {"l1d_size": "64KiB", "l1d_assoc": 4, "l1i_size": "64KiB", "l1i_assoc": 4, "l2_size": f"{l2_size}", "l2_assoc": 16, "num_l2_banks": 1}

SRAM_LATENCIES = {
    "4MiB": {"low_retention_data_read_latency": 6, "low_retention_data_write_latency": 3, "low_retention_tag_read_latency": 2, "low_retention_tag_write_latency": 1},
    "8MiB": {"low_retention_data_read_latency": 9, "low_retention_data_write_latency": 5, "low_retention_tag_read_latency": 2, "low_retention_tag_write_latency": 2},
}

STT_LATENCIES = {
    "4MiB": {
        "LOW": {"low_retention_data_read_latency": 18, "low_retention_data_write_latency": 23, "low_retention_tag_read_latency": 2, "low_retention_tag_write_latency": 1, "low_retention_limit": 1_000_000_000},
        "MEDLOW": {"mediumlow_retention_data_read_latency": 18, "mediumlow_retention_data_write_latency": 30, "mediumlow_retention_tag_read_latency": 2, "mediumlow_retention_tag_write_latency": 1, "mediumlow_retention_limit": 10_000_000_000},
        "MEDHIGH": {"mediumhigh_retention_data_read_latency": 18, "mediumhigh_retention_data_write_latency": 36, "mediumhigh_retention_tag_read_latency": 2, "mediumhigh_retention_tag_write_latency": 1, "mediumhigh_retention_limit": 100_000_000_000},
        "HIGH": {"high_retention_data_read_latency": 18, "high_retention_data_write_latency": 43, "high_retention_tag_read_latency": 2, "high_retention_tag_write_latency": 1, "high_retention_limit": 1_000_000_000_000}
    },

    "8MiB": {
        "LOW": {"low_retention_data_read_latency": 18, "low_retention_data_write_latency": 33, "low_retention_tag_read_latency": 2, "low_retention_tag_write_latency": 1, "low_retention_limit": 1_000_000_000},
        "MEDLOW": {"mediumlow_retention_data_read_latency": 18, "mediumlow_retention_data_write_latency": 36, "mediumlow_retention_tag_read_latency": 2, "mediumlow_retention_tag_write_latency": 1, "mediumlow_retention_limit": 10_000_000_000},
        "MEDHIGH": {"mediumhigh_retention_data_read_latency": 18, "mediumhigh_retention_data_write_latency": 40, "mediumhigh_retention_tag_read_latency": 2, "mediumhigh_retention_tag_write_latency": 1, "mediumhigh_retention_limit": 100_000_000_000},
        "HIGH": {"high_retention_data_read_latency": 18, "high_retention_data_write_latency": 43, "high_retention_tag_read_latency": 2, "high_retention_tag_write_latency": 1, "high_retention_limit": 1_000_000_000_000}
    }
}

S_LAT = SRAM_LATENCIES.get(l2_size, SRAM_LATENCIES["8MiB"])
STT_LAT = STT_LATENCIES.get(l2_size, STT_LATENCIES["8MiB"])

hardware_specific_configs = {
    f"{l2_size}_SRAM": {"num_of_retention_zones": 1, "is_sttram": False, "low_retention_limit": 1_000_000_000_000_000, **S_LAT},

    f"{l2_size}_1RET_STTRAM": {"num_of_retention_zones": 1, "is_sttram": True,
                               "low_retention_data_read_latency": STT_LAT["HIGH"]["high_retention_data_read_latency"],
                               "low_retention_data_write_latency": STT_LAT["HIGH"]["high_retention_data_write_latency"],
                               "low_retention_tag_read_latency": STT_LAT["HIGH"]["high_retention_tag_read_latency"],
                               "low_retention_tag_write_latency": STT_LAT["HIGH"]["high_retention_tag_write_latency"],
                               "low_retention_limit": STT_LAT["HIGH"]["high_retention_limit"]},

    f"{l2_size}_2RET_STTRAM": {"num_of_retention_zones": 2, "is_sttram": True,
                               **STT_LAT["LOW"], **STT_LAT["HIGH"]},

    f"{l2_size}_3RET_STTRAM": {"num_of_retention_zones": 3, "is_sttram": True,
                               **STT_LAT["LOW"], **STT_LAT["MEDLOW"], **STT_LAT["HIGH"]},

    f"{l2_size}_base_4RET_STTRAM": {"num_of_retention_zones": 4, "is_sttram": True, "lazy_redirection_scheme": False,
                                    **STT_LAT["LOW"], **STT_LAT["MEDLOW"], **STT_LAT["MEDHIGH"], **STT_LAT["HIGH"]},

    f"{l2_size}_custom_4RET_STTRAM": {"num_of_retention_zones": 4, "is_sttram": True, "lazy_redirection_scheme": True,
                                      **STT_LAT["LOW"], **STT_LAT["MEDLOW"], **STT_LAT["MEDHIGH"], **STT_LAT["HIGH"]},

    f"{l2_size}_ISO_AREA_custom_4RET_STTRAM": {"num_of_retention_zones": 4, "is_sttram": True, "lazy_redirection_scheme": True,
                                      **STT_LAT["LOW"], **STT_LAT["MEDLOW"], **STT_LAT["MEDHIGH"], **STT_LAT["HIGH"]},
}

final_config = {**common_config, **hardware_specific_configs[args.hardware]}

print("DEBUG final_config types:")
for k, v in final_config.items():
    print(f"  {k}: {repr(v)} ({type(v).__name__})")

cache_hierarchy = MESITwoLevelCacheHierarchy(**final_config)
memory = SingleChannelDDR4_2400(size="3GiB")
processor = SimpleProcessor(cpu_type=CPUTypes.TIMING, isa=ISA.X86, num_cores=4)

board = X86Board(clk_freq="3GHz", processor=processor, memory=memory, cache_hierarchy=cache_hierarchy)
board.set_kernel_disk_workload(
    kernel=AbstractResource(local_path=kernel_path),
    disk_image=DiskImageResource(local_path=disk_image, root_partition="1"),
    kernel_args=["earlyprintk=ttyS0", "console=ttyS0", "lpj=7999923", "root=/dev/hda1"],
    readfile_contents=input_contents
)

board._pre_instantiate()
root = Root.getInstance()
if root: root.system = board; root.full_system = True
else: root = Root(full_system=True, system=board)

m5.instantiate()

output_dir = m5.options.outdir if hasattr(m5.options, 'outdir') else "m5out"
if not os.path.exists(output_dir): os.makedirs(output_dir)

ipc_log_path = os.path.join(output_dir, "ipc_log.csv.gz")
stats_log_path = os.path.join(output_dir, "l2_stats_log.csv.gz")
chunk_path = os.path.join(output_dir, "chunk.csv.gz")
mechanics_path = os.path.join(output_dir, "mechanics_log.csv.gz")
stats_file = os.path.join(output_dir, "stats.txt")

f_ipc = gzip.open(ipc_log_path, "wt")
f_stats = gzip.open(stats_log_path, "wt")
f_chunk = gzip.open(chunk_path, "wt")
f_mechanics = gzip.open(mechanics_path, "wt")

f_ipc.write("Time_s,IPC,Insts,Cycles\n")
f_stats.write("Time_s,Reads,Writes,Stalls,Misses\n")
f_chunk.write("Time_s,Chunk_ID,Reads,Writes\n")

f_mechanics.write("Time_s,Zombies_Collected,Inter_Zone_Jumps,Intra_Zone_Walks,L2_Writebacks\n")

WARMUP_SECONDS = 0.0
ROI_INTERVAL = 10_000_000_000 # 0.01s
total_cumulative_jumps = 0
total_cumulative_walks = 0

print(f"Beginning simulation! Hardware: {args.hardware}")

try:
    while True:
        exit_event = m5.simulate(ROI_INTERVAL)
        exit_cause = exit_event.getCause()

        if exit_cause == "simulate() limit reached":
            current_time = m5.curTick() / 1e12

            if current_time < WARMUP_SECONDS:
                m5.stats.reset()
                continue

            m5.stats.dump()

            c_insts, c_cycles = 0, 0
            c_l2_reads, c_l2_writes, c_l2_stalls, c_l2_misses = 0, 0, 0, 0
            c_zombies, c_jumps, c_walks, c_writebacks = 0, 0, 0, 0
            chunk_reads, chunk_writes = {}, {}

            try:
                with open(stats_file, 'r') as f_in:
                    for line in f_in:
                        parts = line.split()
                        if len(parts) < 2: continue
                        name, val = parts[0], parts[1]

                        if "numInsts" in line: c_insts += int(val)
                        if "numCycles" in line:
                            if int(val) > c_cycles: c_cycles = int(val)

                        if "DataArrayReads" in line: c_l2_reads += int(val)
                        if "DataArrayWrites" in line: c_l2_writes += int(val)
                        if "DataArrayStalls" in line: c_l2_stalls += int(val)
                        if "m_demand_misses" in line and "l2" in name.lower(): c_l2_misses += int(val)

                        if "m_zombies_collected" in name: c_zombies += int(val)
                        if "m_inter_zone_jumps" in name: c_jumps += int(val)
                        if "m_intra_zone_walks" in name: c_walks += int(val)
                        # if "writeback" in name.lower() and "l2" in name.lower(): c_writebacks += int(val)
                        if "dir_cntrl" in name.lower() and "memory.num_writes" in name.lower(): c_writebacks += int(val)

                        if "m_chunk_reads::" in name:
                            idx = name.split('::')[1]
                            chunk_reads[idx] = chunk_reads.get(idx, 0) + int(val)
                        if "m_chunk_writes::" in name:
                            idx = name.split('::')[1]
                            chunk_writes[idx] = chunk_writes.get(idx, 0) + int(val)

            except Exception as e:
                print(f"Error parsing: {e}")

            open(stats_file, 'w').close()

            ipc = c_insts / c_cycles if c_cycles > 0 else 0
            f_ipc.write(f"{current_time:.4f},{ipc:.4f},{c_insts},{c_cycles}\n")
            f_stats.write(f"{current_time:.4f},{c_l2_reads},{c_l2_writes},{c_l2_stalls},{c_l2_misses}\n")

            f_mechanics.write(f"{current_time:.4f},{c_zombies},{c_jumps},{c_walks},{c_writebacks}\n")

            active_chunks = []
            all_idxs = sorted(set(chunk_reads.keys()) | set(chunk_writes.keys()), key=int)
            for i in all_idxs:
                r, w = chunk_reads.get(i, 0), chunk_writes.get(i, 0)
                if r > 0 or w > 0:
                    active_chunks.append(f"{i}:{r}/{w}")
                    f_chunk.write(f"{current_time:.4f},{i},{r},{w}\n")

            total_cumulative_jumps += c_jumps
            total_cumulative_walks += c_walks

            print(f"[{current_time:.2f}s] Insts: {c_insts} | Reads: {c_l2_reads} | Writes: {c_l2_writes} | Walks: {c_walks} | Jumps: {c_jumps} | Total Walks: {total_cumulative_walks} | Total Jumps: {total_cumulative_jumps}")

            f_ipc.flush(); f_stats.flush(); f_chunk.flush(); f_mechanics.flush()
            m5.stats.reset()
        else:
            print(f"Exiting: {exit_cause}")
            break
finally:
    f_ipc.close(); f_stats.close(); f_chunk.close(); f_mechanics.close()
    print("Simulation Complete. Logs saved to m5out.")


