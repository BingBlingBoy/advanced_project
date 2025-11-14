#!/bin/bash

#SBATCH --job-name=gem5_sim
#SBATCH --nodes=1
#SBATCH --time=00:59:00
#SBATCH --output=gem5_compilation_%j.out
#SBATCH --cpus-per-task=52
#SBATCH --mem=64GB

set -e

GEM5_DIR=./gem5
SIF_PATH=./gem5-v25-0.sif
ISA=X86
VARIANT=opt

module load gcc

find . -maxdepth 1 -name "gem5_compilation*" -not -name "gem5_compilation_${SLURM_JOB_ID}.out" -delete

singularity exec \
    --bind $GEM5_DIR:/gem5 \
    $SIF_PATH \
    bash -c "cd /gem5 && scons build/$ISA/gem5.$VARIANT -j$SLURM_CPUS_PER_TASK"

singularity exec \
    --bind $GEM5_DIR:/gem5 \
    $SIF_PATH \
    bash -c "cd /gem5 && scons build/$ISA/compile_commands.json -j$SLURM_CPUS_PER_TASK"

