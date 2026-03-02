#!/bin/bash

#SBATCH --nodes=1
#SBATCH --output=OUTPUT/gem5_run.out
#SBATCH --cpus-per-task=1
#SBATCH --time=00:10:00

set -e

BENCHMARK=$1
RUN_SCRIPT=./benchmark.sh
INPUT=${BENCHMARK}_16c_simmedium.rcS
# INPUT=${BENCHMARK}_16c_test.rcS

OUTPUT_LOG=OUTPUT/${BENCHMARK}
mkdir -p ${OUTPUT_LOG}

module load gcc

for HARDWARE in "1MiB_SRAM" "1MiB_STTRAM"; do
    sbatch --output=${OUTPUT_LOG}/${HARDWARE}.log -J ${BENCHMARK}_${HARDWARE} ${RUN_SCRIPT} ${BENCHMARK} ${HARDWARE} ${INPUT}
done
