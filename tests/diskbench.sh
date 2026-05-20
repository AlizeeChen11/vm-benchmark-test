#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

category="${1:-help}"
direction="${2:-both}"

usage() {
	cat <<EOF
Usage:
  $0 latency [read|write|both]
  $0 iops [read|write|both]
  $0 throughput [read|write|both]
  $0 all [read|write|both]

Examples:
  $0 latency read
  $0 iops both
  $0 throughput write
  $0 all both

Warning:
  These fio tests are destructive. They run against partition-free local NVMe disks
  discovered by lsblk, such as /dev/nvme1n1 through /dev/nvme9n1. Do not run this
  on disks that contain data you need.
EOF
}

run_directional_test() {
	local test_category="$1"
	local read_script="$2"
	local write_script="$3"

	case "${direction}" in
		read)
			bash "${script_dir}/${read_script}"
			;;
		write)
			bash "${script_dir}/${write_script}"
			;;
		both)
			bash "${script_dir}/${read_script}"
			bash "${script_dir}/${write_script}"
			;;
		*)
			echo "Unknown direction for ${test_category}: ${direction}"
			usage
			exit 1
			;;
	esac
}

case "${category}" in
	latency)
		run_directional_test "latency" "disk-randread-latency.sh" "disk-randwrite-latency.sh"
		;;
	iops)
		run_directional_test "iops" "disk-randread-iops.sh" "disk-randwrite-iops.sh"
		;;
	throughput)
		run_directional_test "throughput" "disk-randread-throughput.sh" "disk-randwrite-throughput.sh"
		;;
	all)
		bash "$0" latency "${direction}"
		bash "$0" iops "${direction}"
		bash "$0" throughput "${direction}"
		;;
	-h|--help|help)
		usage
		;;
	*)
		echo "Unknown category: ${category}"
		usage
		exit 1
		;;
esac