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

for HARDWARE in "4MiB_SRAM" "4MiB_1RET_STTRAM" "4MiB_2RET_STTRAM" "4MiB_3RET_STTRAM" "4MiB_4RET_STTRAM"; do
    sbatch --output=${OUTPUT_LOG}/${HARDWARE}.log -J ${BENCHMARK}_${HARDWARE} ${RUN_SCRIPT} ${BENCHMARK} ${HARDWARE} ${INPUT}
done
