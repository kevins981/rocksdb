  clean_cache
  run_microbench 
#!/bin/bash

DB_DIR="/ssd1/songxin8/thesis/rocksdb/rocksdb/tmp/microbench"

RESULT_DIR="/ssd1/songxin8/thesis/rocksdb/rocksdb/exp/create_db/"

#declare -a WORKLOAD_LIST=("zippydb" "up2x")
#declare -a WORKLOAD_LIST=("USR" "VAR")

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

create_db_microbench () { 
  pushd ..   
  # load 
  /usr/bin/time -v ./db_bench --benchmarks="fillrandom,stats" \
      --use_existing_db=0 --disable_auto_compactions=1 --sync=0 \
      --max_background_jobs=16 --max_write_buffer_number=8 \
      --allow_concurrent_memtable_write=false --level0_file_num_compaction_trigger=10485760 \
      --level0_slowdown_writes_trigger=10485760 --level0_stop_writes_trigger=10485760 \
      --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache \
      --db=${DB_DIR} --wal_dir=${DB_DIR}/WAL_LOG \
      --num=262144000 --key_size=20 --value_size=400 --block_size=8192 \
      --cache_size=6442450944 --cache_numshardbits=6 --compression_max_dict_bytes=0 \
      --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 \
      --write_buffer_size=134217728 --target_file_size_base=134217728 \
      --max_bytes_for_level_base=1073741824 --verify_checksum=1 \
      --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 \
      --statistics --stats_per_interval=1 --histogram=1 --memtablerep=skip_list --bloom_bits=10 \
      --open_files=-1 --subcompactions=1 --compaction_style=0 --num_levels=8 \
      --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true \
      --pin_l0_filter_and_index_blocks_in_cache=1 --threads=1 --memtablerep=vector \
      --allow_concurrent_memtable_write=false --disable_wal=1

  # compact 
  ./db_bench --benchmarks="compact,stats" --use_existing_db=1 \
      --disable_auto_compactions=1 --sync=0 --level0_file_num_compaction_trigger=4 \
      --level0_slowdown_writes_trigger=20 --level0_stop_writes_trigger=30 \
      --max_background_jobs=16 --max_write_buffer_number=8 \
      --undefok=use_blob_cache,use_shared_block_and_blob_cache,blob_cache_size,blob_cache_numshardbits,prepopulate_blob_cache,multiread_batched,cache_low_pri_pool_ratio,prepopulate_block_cache \
      --db=${DB_DIR} --wal_dir=${DB_DIR}/WAL_LOG \
      --num=262144000 --key_size=20 --value_size=400 --block_size=8192 \
      --cache_size=34359738368 --cache_numshardbits=6 --compression_max_dict_bytes=0 \
      --compression_ratio=0.5 --bytes_per_sync=1048576 --benchmark_write_rate_limit=0 \
      --write_buffer_size=134217728 --target_file_size_base=134217728 \
      --max_bytes_for_level_base=1073741824 --verify_checksum=1 \
      --delete_obsolete_files_period_micros=62914560 --max_bytes_for_level_multiplier=8 \
      --statistics --report_interval_seconds=1 --histogram=1 --memtablerep=skip_list \
      --bloom_bits=10 --open_files=-1 --subcompactions=1 --compaction_style=0 \
      --num_levels=8 --min_level_to_compress=-1 --level_compaction_dynamic_level_bytes=true \
      --pin_l0_filter_and_index_blocks_in_cache=1 --threads=1
  popd


}


##############
# Script start
##############
trap clean_up SIGHUP SIGINT SIGTERM

[[ $EUID -ne 0 ]] && echo "This script must be run using sudo or as root." && exit 1

mkdir -p $RESULT_DIR

# All allocations on node 0
for workload in "${WORKLOAD_LIST[@]}"
do
  clean_cache
  create_db_microbench 
  #clean_cache
  #create_db_zippdy 
done
