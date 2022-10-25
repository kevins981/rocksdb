#!/bin/bash

RESULT_DIR="/ssd1/songxin8/thesis/rocksdb/vtune/exp1_microbench/" 
DB_DIR="/ssd1/songxin8/thesis/rocksdb/rocksdb/tmp/microbench"

# in seconds
DURATION=900

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

run_microbench_readrandom () { 
  OUTFILE=$1 #first argument
  NODE=$2

  # setting mem-object-size-min-thres=1MB limit to reduce the size of the vtuen result file on disk.
  VTUNE_MEMACC_COMMON="/opt/intel/oneapi/vtune/2022.3.0/bin64/vtune -collect memory-access \
       -knob sampling-interval=100 -knob analyze-mem-objects=true -knob analyze-openmp=true \
       -knob mem-object-size-min-thres=1048576 \
       -data-limit=5000 -result-dir ${OUTFILE}_memacc\
       --app-working-dir=/ssd1/songxin8/thesis/rocksdb/rocksdb/"

  VTUNE_HOTSPOT_COMMON="/opt/intel/oneapi/vtune/2022.3.0/bin64/vtune -collect hotspots \
       -data-limit=5000 -result-dir ${OUTFILE}_hotspot \
       --app-working-dir=/ssd1/songxin8/thesis/rocksdb/rocksdb/"

  pushd ..

  ${VTUNE_HOTSPOT_COMMON} -- /usr/bin/numactl --membind=${NODE} --cpunodebind=0 \
      -- ./db_bench --benchmarks="readrandom,stats" --use_existing_db=1 \
      --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 \
      --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 \
      --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache \
      --db=${DB_DIR} --wal_dir=${DB_DIR}/WAL_LOG \
      --num=262144000 --key_size=20 --value_size=400 --block_size=8192 --cache_size=34359738368 \
      --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 \
      --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 \
      --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 \
      --verify_checksum=1 --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 \
      --statistics --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 \
      --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 \
      --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 \
      --duration=${DURATION} --threads=32 

  popd
  
  clean_cache

  pushd ..

  ${VTUNE_MEMACC_COMMON} -- /usr/bin/numactl --membind=${NODE} --cpunodebind=0 \
      -- ./db_bench --benchmarks="readrandom,stats" --use_existing_db=1 \
      --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 \
      --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 \
      --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache \
      --db=${DB_DIR} --wal_dir=${DB_DIR}/WAL_LOG \
      --num=262144000 --key_size=20 --value_size=400 --block_size=8192 --cache_size=34359738368 \
      --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 \
      --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 \
      --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 \
      --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 \
      --statistics --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 \
      --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 \
      --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 \
      --duration=${DURATION} --threads=32 
  popd
}

run_microbench_scan () { 
  OUTFILE=$1 #first argument
  NODE=$2

  VTUNE_MEMACC_COMMON="/opt/intel/oneapi/vtune/2022.3.0/bin64/vtune -collect memory-access \
       -knob sampling-interval=100 -knob analyze-mem-objects=true -knob analyze-openmp=true \
       -knob mem-object-size-min-thres=1048576 \
       -data-limit=5000 -result-dir ${OUTFILE}_memacc \
       --app-working-dir=/ssd1/songxin8/thesis/rocksdb/rocksdb/"

  VTUNE_HOTSPOT_COMMON="/opt/intel/oneapi/vtune/2022.3.0/bin64/vtune -collect hotspots \
       -data-limit=5000 -result-dir ${OUTFILE}_hotspot \
       --app-working-dir=/ssd1/songxin8/thesis/rocksdb/rocksdb/"

  pushd ..

  ${VTUNE_HOTSPOT_COMMON} -- /usr/bin/numactl --membind=${NODE} --cpunodebind=0 \
      -- ./db_bench --benchmarks="seekrandom,stats" --use_existing_db=1 \
      --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 \
      --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 \
      --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache \
      --db=${DB_DIR} --wal_dir=${DB_DIR}/WAL_LOG \
      --num=262144000 --key_size=20 --value_size=400 --block_size=8192 --cache_size=34359738368 \
      --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 \
      --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 \
      --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 \
      --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 \
      --statistics --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 \
      --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 \
      --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 \
      --duration=${DURATION} --threads=32 --seek_nexts=10 --reverse_iterator=false 

  popd
  
  clean_cache

  pushd ..

  ${VTUNE_MEMACC_COMMON} -- /usr/bin/numactl --membind=${NODE} --cpunodebind=0 \
      -- ./db_bench --benchmarks="seekrandom,stats" --use_existing_db=1 \
      --level0_file_num_compaction_trigger=4 --level0_slowdown_writes_trigger=20 \
      --level0_stop_writes_trigger=30 --max_background_jobs=16 --max_write_buffer_number=8 \
      --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache \
      --db=${DB_DIR} --wal_dir=${DB_DIR}/WAL_LOG \
      --num=262144000 --key_size=20 --value_size=400 --block_size=8192 --cache_size=34359738368 \
      --cache_numshardbits=6 --compression_max_dict_bytes=0 --compression_ratio=0.5 \
      --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 --write_buffer_size=134217728 \
      --target_file_size_base=134217728 --max_bytes_for_level_base=1073741824 --verify_checksum=1 \
      --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 \
      --statistics --histogram=1 --memtablerep=skip_list --bloom_bits=10 --open_files=-1 \
      --subcompactions=1 --compaction_style=0 --num_levels=8 --min_level_to_compress=-1 \
      --level_compaction_dynamic_level_bytes=true --pin_l0_filter_and_index_blocks_in_cache=1 \
      --duration=${DURATION} --threads=32 --seek_nexts=10 --reverse_iterator=false

  popd
}


##############
# Script start
##############
trap clean_up SIGHUP SIGINT SIGTERM

[[ $EUID -ne 0 ]] && echo "This script must be run using sudo or as root." && exit 1

mkdir -p $RESULT_DIR

clean_cache
run_microbench_scan "${RESULT_DIR}/scan_allnode0" $workload 0
clean_cache
run_microbench_scan "${RESULT_DIR}/scan_allnode1" $workload 1
clean_cache
run_microbench_readrandom "${RESULT_DIR}/readrandom_allnode0" $workload 0
clean_cache
run_microbench_readrandom "${RESULT_DIR}/readrandom_allnode1" $workload 1
