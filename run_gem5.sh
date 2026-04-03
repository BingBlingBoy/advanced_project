#!/bin/bash

#SBATCH --nodes=1
#SBATCH --output=OUTPUT/gem5_run.out
#SBATCH --cpus-per-task=1
#SBATCH --time=00:10:00

set -e

if [[ $# -eq 0 ]]; then
  echo "Provide a benchmark"
  exit 1
fi

BENCHMARK=$1
RUN_SCRIPT=./benchmark.sh
INPUT=${BENCHMARK}_16c_simmedium.rcS
# INPUT=${BENCHMARK}_16c_test.rcS

OUTPUT_LOG=OUTPUT/${BENCHMARK}
mkdir -p ${OUTPUT_LOG}

module load gcc

AVAILABLE_HARDWARE=(
  # "4MiB_SRAM"
  # "4MiB_1RET_STTRAM"
  # "4MiB_2RET_STTRAM"
  # "4MiB_3RET_STTRAM"
  "4MiB_base_4RET_STTRAM"
  "4MiB_custom_4RET_STTRAM"
  # "8MiB_SRAM"
  # "8MiB_1RET_STTRAM"
  # "8MiB_2RET_STTRAM"
  # "8MiB_3RET_STTRAM"
  # "8MiB_4RET_STTRAM"
)

for HARDWARE in ${AVAILABLE_HARDWARE[@]}; do
  # Debug
  # sbatch --time=00:05:00 --output=${OUTPUT_LOG}/${HARDWARE}.log -J ${BENCHMARK}_${HARDWARE} ${RUN_SCRIPT} ${BENCHMARK} ${HARDWARE} ${INPUT}

  sbatch --output=${OUTPUT_LOG}/${HARDWARE}.log -J ${BENCHMARK}_${HARDWARE} ${RUN_SCRIPT} ${BENCHMARK} ${HARDWARE} ${INPUT}
done
