#!/bin/bash

#SBATCH --job-name=cache_workload
##SBATCH --job-name=gem5_sim
#SBATCH --nodes=1
#SBATCH --time=23:59:00
#SBATCH --output=gem5_run_%j.out
#SBATCH --cpus-per-task=8
#SBATCH --mem=64GB

set -e

GEM5_DIR=./gem5
SIF_PATH=./gem5-v25-0.sif
PARSEC_BENCHMARKS_DIR=./PARSEC_BENCHMARKS
X86_SYSTEM_DIR=./X86_SYSTEM
ISA=X86
VARIANT=opt

HARDWARE=8MiB_SRAM_ISO_AREA
BENCHMARK=x264
INPUT=${BENCHMARK}_16c_simmedium.rcS

module load gcc

find . -maxdepth 1 -name "gem5_run*" -not -name "gem5_run_${SLURM_JOB_ID}.out" -delete

# mv gem5_run_${SLURM_JOB_ID}.out ${BENCHMARK}_${SLURM_JOB_ID}.out

singularity exec \
    --bind $GEM5_DIR:/gem5 \
    $SIF_PATH \
    g++ -O2 -static \
        -I /gem5/include \
        -I /gem5/util/m5/src \
        /gem5/util/m5/src/abi/x86/m5op.S \
        /gem5/configs/SRAM/cache_workload.cpp \
        -o /gem5/configs/SRAM/cache_workload

singularity exec \
    --bind $GEM5_DIR:/gem5 \
    $SIF_PATH \
    /gem5/build/$ISA/gem5.$VARIANT \
    --outdir=/gem5/configs/SRAM/custom_workload \
    /gem5/configs/SRAM/components.py

# singularity exec \
#     --bind $GEM5_DIR:/gem5 \
#     --bind $PARSEC_BENCHMARKS_DIR:/parsec \
#     --bind $X86_SYSTEM_DIR:/x86 \
#     $SIF_PATH \
#     /gem5/build/$ISA/gem5.$VARIANT \
#     --outdir=/gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK} \
#     /gem5/configs/PARSEC/hardware_config.py --benchmark=${BENCHMARK} --input=${INPUT} --hardware=${HARDWARE}
