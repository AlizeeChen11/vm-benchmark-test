# Azure VM Benchmark Test

Scripts for running repeatable Azure VM CPU, memory, network, and local NVMe disk benchmarks.

## Setup

Run setup on each VM before running benchmarks:

```bash
bash scripts/setup.sh
```

The setup script installs common tools including `fio`, `iperf`, `sockperf`, `stress-ng`, and builds `ntttcp` from source.

## Network Bandwidth With iperf

Run the server on the receiver VM:

```bash
bash tests/networktest.sh server
```

Run the client on the sender VM. Replace `10.0.0.4` with the receiver VM private IP:

```bash
bash tests/networktest.sh client 10.0.0.4 128 60 1G
```

Arguments are:

```text
client <server_host> <parallel_streams> <duration_seconds> <udp_bitrate>
```

The iperf test runs TCP upload, TCP server-to-client tradeoff mode, and a UDP jitter/loss check. Results are written under `results/networktest-*`.

## Network Throughput With ntttcp

Use `ntttcp` for high-throughput VM-to-VM testing. Stop any old `iperf` or `ntttcp` processes first so their ports do not conflict:

```bash
sudo pkill iperf || true
sudo pkill ntttcp || true
```

On the receiver VM:

```bash
bash tests/ntttcptest.sh receiver 10.0.0.4 128 300
```

On the sender VM:

```bash
bash tests/ntttcptest.sh sender 10.0.0.4 128 300
```

Arguments are:

```text
receiver <local_ip> <connections> <duration_seconds>
sender <receiver_ip> <connections> <duration_seconds>
```

For high bandwidth VMs, test multiple connection counts and compare throughput and retransmissions:

```bash
bash tests/ntttcptest.sh sender 10.0.0.4 32 300
bash tests/ntttcptest.sh sender 10.0.0.4 64 300
bash tests/ntttcptest.sh sender 10.0.0.4 128 300
```

Results are written under `results/ntttcptest-receiver-*` and `results/ntttcptest-sender-*`.

## Network Latency With sockperf

Run the latency server on the receiver VM:

```bash
bash tests/networktest.sh latency-server 10.0.0.4
```

Run the latency client on the sender VM:

```bash
bash tests/networktest.sh latency-client 10.0.0.4 100 16
```

Arguments are:

```text
latency-client <server_host> <duration_seconds> <message_size_bytes>
```

This runs a TCP full RTT test using `sockperf ping-pong --full-rtt`. Results are written under `results/network-latencytest-*`.

## Local NVMe Disk Benchmarks With fio

Disk tests are grouped into latency, IOPS, and throughput. The scripts discover partition-free local NVMe disks automatically, for example `/dev/nvme1n1` through `/dev/nvme9n1`, and skip the partitioned OS disk such as `/dev/nvme0n1`.

Warning: disk tests are destructive. They run `blkdiscard` and direct fio workloads against discovered partition-free NVMe disks. Do not run them on disks that contain data you need.

Run each category separately:

```bash
bash tests/diskbench.sh latency both
bash tests/diskbench.sh iops both
bash tests/diskbench.sh throughput both
```

Run read or write only:

```bash
bash tests/diskbench.sh latency read
bash tests/diskbench.sh latency write
bash tests/diskbench.sh iops read
bash tests/diskbench.sh iops write
bash tests/diskbench.sh throughput read
bash tests/diskbench.sh throughput write
```

Run all disk categories:

```bash
bash tests/diskbench.sh all both
```

Disk test profiles:

| Category | Workload | Block size | I/O depth | Jobs | Runtime |
| --- | --- | --- | --- | --- | --- |
| Latency | randread/randwrite | 4k | 1 | 1 | 120s |
| IOPS | randread/randwrite | 4k | 128 | 4 | 300s |
| Throughput | randread/randwrite | 1M | 128 | 4 | 300s |

Results are written under per-test directories in `results/`, such as `results/randread-latency-*`, `results/randwrite-iops-*`, and `results/randread-throughput-*`.

## Existing CPU and Memory Benchmark

The original combined benchmark script still exists:

```bash
bash tests/benchmark-test.sh
```

It collects system information and runs CPU and memory tests with `stress-ng`, `lmbench`, STREAM, and core-to-core latency tooling.
