#!/bin/bash

# import common functions
if [ "$BIGMEMBENCH_COMMON_PATH" = "" ] ; then
  echo "ERROR: bigmembench_common script not found. BIGMEMBENCH_COMMON_PATH is $BIGMEMBENCH_COMMON_PATH"
  echo "Have you set BIGMEMBENCH_COMMON_PATH correctly? Are you using sudo -E instead of just sudo?"
  exit 1
fi
source ${BIGMEMBENCH_COMMON_PATH}/run_exp_common.sh

DB_DIR="/ssd1/songxin8/thesis/rocksdb/rocksdb/tmp/"                                                      
RESULT_DIR="/ssd1/songxin8/thesis/rocksdb/rocksdb/exp/exp_endToEnd/" 

# The amount of time to run readrandom and scan
MICROBENCH_DURATION=900

# The amount of time to run mixgraph (zippyDB)
MIXGRAPH_STEADY_STATE_DURATION=900
# the amount of time it takes for the block cache in DRAM to be full.
# this value is obtained by monitoring top and measuring the time duration 
MIXGRAPH_WARMUP_DURATION=1000
# the total duration to run the rocksdb benchmark is the max of the two.
# this is because we are using --benchmarks="mixgraph,resetstats,mixgraph",
# where the first mixgraph is meant to warmup the DRAM cache, the second for
# steady state profiling.
# The --duration option sets the execution duration for both mixgraphs.
# Thus, we run both mixgraphs for the max of WARMUP_DURATION and STEADY_STATE_DURATION.
# (I did not find a way to specify two different durations)
MIXGRAPH_TOTAL_DURATION=$(( $MIXGRAPH_WARMUP_DURATION > $MIXGRAPH_STEADY_STATE_DURATION ? $MIXGRAPH_WARMUP_DURATION : $MIXGRAPH_STEADY_STATE_DURATION ))

declare -a WORKLOAD_LIST=("readrandom" "scan" "zippydb")

clean_up () {
    echo "Cleaning up. Kernel PID is $EXE_PID, numastat PID is $NUMASTAT_PID, top PID is $TOP_PID."
    # Perform program exit housekeeping
    kill $NUMASTAT_PID
    kill $TOP_PID
    kill $EXE_PID
    exit
}

