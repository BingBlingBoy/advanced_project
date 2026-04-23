#!/bin/bash

#SBATCH --nodes=1
#SBATCH --cpus-per-task=1

#SBATCH --time=1:59:00

set -e

GEM5_DIR=./gem5
SIF_PATH=./gem5-v25-0.sif
PARSEC_BENCHMARKS_DIR=./PARSEC_BENCHMARKS
X86_SYSTEM_DIR=./X86_SYSTEM
ISA=X86
VARIANT=opt

singularity exec \
  --bind $GEM5_DIR:/gem5 \
  --bind $PARSEC_BENCHMARKS_DIR:/parsec \
  --bind $X86_SYSTEM_DIR:/x86 \
  $SIF_PATH \
  /gem5/build/$ISA/gem5.$VARIANT \
  /gem5/configs/PARSEC/fast_test.py # --debug-flags=ProtocolTrace \
# --debug-file=deadlock_trace.log \
