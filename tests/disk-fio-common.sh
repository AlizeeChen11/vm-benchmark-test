#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

require_command() {
     local command_name="$1"

     if ! command -v "${command_name}" >/dev/null 2>&1; then
          echo "Required command not found: ${command_name}"
          exit 1
     fi
}

check_disk_test_prerequisites() {
     require_command awk
     require_command fio
     require_command grep
     require_command lsblk
     require_command sort
     require_command sudo
     require_command tee
}

setup_disk_result_dir() {
     local test_name="$1"
     disk_result_dir="${repo_root}/results/${test_name}-$(date +%Y%m%d-%H%M%S)"
     mkdir -p "${disk_result_dir}"
     result_file="${disk_result_dir}/${test_name}.log"
     exec > >(tee -a "${result_file}") 2>&1
     echo "Writing ${test_name} output to ${result_file}"
}

discover_partition_free_nvme_disks() {
     mapfile -t fio_devices < <(
          lsblk -dn -o NAME,TYPE | awk '$1 ~ /^nvme[0-9]+n[0-9]+$/ && $2 == "disk" { print "/dev/" $1 }' | while read -r dev; do
               if ! lsblk -nr "$dev" -o TYPE | grep -q '^part$'; then
                    echo "$dev"
               fi
          done | sort -V
     )

     if [ "${#fio_devices[@]}" -eq 0 ]; then
          echo "No partition-free local NVMe disks found for fio."
          exit 1
     fi

     printf '%s\n' "${fio_devices[@]}" > "${disk_result_dir}/fio-devices.txt"
     echo "fio devices:"
     cat "${disk_result_dir}/fio-devices.txt"
}

discard_fio_devices() {
     for dev in "${fio_devices[@]}"; do
          echo "Discarding $dev"
          sudo blkdiscard "$dev"
     done
}

write_fio_job_file() {
     local job_file="$1"
     local test_name="$2"
     local rw_mode="$3"
     local block_size="$4"
     local io_depth="$5"
     local num_jobs="$6"
     local runtime_seconds="$7"

     cat > "${job_file}" <<EOF
[global]
ioengine=libaio
direct=1
thread=1
group_reporting=1
time_based=1
runtime=${runtime_seconds}
ramp_time=5
refill_buffers=1
norandommap=1
randrepeat=0
percentile_list=1:5:10:20:30:40:50:60:70:80:90:95:99:99.5:99.9:99.95:99.99
rw=${rw_mode}
bs=${block_size}
iodepth=${io_depth}
numjobs=${num_jobs}

EOF

     local disk_index=1
     for dev in "${fio_devices[@]}"; do
          cat >> "${job_file}" <<EOF
[${test_name}-disk${disk_index}]
filename=${dev}

EOF
          disk_index=$((disk_index + 1))
     done
}

run_disk_fio_test() {
     local test_name="$1"
     local rw_mode="$2"
     local block_size="$3"
     local io_depth="$4"
     local num_jobs="$5"
     local runtime_seconds="$6"

     setup_disk_result_dir "${test_name}"
     check_disk_test_prerequisites
     discover_partition_free_nvme_disks
     sudo sysctl -w fs.aio-max-nr=2097152
     ulimit -n 65535

     local job_file="${disk_result_dir}/${test_name}.fio"
     local output_file="${disk_result_dir}/${test_name}-results.txt"

     write_fio_job_file "${job_file}" "${test_name}" "${rw_mode}" "${block_size}" "${io_depth}" "${num_jobs}" "${runtime_seconds}"
     discard_fio_devices
     echo "Running ${test_name}: rw=${rw_mode}, bs=${block_size}, iodepth=${io_depth}, numjobs=${num_jobs}, runtime=${runtime_seconds}s"
     echo "Job file: ${job_file}"
     echo "Result file: ${output_file}"
     sudo fio "${job_file}" --eta=never --output="${output_file}"
}
