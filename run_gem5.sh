#!/bin/bash

#SBATCH --job-name=gem5_sim
#SBATCH --nodes=1
#SBATCH --time=00:59:00
#SBATCH --output=gem5_run_%j.out
#SBATCH --cpus-per-task=8
#SBATCH --mem=64GB

set -e

GEM5_DIR=./gem5
SIF_PATH=./gem5-v25-0.sif
ISA=X86
VARIANT=opt

module load gcc

find . -maxdepth 1 -name "gem5_run*" -not -name "gem5_run_${SLURM_JOB_ID}.out" -delete

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
    --outdir=/gem5/configs/SRAM/Separate_Latency_classic_outputs \
    /gem5/configs/SRAM/components.py
    # /gem5/configs/SRAM/level2.py --l2_size='1MB' --l1d_size='128kB'

