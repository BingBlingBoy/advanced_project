#!/bin/bash

#SBATCH --nodes=1
#SBATCH --time=00:05:00
#SBATCH --output=OUTPUT/graph.out
#SBATCH --cpus-per-task=8

set -e

module load python

# HARDWARE choices
# - 4MiB_SRAM_ISO_AREA
# - 4MiB_STTRAM
# - 8MiB_SRAM_ISO_CAP
# - 8MiB_STTRAM
for HARDWARE in "4MiB_SRAM_ISO_AREA" "4MiB_STTRAM" "8MiB_SRAM_ISO_CAP" "8MiB_STTRAM"; do
    BENCHMARK=$1
    FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/set_access_log.csv.gz

    ./gem5/configs/PARSEC/set_accesses_graph.py --benchmark ${BENCHMARK} --hardware ${HARDWARE} --file ${FILEPATH}
done
