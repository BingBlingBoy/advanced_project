#!/bin/bash

#SBATCH --nodes=1
#SBATCH --time=00:05:00
#SBATCH --output=OUTPUT/graph.out
#SBATCH --cpus-per-task=8

module load python

# HARDWARE choices
# - 4MiB_SRAM_ISO_AREA
# - 4MiB_STTRAM
# - 8MiB_SRAM_ISO_CAP
# - 8MiB_STTRAM
HARDWARE=4MiB_STTRAM
BENCHMARK=blackscholes
FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/ipc_log.csv.gz

./gem5/configs/PARSEC/ipc_graph.py --benchmark ${BENCHMARK} --hardware ${HARDWARE} --file ${FILEPATH}
