//  Copyright (c) 2013-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under both the GPLv2 (found in the
//  COPYING file in the root directory) and Apache 2.0 License
//  (found in the LICENSE.Apache file in the root directory).
//
// Copyright (c) 2011 The LevelDB Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file. See the AUTHORS file for names of contributors.


#ifndef GFLAGS
#include <cstdio>
int main() {
  fprintf(stderr, "Please install gflags to run rocksdb tools\n");
  return 1;
}
#else
#include "rocksdb/db_bench_tool.h"
#include <iostream>
#include <pthread.h>
#include "perf_lfu.cpp"

int main(int argc, char** argv) {
  // start perf monitornig thread
  pthread_t perf_thread;
  int r = pthread_create(&perf_thread, NULL, perf_func, NULL);
  if (r != 0) {
    std::cout << "pthread create failed." << std::endl;
    exit(1);
  }
  r = pthread_setname_np(perf_thread, "lfu_perf");
  if (r != 0) {
    std::cout << "perf thread set name failed." << std::endl;
  }
  std::cout << "perf thread created." << std::endl;

  return ROCKSDB_NAMESPACE::db_bench_tool(argc, argv);
}
#endif  // GFLAGS
