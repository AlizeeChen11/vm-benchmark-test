#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

mode="${1:-client}"
server_host="${2:-10.0.0.4}"
parallel_streams="${3:-128}"
duration_seconds="${4:-60}"
udp_bitrate="${5:-1G}"
port="${IPERF_PORT:-5001}"
sockperf_port="${SOCKPERF_PORT:-12345}"

usage() {
	cat <<EOF
Usage:
  $0 server
  $0 client [server_host] [parallel_streams] [duration_seconds] [udp_bitrate]
	$0 latency-server [local_ip]
	$0 latency-client [server_host] [duration_seconds] [message_size_bytes]

Examples:
  $0 server
  $0 client 10.0.0.4 128 60 1G
	$0 latency-server 10.0.0.4
	$0 latency-client 10.0.0.4 100 16

Environment:
	IPERF_PORT    iperf port, default: 5001
	SOCKPERF_PORT sockperf port, default: 12345
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

detect_primary_ipv4() {
	ip -o -4 addr show scope global | awk '{ split($4, addr, "/"); print addr[1]; exit }'
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

run_server() {
	require_command iperf
	tune_network_buffers

	echo "Starting iperf server on port ${port}"
	echo "Press Ctrl+C to stop the server."
	iperf -s -p "${port}"
}

run_client() {
	require_command iperf
	require_command tee
	tune_network_buffers
	setup_result_log "networktest"

	echo "iperf version:"
	iperf --version | head -n 1
	echo "Server: ${server_host}:${port}"
	echo "Parallel TCP streams: ${parallel_streams}"
	echo "Duration: ${duration_seconds}s"
	echo "UDP bitrate for jitter/loss test: ${udp_bitrate}"

	echo
	echo "== TCP upload bandwidth =="
	iperf -c "${server_host}" -p "${port}" -P "${parallel_streams}" -t "${duration_seconds}" -i 10 -f g

	echo
	echo "== TCP server-to-client bandwidth (tradeoff mode) =="
	echo "iperf v2 -r runs client-to-server first, then server-to-client."
	iperf -c "${server_host}" -p "${port}" -P "${parallel_streams}" -t "${duration_seconds}" -i 10 -f g -r

	echo
	echo "== UDP jitter/loss latency proxy =="
	echo "iperf reports UDP jitter and loss, not true RTT latency. Use ping or a dedicated latency tool for RTT."
	iperf -c "${server_host}" -p "${port}" -u -b "${udp_bitrate}" -t "${duration_seconds}" -i 10 -f g
}

run_latency_server() {
	local local_ip="${2:-$(detect_primary_ipv4)}"

	require_command awk
	require_command grep
	require_command ip
	require_command sockperf
	validate_local_ip "${local_ip}"

	echo "Starting sockperf latency server on ${local_ip}:${sockperf_port}"
	echo "Press Ctrl+C to stop the server."
	sockperf sr --tcp -i "${local_ip}" -p "${sockperf_port}"
}

run_latency_client() {
	local latency_server_host="${2:-10.0.0.4}"
	local latency_duration_seconds="${3:-100}"
	local message_size_bytes="${4:-16}"

	require_command sockperf
	require_command tee
	setup_result_log "network-latencytest"

	echo "sockperf version:"
	sockperf --version 2>&1 | head -n 1 || true
	echo "Server: ${latency_server_host}:${sockperf_port}"
	echo "Duration: ${latency_duration_seconds}s"
	echo "Message size: ${message_size_bytes} bytes"

	echo
	echo "== TCP full RTT latency =="
	sockperf ping-pong -i "${latency_server_host}" --tcp -m "${message_size_bytes}" -t "${latency_duration_seconds}" -p "${sockperf_port}" --full-rtt
}

case "${mode}" in
	server)
		run_server
		;;
	client)
		run_client
		;;
	latency-server|latency_server)
		run_latency_server "$@"
		;;
	latency-client|latency_client)
		run_latency_client "$@"
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