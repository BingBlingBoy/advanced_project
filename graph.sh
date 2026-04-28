#!/bin/bash

#SBATCH --nodes=1
#SBATCH --time=00:05:00
#SBATCH --output=OUTPUT/graph.out
#SBATCH --cpus-per-task=8

set -e

module load python

HARDWARE_LIST=(
  # "4MiB_SRAM"
  # "4MiB_1RET_STTRAM"
  # "4MiB_base_4RET_STTRAM"
  "4MiB_custom_4RET_STTRAM"

  # "8MiB_SRAM"
  # "8MiB_1RET_STTRAM"
  # "8MiB_base_4RET_STTRAM"
  # "8MiB_custom_4RET_STTRAM"
  #
  # "16MiB_SRAM"
  # "16MiB_1RET_STTRAM"
  # "16MiB_base_4RET_STTRAM"
  # "16MiB_custom_4RET_STTRAM"
)

# for HARDWARE in ${HARDWARE_LIST[@]}; do
#   BENCHMARK=$1
#
#   # IPC_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/ipc_log.csv.gz
#   # CHUNK_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/chunk.csv.gz
#   # L2_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/l2_stats_log.csv.gz
#
#   # ./gem5/configs/PARSEC/ipc_graph.py \
#   #   --benchmark ${BENCHMARK} \
#   #   --hardware ${HARDWARE} \
#   #   --file ${IPC_FILEPATH} \
#   #   --outdir "OUTPUT/GRAPHS/${BENCHMARK}" || {
#   #   echo "--> SKIPPING ${HARDWARE}: Data incomplete or missing."
#   #   continue
#   # }
#
#   ./gem5/configs/PARSEC/ipc_graph.py \
#     --tech ${HARDWARE}/standard \
#     --outdir "OUTPUT/GRAPHS/IPC" \
#     --benchmark="[blackscholes, dedup, canneal]" || {
#     echo "--> SKIPPING IPC COMPARE ${HARDWARE}: Data incomplete or missing."
#   }
#
#   # ./gem5/configs/PARSEC/power_analysis.py \
#   #   --benchmark ${BENCHMARK} \
#   #   --hardware ${HARDWARE} \
#   #   --file ${CHUNK_FILEPATH} \
#   #   --outdir "OUTPUT/GRAPHS/${BENCHMARK}" || {
#   #   echo "--> SKIPPING ${HARDWARE}: Data incomplete or missing."
#   #   continue
#   # }
#   #
#   # ./gem5/configs/PARSEC/spatial_plot.py \
#   #   --benchmark ${BENCHMARK} \
#   #   --hardware ${HARDWARE} \
#   #   --file ${CHUNK_FILEPATH} \
#   #   --outdir "OUTPUT/GRAPHS/${BENCHMARK}" || {
#   #   echo "--> SKIPPING ${HARDWARE}: Data incomplete or missing."
#   #   continue
#   # }
#   #
#   # ./gem5/configs/PARSEC/compare_graphs.py \
#   #   --benchmark ${BENCHMARK} \
#   #   --hardwares "Baseline_1RET" "Lazy_4RET" \
#   #   --dirs ./gem5/configs/PARSEC/1MiB_1RET_STTRAM/${BENCHMARK} ./gem5/configs/PARSEC/1MiB_4RET_STTRAM/${BENCHMARK} \
#   #   --outdir "OUTPUT/COMPARISONS" || {
#   #   echo "--> SKIPPING ${HARDWARE}: Data incomplete or missing."
#   #   continue
#   # }
#
# done

# ./gem5/configs/PARSEC/compare_ipc.py \
#   --search 4MiB \
#   --outdir "OUTPUT/GRAPHS/IPC_COMPARISONS" \
#   --exclude "1RET, base_4RET" \
#   --benchmark="blackscholes, fluidanimate, canneal, streamcluster, dedup" || {
#   echo "--> SKIPPING"
# }
#
# ./gem5/configs/PARSEC/normalised_ipc.py \
#   --search 4MiB \
#   --outdir "OUTPUT/GRAPHS/NORMALISED_IPC_COMPARISONS" \
#   --baseline SRAM \
#   --exclude "1RET, base_4RET" \
#   --benchmark="blackscholes, fluidanimate, canneal, streamcluster, dedup" || {
#   echo "--> SKIPPING"
# }

# ./gem5/configs/PARSEC/edp.py \
#   --search "4MiB" \
#   --outdir "OUTPUT/GRAPHS/EDP" \
#   --baseline "4MiB_SRAM" \
#   --benchmark "blackscholes, fluidanimate, canneal, streamcluster, dedup" \
#   --exclude "1RET, base_4RET" \
#   --metrics "NVSim/OUTPUT/sttram_metrics_linear_dist.txt" || {
#   echo "--> SKIPPING"
# }

