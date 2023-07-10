#!/bin/bash

# import common functions
if [ "$BIGMEMBENCH_COMMON_PATH" = "" ] ; then
  echo "ERROR: bigmembench_common script not found. BIGMEMBENCH_COMMON_PATH is $BIGMEMBENCH_COMMON_PATH"
  echo "Have you set BIGMEMBENCH_COMMON_PATH correctly? Are you using sudo -E instead of just sudo?"
  exit 1
fi
source ${BIGMEMBENCH_COMMON_PATH}/run_exp_common.sh

DB_DIR="/ssd1/songxin8/thesis/rocksdb/tmp/"
#SOURCE_DB="${DB_DIR}/fillrandom/"
SOURCE_DB="${DB_DIR}/zippydb_medium_cp/"
#RESULT_DIR="exp/exp_lfu_20230426_1258keyrangenum/" 
RESULT_DIR="exp/test"
MEMCONFIG="16threads16GB"
DURATION=4000
NUM_THREADS=16
NUM_ITERS=1

run_app () { 
  OUTFILE_NAME=$1
  WORKLOAD=$2
  CONFIG=$3
  DB_NAME=$4

  OUTFILE_PATH="${RESULT_DIR}/${OUTFILE_NAME}"

  if [[ "$CONFIG" == "ALL_LOCAL" ]]; then
    # All local config: place both data and compute on node 1
    COMMAND_COMMON="/usr/bin/time -v /usr/bin/numactl --membind=0 --cpunodebind=0"
  elif [[ "$CONFIG" == "EDGES_ON_REMOTE" ]]; then
    # place edges array on node 1, rest on node 0
    COMMAND_COMMON="/usr/bin/time -v /usr/bin/numactl --membind=0 --cpunodebind=0"
  elif [[ "$CONFIG" == "TPP" ]]; then
    # only use node 0 CPUs and let TPP decide how memory is placed
    COMMAND_COMMON="/usr/bin/time -v /usr/bin/numactl --cpunodebind=0"
  elif [[ "$CONFIG" == "AUTONUMA" ]]; then
    COMMAND_COMMON="/usr/bin/time -v /usr/bin/numactl --cpunodebind=0"
  elif [[ "$CONFIG" == "LFU" ]]; then
    COMMAND_COMMON="/usr/bin/time -v /usr/bin/numactl --cpunodebind=0"
  else
    echo "Error! Undefined configuration $CONFIG"
    exit 1
  fi

  echo "Start" > $OUTFILE_PATH
  echo "=======================" >> $OUTFILE_PATH
  echo "NUMA hardware config " >> $OUTFILE_PATH
  NUMACTL_OUT=$(numactl -H)
  echo "$NUMACTL_OUT" >> $OUTFILE_PATH

  echo "=======================" >> $OUTFILE_PATH
  echo "Migration counters" >> $OUTFILE_PATH
  MIGRATION_STAT=$(grep -E "pgdemote|pgpromote|pgmigrate" /proc/vmstat)
  echo "$MIGRATION_STAT" >> $OUTFILE_PATH
  echo "=======================" >> $OUTFILE_PATH


  case $WORKLOAD in
    # both sine_d increased by x10000 to to speedup the benchmarking, as per 
    # https://github.com/facebook/rocksdb/wiki/RocksDB-Trace%2C-Replay%2C-Analyzer%2C-and-Workload-Generation#synthetic-workload-generation-based-on-models
    # keyrange_num is increased proportionally with the number of total keys to keep the distribution the same.
    "zippydb")
      echo "${COMMAND_COMMON} \
      -- ./db_bench --benchmarks="mixgraph,stats" --cache_size=200000000000 \
      --cache_numshardbits=6 -use_existing_db=1 \
      --db=${DB_DIR}/${DB_NAME} --wal_dir=${DB_DIR}/${DB_NAME}/WAL_LOG \
      -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true \
      -key_dist_a=0.002312 -key_dist_b=0.3467 \
      -keyrange_dist_a=14.18 -keyrange_dist_b=-2.917 -keyrange_dist_c=0.0164 -keyrange_dist_d=-0.08082 \
      -keyrange_num=30 -value_k=0.2615 -value_sigma=25.45 \
      -iter_k=2.517 -iter_sigma=14.236 \
      -mix_get_ratio=0.83 -mix_put_ratio=0.14 -mix_seek_ratio=0.03 \
      -sine_mix_rate_interval_milliseconds=5000 -sine_a=1000 -sine_b=0.000073 -sine_d=45000000 \
      --perf_level=2 -reads=42000000000 -num=2097152000 -key_size=48 --bloom_bits=10 --open_files=1048575 \
      --statistics --duration=${DURATION} -stats_interval_seconds=5 --threads=${NUM_THREADS}" >> ${OUTFILE_PATH}
      
      ${COMMAND_COMMON} \
      -- ./db_bench --benchmarks="mixgraph,stats" --cache_size=200000000000 \
      --cache_numshardbits=6 -use_existing_db=1 \
      --db=${DB_DIR}/${DB_NAME} --wal_dir=${DB_DIR}/${DB_NAME}/WAL_LOG \
      -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true \
      -key_dist_a=0.002312 -key_dist_b=0.3467 \
      -keyrange_dist_a=14.18 -keyrange_dist_b=-2.917 -keyrange_dist_c=0.0164 -keyrange_dist_d=-0.08082 \
      -keyrange_num=30 -value_k=0.2615 -value_sigma=25.45 \
      -iter_k=2.517 -iter_sigma=14.236 \
      -mix_get_ratio=0.83 -mix_put_ratio=0.14 -mix_seek_ratio=0.03 \
      -sine_mix_rate_interval_milliseconds=5000 -sine_a=1000 -sine_b=0.000073 -sine_d=45000000 \
      --perf_level=2 -reads=42000000000 -num=2097152000 -key_size=48 --bloom_bits=10 --open_files=1048575 \
      --statistics --duration=${DURATION} -stats_interval_seconds=5 --threads=${NUM_THREADS} &>> ${OUTFILE_PATH}
      ;;
    "socialgraph")
      echo "${COMMAND_COMMON} \
      -- ./db_bench --benchmarks="mixgraph,stats" --cache_size=200000000000 \
      --cache_numshardbits=6 -use_existing_db=1 \
      --db=${DB_DIR}/${DB_NAME} --wal_dir=${DB_DIR}/${DB_NAME}/WAL_LOG \
      -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true \
      -key_dist_a=0.001636 -key_dist_b=-0.7094 \
      -value_k=0.923 -value_sigma=226.409 -value_theta=0 \
      -iter_k=0.0819 -iter_sigma=1.747 \
      -mix_get_ratio=0.83 -mix_put_ratio=0.14 -mix_seek_ratio=0.03 \
      -sine_mix_rate_interval_milliseconds=5000 -sine_a=147.9 -sine_b=0.000083 -sine_c=-1.734 -sine_d=10642000  \
      --perf_level=2 -reads=42000000000 -num=2097152000 -key_size=48 --bloom_bits=10 --open_files=1048575 \
      --statistics --duration=${DURATION} -stats_interval_seconds=5 --threads=${NUM_THREADS}" >> ${OUTFILE_PATH}

      # the key_size and query ratio -mix_get_ratio etc. are the same as zippydb, since none is provided for social graph
      # socialgraph workload does not have keyrange_dist_* parameters.
      ${COMMAND_COMMON} \
      -- ./db_bench --benchmarks="mixgraph,stats" --cache_size=200000000000 \
      --cache_numshardbits=6 -use_existing_db=1 \
      --db=${DB_DIR}/${DB_NAME} --wal_dir=${DB_DIR}/${DB_NAME}/WAL_LOG \
      -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true \
      -key_dist_a=0.001636 -key_dist_b=-0.7094 \
      -value_k=0.923 -value_sigma=226.409 -value_theta=0 \
      -iter_k=0.0819 -iter_sigma=1.747 \
      -mix_get_ratio=0.83 -mix_put_ratio=0.14 -mix_seek_ratio=0.03 \
      -sine_mix_rate_interval_milliseconds=5000 -sine_a=147.9 -sine_b=0.000083 -sine_c=-1.734 -sine_d=10642000  \
      --perf_level=2 -reads=42000000000 -num=2097152000 -key_size=48 --bloom_bits=10 --open_files=1048575 \
      --statistics --duration=${DURATION} -stats_interval_seconds=5 --threads=${NUM_THREADS} &>> ${OUTFILE_PATH}
      ;;
    *)
      echo -n "ERROR: Unknown executable $WORKLOAD"
      exit 1
      ;;
  esac

  echo "=======================" >> $OUTFILE_PATH
  echo "Migration counters" >> $OUTFILE_PATH
  MIGRATION_STAT=$(grep -E "pgdemote|pgpromote|pgmigrate" /proc/vmstat)
  echo "$MIGRATION_STAT" >> $OUTFILE_PATH
  echo "=======================" >> $OUTFILE_PATH

}

