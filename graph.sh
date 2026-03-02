#!/bin/bash

#SBATCH --nodes=1
#SBATCH --time=00:05:00
#SBATCH --output=OUTPUT/graph.out
#SBATCH --cpus-per-task=8

set -e

module load python

for HARDWARE in "4MiB_SRAM" "4MiB_STTRAM" "8MiB_SRAM" "8MiB_STTRAM"; do
    BENCHMARK=$1

    IPC_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/ipc_log.csv.gz
    CHUNK_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/chunk.csv.gz
    L2_FILEPATH=./gem5/configs/PARSEC/${HARDWARE}/${BENCHMARK}/l2_stats_log.csv.gz

    # ./gem5/configs/PARSEC/ipc_graph.py --benchmark ${BENCHMARK} --hardware ${HARDWARE} --file ${IPC_FILEPATH}
    # ./gem5/configs/PARSEC/set_accesses_graph.py --benchmark ${BENCHMARK} --hardware ${HARDWARE} --file ${SET_ACCESSES_FILEPATH}
    # ./gem5/configs/PARSEC/plot_l2_stats.py --benchmark ${BENCHMARK} --hardware ${HARDWARE} --file ${L2_FILEPATH}
    ./gem5/configs/PARSEC/power_analysis.py \
        --benchmark ${BENCHMARK} \
        --hardware ${HARDWARE} \
        --file ${CHUNK_FILEPATH} \
        --outdir "OUTPUT/GRAPHS/${BENCHMARK}"
    ./gem5/configs/PARSEC/spatial_plot.py \
        --benchmark ${BENCHMARK} \
        --hardware ${HARDWARE} \
        --file ${CHUNK_FILEPATH} \
        --outdir "OUTPUT/GRAPHS/${BENCHMARK}"
done
