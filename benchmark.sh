#!/bin/bash

#SBATCH --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --time=71:59:00
#SBATCH --mem=32GB

##SBATCH -p long
##SBATCH --mem=28GB
##SBATCH --time=6-23:59:00

set -e

GEM5_DIR=./gem5
SIF_PATH=./gem5-v25-0.sif
PARSEC_BENCHMARKS_DIR=./PARSEC_BENCHMARKS
X86_SYSTEM_DIR=./X86_SYSTEM
ISA=X86
VARIANT=opt

BENCHMARK=$1
HARDWARE=$2
INPUT=${BENCHMARK}_16c_simmedium.rcS
# INPUT=${BENCHMARK}_16c_test.rcS

OUTPUT_LOG=OUTPUT/${BENCHMARK}
mkdir -p ${OUTPUT_LOG}

module load gcc

# LOG_FILE="${OUTPUT_LOG}/${HARDWARE}.log"

singularity exec \
    --bind $GEM5_DIR:/gem5 \
    --bind $PARSEC_BENCHMARKS_DIR:/parsec \
    --bind $X86_SYSTEM_DIR:/x86 \
    $SIF_PATH \
    /gem5/build/$ISA/gem5.$VARIANT \
    --outdir=/gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK} \
    /gem5/configs/PARSEC/hardware_config.py --benchmark=${BENCHMARK} --input=${INPUT} --hardware=${HARDWARE}

# /gem5/configs/PARSEC/hardware_config.py --benchmark=${BENCHMARK} --input=${INPUT} --hardware=${HARDWARE} >"${LOG_FILE}" 2>&1
