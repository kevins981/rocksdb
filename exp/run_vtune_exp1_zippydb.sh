#!/bin/bash

RESULT_DIR="/ssd1/songxin8/thesis/rocksdb/vtune/exp1_zippydb/" 
DB_DIR="/ssd1/songxin8/thesis/rocksdb/rocksdb/tmp/zippydb/"

STREADY_STATE_DURATION=900
# the amount of time it takes for the block cache in DRAM to be full.
# this value is obtained by monitoring top and measuring the time duration.
# 32GB block cache on ZippyDB workload takes approx 1000s to warmup.
WARMUP_DURATION=1000 
# need to run the workload for this much time in total. The warmup duration will not be profiled
TOTAL_DURATION=$(expr $STREADY_STATE_DURATION + $WARMUP_DURATION)

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

  VTUNE_HOTSPOT_COMMON="/opt/intel/oneapi/vtune/2022.3.0/bin64/vtune -collect hotspots -start-paused \
       -data-limit=10000 -result-dir ${OUTFILE}_hotspot \
       --app-working-dir=/ssd1/songxin8/thesis/rocksdb/rocksdb/"

  # setting mem-object-size-min-thres=1MB limit to reduce the size of the vtuen result file on disk.
  VTUNE_MEMACC_COMMON="/opt/intel/oneapi/vtune/2022.3.0/bin64/vtune -collect memory-access -start-paused \
       -knob sampling-interval=100 -knob analyze-mem-objects=true -knob analyze-openmp=true \
       -knob mem-object-size-min-thres=1048576 \
       -data-limit=10000 -result-dir ${OUTFILE}_memacc\
       --app-working-dir=/ssd1/songxin8/thesis/rocksdb/rocksdb/"

  pushd ..
  ####### hotspot analysis
  ${VTUNE_HOTSPOT_COMMON} -- /usr/bin/numactl --membind=${NODE} --cpunodebind=0 \
      ./db_bench --benchmarks="mixgraph,resetstats,mixgraph,stats" --cache_size=34359738368 \
      --db=${DB_DIR} --wal_dir=${DB_DIR}/WAL_LOG \
      --cache_numshardbits=6 -use_existing_db=1 -use_direct_io_for_flush_and_compaction=true \
      -use_direct_reads=true -keyrange_dist_a=14.18 -keyrange_dist_b=-2.917 -keyrange_dist_c=0.0164 -keyrange_dist_d=-0.08082 \
      -keyrange_num=30 -value_k=0.2615 -value_sigma=25.45 -iter_k=2.517 -iter_sigma=14.236 \
      -mix_get_ratio=0.85 -mix_put_ratio=0.14 -mix_seek_ratio=0.01 \
      -sine_mix_rate_interval_milliseconds=5000 -sine_a=1000 -sine_b=0.00000073 -sine_d=450000 \
      --perf_level=2 -num=524288000 -key_size=48 --bloom_bits=10 --write_buffer_size=1073741824 \
      --max_bytes_for_level_base=10737418240 --max_write_buffer_number=40 \
      --open_files=-1 --statistics --duration=${TOTAL_DURATION} &

  VTUNE_PID=$!

  echo "[INFO] Sleeping for ${WARMUP_DURATION} to wait for the DRAM cache to warmup. Vtune profiling is not running right now."
  sleep ${WARMUP_DURATION}

  echo "[INFO] Warmup complete. Resuming Vtune profiling."
  /opt/intel/oneapi/vtune/2022.3.0/bin64/vtune -command resume -r ${OUTFILE}_hotspot

  echo "[INFO] Waiting for vtune to finish."
  wait $VTUNE_PID

  popd
  
  clean_cache

  pushd ..

  ####### memory access analysis

  # Only need to run one mixgraph benchmark, since we do not need to 
  # resetstats for vtune profiling
  ${VTUNE_MEMACC_COMMON} -- /usr/bin/numactl --membind=${NODE} --cpunodebind=0 \
      ./db_bench --benchmarks="mixgraph,stats" --cache_size=34359738368 \
      --db=${DB_DIR} --wal_dir=${DB_DIR}/WAL_LOG \
      --cache_numshardbits=6 -use_existing_db=1 -use_direct_io_for_flush_and_compaction=true \
      -use_direct_reads=true -keyrange_dist_a=14.18 -keyrange_dist_b=-2.917 -keyrange_dist_c=0.0164 -keyrange_dist_d=-0.08082 \
      -keyrange_num=30 -value_k=0.2615 -value_sigma=25.45 -iter_k=2.517 -iter_sigma=14.236 \
      -mix_get_ratio=0.85 -mix_put_ratio=0.14 -mix_seek_ratio=0.01 \
      -sine_mix_rate_interval_milliseconds=5000 -sine_a=1000 -sine_b=0.00000073 -sine_d=450000 \
      --perf_level=2 -num=524288000 -key_size=48 --bloom_bits=10 --write_buffer_size=1073741824 \
      --max_bytes_for_level_base=10737418240 --max_write_buffer_number=40 \
      --open_files=-1 --statistics --duration=${TOTAL_DURATION} &

  VTUNE_PID=$!

  echo "[INFO] Sleeping for ${WARMUP_DURATION} to wait for the DRAM cache to warmup. Vtune profiling is not running right now."
  sleep ${WARMUP_DURATION}

  echo "[INFO] Warmup complete. Resuming Vtune profiling."
  /opt/intel/oneapi/vtune/2022.3.0/bin64/vtune -command resume -r ${OUTFILE}_memacc

  echo "[INFO] Waiting for vtune to finish."
  wait $VTUNE_PID

  popd
}

##############
# Script start
##############
trap clean_up SIGHUP SIGINT SIGTERM

[[ $EUID -ne 0 ]] && echo "This script must be run using sudo or as root." && exit 1

mkdir -p $RESULT_DIR

clean_cache
run_zippydb "${RESULT_DIR}/zippydb_allnode0" $workload 0
clean_cache
run_zippydb "${RESULT_DIR}/zippydb_allnode1" $workload 1
