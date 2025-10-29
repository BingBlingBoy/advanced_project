#!/bin/bash

#SBATCH --job-name=gem5_sim
#SBATCH --nodes=1
#SBATCH --time=02:59:00
#SBATCH --output=gem5_compililation_%j.out
#SBATCH --cpus-per-task=16
#SBATCH --mem=64GB

set -e

GEM5_DIR=./gem5
SIF_PATH=./gem5-v25-0.sif
ISA=X86
VARIANT=opt

module load gcc

singularity exec \
    --bind $GEM5_DIR:/gem5 \
    $SIF_PATH \
    bash -c "cd /gem5 && scons build/$ISA/gem5.$VARIANT -j$SLURM_CPUS_PER_TASK"

# singularity exec \
#     --bind $GEM5_DIR:/gem5 \
#     $SIF_PATH \
#     bash -c "cd /gem5 && scons build/$ISA/compile_commands.json -j$SLURM_CPUS_PER_TASK"