run_app () { 
  OUTFILE_NAME=$1
  WORKLOAD=$2
  CONFIG=$3

  OUTFILE_PATH="${RESULT_DIR}/${OUTFILE_NAME}"

  if [[ "$CONFIG" == "ALL_LOCAL" ]]; then
    # All local config: place both data and compute on node 1
    COMMAND_COMMON="/usr/bin/time -v /usr/bin/numactl --membind=1 --cpunodebind=1"
  elif [[ "$CONFIG" == "EDGES_ON_REMOTE" ]]; then
    # place edges array on node 1, rest on node 0
    COMMAND_COMMON="/usr/bin/time -v /usr/bin/numactl --membind=0 --cpunodebind=0"
  elif [[ "$CONFIG" == "TPP" ]]; then
    # only use node 0 CPUs and let TPP decide how memory is placed
    COMMAND_COMMON="/usr/bin/time -v /usr/bin/numactl --cpunodebind=0"
  elif [[ "$CONFIG" == "AUTONUMA" ]]; then
    COMMAND_COMMON="/usr/bin/time -v /usr/bin/numactl --cpunodebind=0"
  else
    echo "Error! Undefined configuration $CONFIG"
    exit 1
  fi

  pushd ..

  case $WORKLOAD in
    "readrandom")
      ${COMMAND_COMMON} \
      -- ./db_bench --benchmarks="readrandom,stats" --use_existing_db=1 \
      --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 \
      --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 \
      --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache \
      --db=${DB_DIR}/microbench --wal_dir=${DB_DIR}/microbench/WAL_LOG \
      --num=262144000 --key_size=20 --value_size=400 --block_size=8192 --cache_size=34359738368 \
      --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 \
      --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 \
      --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 \
      --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 \
      --statistics --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 \
      --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 \
      --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 \
      --duration=${MICROBENCH_DURATION} --threads=32 &> ${OUTFILE_PATH} &
      ;;
    "scan")
      ${COMMAND_COMMON} \
      -- ./db_bench --benchmarks="seekrandom,stats" --use_existing_db=1 \
      --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 \
      --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 \
      --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache \
      --db=${DB_DIR}/microbench --wal_dir=${DB_DIR}/microbench/WAL_LOG \
      --num=262144000 --key_size=20 --value_size=400 --block_size=8192 --cache_size=34359738368 \
      --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 \
      --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 \
      --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 \
      --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 \
      --statistics --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 \
      --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 \
      --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 \
      --duration=${MICROBENCH_DURATION} --threads=32 --seek_nexts=10 --reverse_iterator=false &> ${OUTFILE_PATH} &
      ;;
    "zippydb")
      ${COMMAND_COMMON} \
      -- ./db_bench --benchmarks="mixgraph,resetstats,mixgraph,stats" --cache_size=34359738368 \
      --cache_numshardbits=6 -use_existing_db=1 \
      --db=${DB_DIR}/zippydb --wal_dir=${DB_DIR}/zippydb/WAL_LOG \
      -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true \
      -keyrange_dist_a=14.18 -keyrange_dist_b=-2.917 -keyrange_dist_c=0.0164 -keyrange_dist_d=-0.08082 \
      -keyrange_num=30 -value_k=0.2615 -value_sigma=25.45 -iter_k=2.517 -iter_sigma=14.236 \
      -mix_get_ratio=0.85 -mix_put_ratio=0.14 -mix_seek_ratio=0.01 \
      -sine_mix_rate_interval_milliseconds=5000 -sine_a=1000 -sine_b=0.00000073 -sine_d=450000 \
      --perf_level=2 -reads=4200000 -num=524288000 -key_size=48 --bloom_bits=10 \
      --write_buffer_size=1073741824 --max_bytes_for_level_base=10737418240 --max_write_buffer_number=40 --open_files=-1 \
      --statistics --duration=${MIXGRAPH_TOTAL_DURATION} &> ${OUTFILE_PATH} &
      ;;
    *)
      echo -n "ERROR: Unknown executable $WORKLOAD"
      exit 1
      ;;
  esac

  TIME_PID=$! 
  EXE_PID=$(pgrep -P $TIME_PID)

  echo "RocksDB PID is ${EXE_PID}"
  echo "start" > ${OUTFILE_PATH}-numastat 
  while true; do numastat -p $EXE_PID >> ${OUTFILE_PATH}-numastat; sleep 5; done &
  NUMASTAT_PID=$!
  top -b -d 10 -1 -p $EXE_PID > ${OUTFILE_PATH}-toplog &
  TOP_PID=$!

  echo "Waiting for rocksDB benchmark to complete (PID is ${EXE_PID}). Log is written to ${OUTFILE_PATH}, PID is ${NUMASTAT_PID}. Top log PID is ${TOP_PID}."
  wait $TIME_PID
  kill $NUMASTAT_PID
  kill $TOP_PID
  popd
}

##############
# Script start
##############
trap clean_up SIGHUP SIGINT SIGTERM

[[ $EUID -ne 0 ]] && echo "This script must be run using sudo or as root." && exit 1

mkdir -p $RESULT_DIR

# All allocations on node 0
disable_numa
for workload in "${WORKLOAD_LIST[@]}"
do
  clean_cache
  LOGFILE_NAME=$(gen_file_name "rocksdb" "${workload}" "${MEMCONFIG}_allLocal")
  run_app ${LOGFILE_NAME} ${workload} "ALL_LOCAL"
done


# AutoNUMA
enable_autonuma
for workload in "${WORKLOAD_LIST[@]}"
do
  clean_cache
  LOGFILE_NAME=$(gen_file_name "rocksdb" "${workload}" "${MEMCONFIG}_autonuma")
  run_app ${LOGFILE_NAME} ${workload} "AUTONUMA"
done

# TPP
enable_tpp
for workload in "${WORKLOAD_LIST[@]}"
do
  clean_cache
  LOGFILE_NAME=$(gen_file_name "rocksdb" "${workload}" "${MEMCONFIG}_tpp")
  run_app ${LOGFILE_NAME} ${workload} "TPP"
done

