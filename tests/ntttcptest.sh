#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

mode="${1:-help}"
host_arg="${2:-}"
connections="${3:-16}"
duration_seconds="${4:-300}"

usage() {
	cat <<EOF
Usage:
  $0 receiver [local_ip] [connections] [duration_seconds]
  $0 sender <receiver_ip> [connections] [duration_seconds]

Examples:
  $0 receiver 10.0.0.4 16 300
  $0 sender 10.0.0.4 16 300

Notes:
  receiver mode binds to the local VM IP. The IP must exist on this VM.
  sender mode targets the receiver VM IP.
  ntttcp uses ports starting around 5001, so stop iperf first if it is listening on 5001+.
EOF
}

require_command() {
	local command_name="$1"

	if ! command -v "${command_name}" >/dev/null 2>&1; then
		echo "Required command not found: ${command_name}"
		echo "Run scripts/setup.sh first, then retry."
		exit 1
	fi
}

detect_primary_ipv4() {
	ip -o -4 addr show scope global | awk '{ split($4, addr, "/"); print addr[1]; exit }'
}

tune_network_buffers() {
	sudo sysctl -w net.core.rmem_max=67108864
	sudo sysctl -w net.core.wmem_max=67108864
	sudo sysctl -w net.ipv4.tcp_rmem='4096 87380 33554432'
	sudo sysctl -w net.ipv4.tcp_wmem='4096 87380 33554432'
}

setup_result_log() {
	local test_name="$1"
	local result_dir="${repo_root}/results/${test_name}-$(date +%Y%m%d-%H%M%S)"
	mkdir -p "${result_dir}"
	local result_file="${result_dir}/${test_name}.log"
	exec > >(tee -a "${result_file}") 2>&1
	echo "Writing ${test_name} output to ${result_file}"
}

validate_local_ip() {
	local local_ip="$1"

	if ! ip -o -4 addr show | awk '{ split($4, addr, "/"); print addr[1] }' | grep -Fxq "${local_ip}"; then
		echo "Local IP ${local_ip} was not found on this VM."
		echo "Available IPv4 addresses:"
		ip -o -4 addr show | awk '{ split($4, addr, "/"); print "  " addr[1] " on " $2 }'
		exit 1
	fi
}

check_ntttcp_port_conflicts() {
	require_command ss
	local last_port=$((5001 + connections * 2))
	local occupied_ports

	occupied_ports="$(sudo ss -lntp | awk -v start=5001 -v end="${last_port}" '
		$4 ~ /:[0-9]+$/ {
			split($4, parts, ":")
			port = parts[length(parts)] + 0
			if (port >= start && port <= end) {
				print
			}
		}
	')"

	if [ -n "${occupied_ports}" ]; then
		echo "Ports in the ntttcp range 5001-${last_port} are already in use:"
		echo "${occupied_ports}"
		echo
		echo "Stop the conflicting process, for example: sudo pkill iperf"
		exit 1
	fi
}

print_environment() {
	echo "ntttcp version:"
	ntttcp 2>&1 | head -n 1 || true
	echo "Kernel: $(uname -r)"
	echo "CPU cores: $(nproc)"
	echo "Network interfaces:"
	ip -o -4 addr show scope global
}

run_receiver() {
	local local_ip="${host_arg:-$(detect_primary_ipv4)}"

	if [ -z "${local_ip}" ]; then
		echo "Could not detect a local IPv4 address. Pass the receiver IP explicitly."
		usage
		exit 1
	fi

	validate_local_ip "${local_ip}"
	check_ntttcp_port_conflicts
	tune_network_buffers
	setup_result_log "ntttcptest-receiver"
	print_environment

	echo
	echo "Starting ntttcp receiver"
	echo "Local bind IP: ${local_ip}"
	echo "Connections: ${connections}"
	echo "Duration: ${duration_seconds}s"
	echo
	ntttcp -r -m "${connections},*,${local_ip}" -t "${duration_seconds}"
}

run_sender() {
	local receiver_ip="${host_arg}"

	if [ -z "${receiver_ip}" ]; then
		echo "receiver_ip is required in sender mode."
		usage
		exit 1
	fi

	tune_network_buffers
	setup_result_log "ntttcptest-sender"
	print_environment

	echo
	echo "Starting ntttcp sender"
	echo "Receiver IP: ${receiver_ip}"
	echo "Connections: ${connections}"
	echo "Duration: ${duration_seconds}s"
	echo
	ntttcp -s -m "${connections},*,${receiver_ip}" -t "${duration_seconds}"
}

case "${mode}" in
	receiver|recv|r)
		require_command ntttcp
		require_command awk
		require_command grep
		require_command ip
		require_command sudo
		require_command tee
		run_receiver
		;;
	sender|send|s)
		require_command ntttcp
		require_command ip
		require_command sudo
		require_command tee
		run_sender
		;;
	-h|--help|help)
		usage
		;;
	*)
		echo "Unknown mode: ${mode}"
		usage
		exit 1
		;;
esac