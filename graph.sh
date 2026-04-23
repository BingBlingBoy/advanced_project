#!/bin/bash

#SBATCH --nodes=1
#SBATCH --time=00:05:00
#SBATCH --output=OUTPUT/graph.out
#SBATCH --cpus-per-task=8

set -e

module load python

HARDWARE_LIST=(
  "4MiB_SRAM"
  "4MiB_1RET_STTRAM"
  "4MiB_base_4RET_STTRAM"
  "4MiB_custom_4RET_STTRAM"

  "8MiB_SRAM"
  "8MiB_1RET_STTRAM"
  "8MiB_base_4RET_STTRAM"
  "8MiB_custom_4RET_STTRAM"

  "16MiB_SRAM"
  "16MiB_1RET_STTRAM"
  "16MiB_base_4RET_STTRAM"
  "16MiB_custom_4RET_STTRAM"
)

for HARDWARE in ${HARDWARE_LIST[@]}; do
  BENCHMARK=$1

  # IPC_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/ipc_log.csv.gz
  # CHUNK_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/chunk.csv.gz
  # L2_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/l2_stats_log.csv.gz

  # ./gem5/configs/PARSEC/ipc_graph.py \
  #   --benchmark ${BENCHMARK} \
  #   --hardware ${HARDWARE} \
  #   --file ${IPC_FILEPATH} \
  #   --outdir "OUTPUT/GRAPHS/${BENCHMARK}" || {
  #   echo "--> SKIPPING ${HARDWARE}: Data incomplete or missing."
  #   continue
  # }

  ./gem5/configs/PARSEC/ipc_graph.py \
    --tech ${HARDWARE}/4bit_counter \
    --outdir "OUTPUT/GRAPHS/IPC_COMPARISONS" || {
    echo "--> SKIPPING IPC COMPARE ${HARDWARE}: Data incomplete or missing."
  }

  # ./gem5/configs/PARSEC/power_analysis.py \
  #   --benchmark ${BENCHMARK} \
  #   --hardware ${HARDWARE} \
  #   --file ${CHUNK_FILEPATH} \
  #   --outdir "OUTPUT/GRAPHS/${BENCHMARK}" || {
  #   echo "--> SKIPPING ${HARDWARE}: Data incomplete or missing."
  #   continue
  # }
  #
  # ./gem5/configs/PARSEC/spatial_plot.py \
  #   --benchmark ${BENCHMARK} \
  #   --hardware ${HARDWARE} \
  #   --file ${CHUNK_FILEPATH} \
  #   --outdir "OUTPUT/GRAPHS/${BENCHMARK}" || {
  #   echo "--> SKIPPING ${HARDWARE}: Data incomplete or missing."
  #   continue
  # }
  #
  # ./gem5/configs/PARSEC/compare_graphs.py \
  #   --benchmark ${BENCHMARK} \
  #   --hardwares "Baseline_1RET" "Lazy_4RET" \
  #   --dirs ./gem5/configs/PARSEC/1MiB_1RET_STTRAM/${BENCHMARK} ./gem5/configs/PARSEC/1MiB_4RET_STTRAM/${BENCHMARK} \
  #   --outdir "OUTPUT/COMPARISONS" || {
  #   echo "--> SKIPPING ${HARDWARE}: Data incomplete or missing."
  #   continue
  # }

done

echo "DONE"
