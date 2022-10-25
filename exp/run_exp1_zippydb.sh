#!/bin/bash

DB_DIR="/ssd1/songxin8/thesis/rocksdb/rocksdb/tmp/zippydb/"
RESULT_DIR="/ssd1/songxin8/thesis/rocksdb/rocksdb/exp/exp1_zippydb/" 

# the desired duration to profile in seconds
STEADY_STATE_DURATION=900
# the amount of time it takes for the block cache in DRAM to be full.
# this value is obtained by monitoring top and measuring the time duration 
WARMUP_DURATION=1000

# the total duration to run the rocksdb benchmark is the max of the two.
# this is because we are using --benchmarks="mixgraph,resetstats,mixgraph",
# where the first mixgraph is meant to warmup the DRAM cache, the second for
# steady state profiling.
# The --duration option sets the execution duration for both mixgraphs.
# Thus, we run both mixgraphs for the max of WARMUP_DURATION and STEADY_STATE_DURATION.
# (I did not find a way to specify two different durations)
TOTAL_DURATION=$(( $WARMUP_DURATION > $STEADY_STATE_DURATION ? $WARMUP_DURATION : $STEADY_STATE_DURATION ))

clean_up () {
    echo "Cleaning up. Kernel PID is $EXE_PID, numastat PID is $LOG_PID."
    # Perform program exit housekeeping
    kill $LOG_PID
    kill $EXE_PID
    exit
}

clean_cache () { 
  echo "Clearing caches..."
  # clean CPU caches 
  ./tools/clear_cpu_cache
  # clean page cache 
  echo 3 > /proc/sys/vm/drop_caches
}

run_zippydb () { 
  OUTFILE=$1 #first argument
  NODE=$2

  echo "Storing output to ${OUTFILE}"

  /usr/bin/time -v /usr/bin/numactl --membind=${NODE} --cpunodebind=0 \
      ../db_bench --benchmarks="mixgraph,resetstats,mixgraph,stats" --cache_size=34359738368 --cache_numshardbits=6 -use_existing_db=1 \
      --db=${DB_DIR} --wal_dir=${DB_DIR}/WAL_LOG \
      -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true \
      -keyrange_dist_a=14.18 -keyrange_dist_b=-2.917 -keyrange_dist_c=0.0164 -keyrange_dist_d=-0.08082 \
      -keyrange_num=30 -value_k=0.2615 -value_sigma=25.45 -iter_k=2.517 -iter_sigma=14.236 \
      -mix_get_ratio=0.85 -mix_put_ratio=0.14 -mix_seek_ratio=0.01 \
      -sine_mix_rate_interval_milliseconds=5000 -sine_a=1000 -sine_b=0.00000073 -sine_d=450000 \
      --perf_level=2 -reads=4200000 -num=524288000 -key_size=48 --bloom_bits=10 \
      --write_buffer_size=1073741824 --max_bytes_for_level_base=10737418240 --max_write_buffer_number=40 --open_files=-1 \
      --statistics --duration=${TOTAL_DURATION} &> ${OUTFILE} &

  # PID of time command
  TIME_PID=$! 
  # get PID of actual kernel, which is a child of time. 
  # This PID is needed for the numastat command
  EXE_PID=$(pgrep -P $TIME_PID)

  echo "RocksDB PID is ${EXE_PID}"
  echo "start" > ${OUTFILE}_numastat 
  while true; do numastat -p $EXE_PID >> ${OUTFILE}_numastat; sleep 5; done &
  LOG_PID=$!

  echo "[INFO] This workload will run for approximately ${TOTAL_DURATION}*2 seconds."

  echo "Waiting for rocksDB benchmark to complete (PID is ${EXE_PID}). Log is written to ${OUTFILE}, PID is ${LOG_PID}"
  wait $TIME_PID
  # kill numastat process
  kill $LOG_PID
}



##############
# Script start
##############
trap clean_up SIGHUP SIGINT SIGTERM

[[ $EUID -ne 0 ]] && echo "This script must be run using sudo or as root." && exit 1

mkdir -p $RESULT_DIR

# All allocations on node 0
clean_cache
run_zippydb "${RESULT_DIR}/zippydb_allnode0" $workload 0
clean_cache
run_zippydb "${RESULT_DIR}/zippydb_allnode1" $workload 1
