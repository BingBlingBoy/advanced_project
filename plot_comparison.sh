#!/bin/bash

#SBATCH --nodes=1
#SBATCH --time=00:05:00
#SBATCH --output=OUTPUT/plot_compare.out
#SBATCH --cpus-per-task=1

set -e

module load python

# 1. READ ARGUMENTS
BENCHMARK=$1
SRAM_INPUT=$2 # Expecting "4" or "8"
STT_INPUT=$3  # Expecting "4" or "8"

if [ -z "$BENCHMARK" ] || [ -z "$SRAM_INPUT" ] || [ -z "$STT_INPUT" ]; then
    echo "Usage: sbatch plot_comparison.sh <benchmark> <sram_size> <stt_size>"
    exit 1
fi

# 2. RESOLVE SRAM DIRECTORY & LABEL
if [ "$SRAM_INPUT" == "4" ]; then
    SRAM_DIR="4MiB_SRAM_ISO_AREA"
    SRAM_LABEL="4MiB SRAM"
elif [ "$SRAM_INPUT" == "8" ]; then
    SRAM_DIR="8MiB_SRAM_ISO_CAP"
    SRAM_LABEL="8MiB SRAM"
else
    echo "Error: SRAM size must be 4 or 8"
    exit 1
fi

# 3. RESOLVE STT-RAM DIRECTORY & LABEL
if [ "$STT_INPUT" == "4" ]; then
    STT_DIR="4MiB_STTRAM"
    STT_LABEL="4MiB STT-RAM"
elif [ "$STT_INPUT" == "8" ]; then
    STT_DIR="8MiB_STTRAM"
    STT_LABEL="8MiB STT-RAM"
else
    echo "Error: STT-RAM size must be 4 or 8"
    exit 1
fi

echo "=========================================="
echo "Comparing: $BENCHMARK"
echo "SRAM: $SRAM_LABEL"
echo "STT:  $STT_LABEL"
echo "=========================================="

# 4. DEFINE FILE PATHS (Adjust if needed)
BASE_PATH="./gem5/configs/PARSEC"
SRAM_IPC="${BASE_PATH}/${SRAM_DIR}/${BENCHMARK}/ipc_log.csv.gz"
STT_IPC="${BASE_PATH}/${STT_DIR}/${BENCHMARK}/ipc_log.csv.gz"
STT_STATS="${BASE_PATH}/${STT_DIR}/${BENCHMARK}/l2_stats_log.csv.gz"

# 5. RUN PYTHON SCRIPT
python3 ${BASE_PATH}/plot_accurate_comparison.py \
    --benchmark "${BENCHMARK}" \
    --sram-ipc "${SRAM_IPC}" \
    --stt-ipc "${STT_IPC}" \
    --stt-stats "${STT_STATS}" \
    --sram-label "${SRAM_LABEL}" \
    --stt-label "${STT_LABEL}" \
    --output-dir "./COMPARISON_GRAPHS/${BENCHMARK}_${SRAM_INPUT}v${STT_INPUT}"

echo "Done!"
