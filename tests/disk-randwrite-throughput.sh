#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/disk-fio-common.sh"

block_size="${FIO_BS:-1M}"
io_depth="${FIO_IODEPTH:-4096}"
num_jobs="${FIO_NUMJOBS:-160}"
runtime_seconds="${FIO_RUNTIME:-300}"

run_disk_fio_aggregate_test "randwrite-throughput" "randwrite" "${block_size}" "${io_depth}" "${num_jobs}" "${runtime_seconds}"