##############
# Script start
##############

mkdir -p $RESULT_DIR

# AutoNUMA
echo "[INFO] Building rocksdb for LFU"
cp tools/db_bench.cc.orig tools/db_bench.cc
make static_lib db_bench -j
BUILD_RET=$?
echo "Build return: $BUILD_RET"

if [ $BUILD_RET -ne 0 ]; then
  echo "ERROR: Failed to build RocksDB"
  exit 1 
fi
for ((i=0;i<$NUM_ITERS;i++));
do
  # ZippyDB
  # if db already exist
  if [ -d "${DB_DIR}/zippydb_autonuma" ]; then 
    echo "db director ${DB_DIR}/zippydb_autonuma already exist. Please remove it"; 
    exit 1
  fi
  # Make a copy of the database
  cp -r ${SOURCE_DB} ${DB_DIR}/zippydb_autonuma
  enable_autonuma "MGLRU"
  clean_cache
  LOGFILE_NAME=$(gen_file_name "rocksdb" "zippydb" "${MEMCONFIG}_autonuma" "iter$i")
  run_app $LOGFILE_NAME "zippydb" "AUTONUMA" "zippydb_autonuma"

  ## Social graph
  ## if db already exist
  #if [ -d "${DB_DIR}/socialgraph_autonuma" ]; then 
  #  echo "db director ${DB_DIR}/socialgraph_autonuma already exist. Please remove it"; 
  #  exit 1
  #fi
  ## Make a copy of the database
  #cp -r ${SOURCE_DB} ${DB_DIR}/socialgraph_autonuma
  #enable_autonuma "MGLRU"
  #clean_cache
  #LOGFILE_NAME=$(gen_file_name "rocksdb" "socialgraph" "${MEMCONFIG}_autonuma" "iter$i")
  #run_app $LOGFILE_NAME "socialgraph" "AUTONUMA" "socialgraph_autonuma"
