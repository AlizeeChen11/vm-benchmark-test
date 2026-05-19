#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "${script_dir}/disk-randread-latency.sh"
bash "${script_dir}/disk-randwrite-latency.sh"
bash "${script_dir}/disk-randread-iops.sh"
bash "${script_dir}/disk-randwrite-iops.sh"
bash "${script_dir}/disk-randread-throughput.sh"
bash "${script_dir}/disk-randwrite-throughput.sh"
