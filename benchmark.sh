#!/bin/bash

#SBATCH --nodes=1
#SBATCH --cpus-per-task=1

#SBATCH --time=71:59:00
#SBATCH --mem=42GB

set -e

GEM5_DIR=./gem5
SIF_PATH=./gem5-v25-0.sif
PARSEC_BENCHMARKS_DIR=./PARSEC_BENCHMARKS
X86_SYSTEM_DIR=./X86_SYSTEM
ISA=X86
VARIANT=opt

BENCHMARK=$1
HARDWARE=$2
INPUT=$3
PROPERTY=$4

OUTPUT_LOG=OUTPUT/${BENCHMARK}
mkdir -p ${OUTPUT_LOG}

module load gcc

if [ ! -f ${PARSEC_BENCHMARKS_DIR}/parsec-2.1-alpha-files/${INPUT} ]; then
  echo "${INPUT} not found"
  exit 2
fi

# LOG_FILE="${OUTPUT_LOG}/${HARDWARE}.log"
# --debug-flags=RubyCache --debug-start=1515900000 \
# --debug-flags=RubySlicc,ProtocolTrace,RubyCache \
# --debug-start=5450000000000 \
# --debug-file=trace.log \
# --debug-flags=ProtocolTrace,RubySlicc,RubyCache \
# --debug-start=5760000000000 \
# --debug-file=trace.log \

singularity exec \
  --bind $GEM5_DIR:/gem5 \
  --bind $PARSEC_BENCHMARKS_DIR:/parsec \
  --bind $X86_SYSTEM_DIR:/x86 \
  $SIF_PATH \
  /gem5/build/$ISA/gem5.$VARIANT \
  --outdir=/gem5/configs/PARSEC/${HARDWARE}/${PROPERTY}/${BENCHMARK} \
  /gem5/configs/PARSEC/hardware_config.py --benchmark=${BENCHMARK} --input=${INPUT} --hardware=${HARDWARE}

# /gem5/configs/PARSEC/hardware_config.py --benchmark=${BENCHMARK} --input=${INPUT} --hardware=${HARDWARE} >"${LOG_FILE}" 2>&1
