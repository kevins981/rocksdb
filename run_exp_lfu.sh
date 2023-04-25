#!/bin/bash

# import common functions
if [ "$BIGMEMBENCH_COMMON_PATH" = "" ] ; then
  echo "ERROR: bigmembench_common script not found. BIGMEMBENCH_COMMON_PATH is $BIGMEMBENCH_COMMON_PATH"
  echo "Have you set BIGMEMBENCH_COMMON_PATH correctly? Are you using sudo -E instead of just sudo?"
  exit 1
fi
source ${BIGMEMBENCH_COMMON_PATH}/run_exp_common.sh

DB_DIR="/ssd1/songxin8/thesis/rocksdb/tmp/"
RESULT_DIR="exp/exp_lfu_20230425/" 
MEMCONFIG="16threads16GB"
DURATION=5000
NUM_THREADS=16
NUM_ITERS=1

#declare -a WORKLOAD_LIST=("zippydb" "socialgraph")

run_app () { 
  OUTFILE_NAME=$1
  WORKLOAD=$2
  CONFIG=$3
  DB_NAME=$4

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
    "zippydb")
      ${COMMAND_COMMON} \
      -- ./db_bench --benchmarks="mixgraph,stats" --cache_size=200000000000 \
      --cache_numshardbits=6 -use_existing_db=1 \
      --db=${DB_DIR}/${DB_NAME} --wal_dir=${DB_DIR}/${DB_NAME}/WAL_LOG \
      -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true \
      -keyrange_dist_a=14.18 -keyrange_dist_b=-2.917 -keyrange_dist_c=0.0164 -keyrange_dist_d=-0.08082 \
      -keyrange_num=30 -value_k=0.2615 -value_sigma=25.45 -iter_k=2.517 -iter_sigma=14.236 \
       -mix_get_ratio=0.85 -mix_put_ratio=0.14 -mix_seek_ratio=0.01 \
      -sine_mix_rate_interval_milliseconds=5000 -sine_a=1000 -sine_b=0.000073 -sine_d=45000000 \
      --perf_level=2 -reads=4200000 -num=2097152000 -key_size=48 --bloom_bits=10 --open_files=1048575 \
      --statistics --duration=${DURATION} -stats_interval_seconds=5 --threads=${NUM_THREADS} &>> ${OUTFILE_PATH}
      ;;
    "socialgraph")
      ${COMMAND_COMMON} \
      -- ./db_bench --benchmarks="mixgraph,stats" --cache_size=200000000000 \
      --cache_numshardbits=6 -use_existing_db=1 \
      --db=${DB_DIR}/${DB_NAME} --wal_dir=${DB_DIR}/${DB_NAME}/WAL_LOG \
      -use_direct_io_for_flush_and_compaction=true -use_direct_reads=true \
      -keyrange_dist_a=0.001636 -keyrange_dist_b=-0.7094 -keyrange_dist_c=0.000000003217 \
      -keyrange_num=30 -value_k=0.923 -value_sigma=226.409 -value_theta=0 -iter_k=0.0819 -iter_sigma=1.747 \
      -mix_get_ratio=0.85 -mix_put_ratio=0.14 -mix_seek_ratio=0.01 \
      -sine_mix_rate_interval_milliseconds=5000 -sine_a=147.9 -sine_b=0.000083 -sine_c=-1.734 -sine_d=10642000  \
      --perf_level=2 -reads=4200000 -num=2097152000 -key_size=48 --bloom_bits=10 --open_files=1048575 \
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

# TinyLFU
echo "[INFO] Building rocksdb for LFU"
cp tools/db_bench.cc.lfu tools/db_bench.cc
make static_lib db_bench -j
for ((i=0;i<$NUM_ITERS;i++));
do
  enable_lfu
  # ZippyDB
  clean_cache
  LOGFILE_NAME=$(gen_file_name "rocksdb" "zippydb" "${MEMCONFIG}_lfu" "iter$i")
  run_app $LOGFILE_NAME "zippydb" "LFU" "zippydb_lfu"
  # Social graph
  clean_cache
  LOGFILE_NAME=$(gen_file_name "rocksdb" "socialgraph" "${MEMCONFIG}_lfu" "iter$i")
  run_app $LOGFILE_NAME "socialgraph" "LFU" "socialgraph_lfu"
done


# AutoNUMA
echo "[INFO] Building rocksdb for LFU"
cp tools/db_bench.cc.orig tools/db_bench.cc
make static_lib db_bench -j
for ((i=0;i<$NUM_ITERS;i++));
do
  enable_autonuma "MGLRU"
  # ZippyDB
  clean_cache
  LOGFILE_NAME=$(gen_file_name "rocksdb" "zippydb" "${MEMCONFIG}_autonuma" "iter$i")
  run_app $LOGFILE_NAME "zippydb" "AUTONUMA" "zippydb_autonuma"
  # Social graph
  clean_cache
  LOGFILE_NAME=$(gen_file_name "rocksdb" "socialgraph" "${MEMCONFIG}_autonuma" "iter$i")
  run_app $LOGFILE_NAME "socialgraph" "AUTONUMA" "socialgraph_autonuma"
done
