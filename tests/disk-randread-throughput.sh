#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/disk-fio-common.sh"

run_disk_fio_test "randread-throughput" "randread" "1M" "128" "4" "300"
