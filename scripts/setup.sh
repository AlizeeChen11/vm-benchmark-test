#!/bin/bash

sudo apt update
sudo apt install lshw build-essential fio iperf stress-ng git sockperf -y

git clone https://github.com/intel/lmbench.git
cd lmbench
make
cd ..

echo "lat_mem_rd path(s):"
find . -name lat_mem_rd

wget http://www.cs.virginia.edu/stream/FTP/Code/stream.c
gcc -O2 -fopenmp -DSTREAM_ARRAY_SIZE=80000000 -DNTIMES=100 stream.c -o stream

wget https://github.com/KCORES/core-to-core-latency-plus/releases/download/0.1.17/core-to-core-latency-plus-linux-amd64
chmod +x core-to-core-latency-plus-linux-amd64