./gem5/configs/PARSEC/routing_mechanism.py \
  --search "4MiB" \
  --benchmark "blackscholes, fluidanimate, canneal, streamcluster, dedup" \
  --exclude "1RET, base_4RET" \
  --outdir "OUTPUT/GRAPHS/ROUTING" || {
  echo "--> SKIPPING"
}

# ./gem5/configs/PARSEC/energy_breakdown.py \
#   --search 4MiB \
#   --outdir "OUTPUT/GRAPHS/ENERGY_BREAKDOWN" \
#   --metrics NVSim/OUTPUT/sttram_metrics_linear_dist.txt \
#   --exclude "1RET, base_4RET" \
#   --baseline SRAM \
#   --benchmark="blackscholes, fluidanimate, canneal, streamcluster, dedup" || {
#   echo "--> SKIPPING"
# }
#
# ./gem5/configs/PARSEC/set_accesses_graph.py \
#   --search "4MiB" \
#   --benchmark "blackscholes" \
#   --outdir "OUTPUT/GRAPHS/interset" || {
#   echo "--> SKIPPING"
# }
#
# ./gem5/configs/PARSEC/spatio_temporal.py \
#   --search 4MiB \
#   --benchmark blackscholes \
#   --metrics NVSim/OUTPUT/sttram_metrics_linear_dist.txt \
#   --exclude "1RET, base_4RET" \
#   --outdir "OUTPUT/GRAPHS/SPATIAL_TEMPORAL" \
#   --benchmark="blackscholes, fluidanimate, canneal, streamcluster, dedup" || {
#   echo "--> SKIPPING"
# }

# ./gem5/configs/PARSEC/compare_ipc.py \
#   --search 8MiB \
#   --outdir "OUTPUT/GRAPHS/IPC_COMPARISONS" \
#   --exclude "1RET, base_4RET, ISO_AREA" \
#   --benchmark="blackscholes, fluidanimate, canneal, streamcluster, dedup" || {
#   echo "--> SKIPPING"
# }
# #
# ./gem5/configs/PARSEC/normalised_ipc.py \
#   --search 8MiB \
#   --outdir "OUTPUT/GRAPHS/NORMALISED_IPC_COMPARISONS" \
#   --baseline SRAM \
#   --exclude "1RET, base_4RET, ISO_AREA" \
#   --benchmark="blackscholes, fluidanimate, canneal, streamcluster, dedup" || {
#   echo "--> SKIPPING"
# }

# ./gem5/configs/PARSEC/edp.py \
#   --search "8MiB" \
#   --outdir "OUTPUT/GRAPHS/EDP" \
#   --baseline "8MiB_SRAM" \
#   --benchmark "blackscholes, fluidanimate, canneal, streamcluster, dedup" \
#   --exclude "1RET, base_4RET, ISO_AREA" \
#   --metrics "NVSim/OUTPUT/sttram_metrics_linear_dist.txt" || {
#   echo "--> SKIPPING"
# }

./gem5/configs/PARSEC/routing_mechanism.py \
  --search "8MiB" \
  --benchmark "blackscholes, fluidanimate, canneal, streamcluster, dedup" \
  --exclude "1RET, base_4RET, ISO_AREA" \
  --outdir "OUTPUT/GRAPHS/ROUTING" || {
  echo "--> SKIPPING"
}
#
# ./gem5/configs/PARSEC/energy_breakdown.py \
#   --search 8MiB \
#   --outdir "OUTPUT/GRAPHS/ENERGY_BREAKDOWN" \
#   --metrics NVSim/OUTPUT/sttram_metrics_linear_dist.txt \
#   --exclude "1RET, base_4RET, ISO_AREA" \
#   --baseline SRAM \
#   --benchmark="blackscholes, fluidanimate, canneal,  dedup" || {
#   echo "--> SKIPPING"
# }
#
# ./gem5/configs/PARSEC/set_accesses_graph.py \
#   --search "8MiB" \
#   --benchmark "blackscholes" \
#   --outdir "OUTPUT/GRAPHS/interset" || {
#   echo "--> SKIPPING"
# }
#
# ./gem5/configs/PARSEC/spatio_temporal.py \
#   --search 8MiB \
#   --metrics NVSim/OUTPUT/sttram_metrics_linear_dist.txt \
#   --exclude "1RET, base_4RET, ISO_AREA" \
#   --outdir "OUTPUT/GRAPHS/SPATIAL_TEMPORAL" \
#   --benchmark="blackscholes, fluidanimate, canneal, dedup" || {
#   echo "--> SKIPPING"
# }

echo "DONE"