done

# TinyLFU
#echo "[INFO] Building rocksdb for LFU"
#cp tools/db_bench.cc.lfu tools/db_bench.cc
#make static_lib db_bench -j
#BUILD_RET=$?
#echo "Build return: $BUILD_RET"
#
#if [ $BUILD_RET -ne 0 ]; then
#  echo "ERROR: Failed to build RocksDB"
#  exit 1 
#fi
#for ((i=0;i<$NUM_ITERS;i++));
#do
#  # ZippyDB
#  # if db already exist
#  if [ -d "${DB_DIR}/zippydb_lfu" ]; then 
#    echo "db director ${DB_DIR}/zippydb_lfu already exist. Please remove it"; 
#    exit 1
#  fi
#  # Make a copy of the database
#  cp -r ${SOURCE_DB} ${DB_DIR}/zippydb_lfu
#  enable_lfu
#  clean_cache
#  LOGFILE_NAME=$(gen_file_name "rocksdb" "zippydb" "${MEMCONFIG}_lfu" "iter$i")
#  run_app $LOGFILE_NAME "zippydb" "LFU" "zippydb_lfu"
#
#
#  ## Social graph
#  ## if db already exist
#  #if [ -d "${DB_DIR}/socialgraph_lfu" ]; then 
#  #  echo "db director ${DB_DIR}/socialgraph_lfu already exist. Please remove it"; 
#  #  exit 1
#  #fi
#  ## Make a copy of the database
#  #cp -r ${SOURCE_DB} ${DB_DIR}/socialgraph_lfu
#  #enable_lfu
#  #clean_cache
#  #LOGFILE_NAME=$(gen_file_name "rocksdb" "socialgraph" "${MEMCONFIG}_lfu" "iter$i")
#  #run_app $LOGFILE_NAME "socialgraph" "LFU" "socialgraph_lfu"
#done

