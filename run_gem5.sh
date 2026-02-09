#!/bin/bash

#SBATCH --nodes=1
#SBATCH --output=OUTPUT/gem5_run.out
#SBATCH --cpus-per-task=1
#SBATCH --time=00:09:00

set -e

GEM5_DIR=./gem5
SIF_PATH=./gem5-v25-0.sif
PARSEC_BENCHMARKS_DIR=./PARSEC_BENCHMARKS
X86_SYSTEM_DIR=./X86_SYSTEM
ISA=X86
VARIANT=opt

BENCHMARK=$1
RUN_SCRIPT=./benchmark.sh
INPUT=${BENCHMARK}_16c_simmedium.rcS
# INPUT=${BENCHMARK}_16c_test.rcS

OUTPUT_LOG=OUTPUT/${BENCHMARK}
mkdir -p ${OUTPUT_LOG}

module load gcc

for HARDWARE in "4MiB_SRAM" "4MiB_STTRAM" "8MiB_SRAM" "8MiB_STTRAM"; do
    sbatch --output=${OUTPUT_LOG}/${HARDWARE}.log -J ${BENCHMARK}_${HARDWARE} ${RUN_SCRIPT} ${BENCHMARK} ${HARDWARE}
done
