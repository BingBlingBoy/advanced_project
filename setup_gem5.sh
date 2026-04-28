#!/bin/bash

#SBATCH --job-name=gem5_sim
#SBATCH --nodes=1
#SBATCH --time=02:00:00
#SBATCH --output=OUTPUT/gem5_compilation.out
#SBATCH --cpus-per-task=16

set -e

OUTPUT_DIR=OUTPUT
mkdir -p $OUTPUT_DIR

GEM5_DIR=./gem5
PARSEC_BENCHMARKS_DIR=./PARSEC_BENCHMARKS
SIF_PATH=./gem5-v25-0.sif
ISA=X86
# VARIANT=opt
VARIANT=fast

module load gcc

find . -maxdepth 1 -name "gem5_compilation*" -not -name "gem5_compilation_${SLURM_JOB_ID}.out" -delete

singularity exec \
  --bind $GEM5_DIR:/gem5 \
  --bind $PARSEC_BENCHMARKS_DIR:/parsec \
  $SIF_PATH \
  bash -c "cd /gem5 && \
  scons defconfig build/$ISA build_opts/$ISA && \
  scons setconfig build/$ISA RUBY_PROTOCOL_STTRAM=y SLICC_HTML=y && \
  touch src/mem/ruby/protocol/*.sm && \
  scons build/$ISA/gem5.$VARIANT -j16"

singularity exec \
  --bind $GEM5_DIR:/gem5 \
  --bind $PARSEC_BENCHMARKS_DIR:/parsec \
  $SIF_PATH \
  bash -c "cd /gem5 &&  scons build/$ISA/compile_commands.json -j16"

echo "Applying Neovim LSP and SSHFS path fixes..."

JSON_FILE="$GEM5_DIR/build/$ISA/compile_commands.json"

sed -i.bak 's|"directory": "/gem5"|"directory": "/home/ckdbarnz/.ssh/sesh/gem5"|g' "$JSON_FILE"

cd $GEM5_DIR
ln -sf build/$ISA/compile_commands.json compile_commands.json

echo "Compilation and path formatting complete. Ready for Neovim!"
