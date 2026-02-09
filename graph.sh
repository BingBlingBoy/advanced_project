#!/bin/bash

#SBATCH --nodes=1
#SBATCH --time=00:05:00
#SBATCH --output=OUTPUT/graph.out
#SBATCH --cpus-per-task=8

set -e

module load python

for HARDWARE in "4MiB_SRAM_ISO_AREA" "4MiB_STTRAM" "8MiB_SRAM_ISO_CAP" "8MiB_STTRAM"; do
    BENCHMARK=$1

    IPC_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/ipc_log.csv.gz
    SET_ACCESSES_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/set_access_log.csv.gz
    L2_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/l2_stats_log.csv.gz

    ./gem5/configs/PARSEC/ipc_graph.py --benchmark ${BENCHMARK} --hardware ${HARDWARE} --file ${IPC_FILEPATH}
    ./gem5/configs/PARSEC/set_accesses_graph.py --benchmark ${BENCHMARK} --hardware ${HARDWARE} --file ${SET_ACCESSES_FILEPATH}
    ./gem5/configs/PARSEC/plot_l2_stats.py --benchmark ${BENCHMARK} --hardware ${HARDWARE} --file ${L2_FILEPATH}
done
