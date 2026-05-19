
#!/bin/bash
#run ../scripts/setup.sh to install test tools first

mkdir -p results
result_file="results/benchmark-results-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "${result_file}") 2>&1
echo "Writing benchmark output to ${result_file}"

# Verify OS version, kernel version, tool version, and hardware information, cache size, memory size, disk type, network type, etc. before running benchmarks.
echo "OS Version:"
cat /etc/os-release    
echo "Kernel Version:"
uname -r
echo "GCC Version:"
gcc --version
echo "CPU Information:"
lscpu
echo "Memory Information:"
lshw -short -C memory
echo "Disk Information:"
lsblk
echo "Network Information:"
lshw -short -C network
echo "Cache Information:"
getconf -a | grep "cache" | grep -v None
echo "OS disk info":
df -Th 

# cpu int64 and float benchmarks using stress-ng
cpu_count=$(nproc)
echo "Running stress-ng with ${cpu_count} CPU worker(s)"
stress-ng --cpu "${cpu_count}" --cpu-method int64 --timeout 60s --metrics
stress-ng --cpu "${cpu_count}" --cpu-method float --timeout 60s --metrics

lat_mem_rd_path=$(find . -name lat_mem_rd -type f | head -n 1)
if [ -z "${lat_mem_rd_path}" ]; then
     echo "lat_mem_rd was not found. Run ../scripts/setup.sh first, then retry."
     exit 1
fi
echo "Using lat_mem_rd: ${lat_mem_rd_path}"
taskset -c 2 "${lat_mem_rd_path}" -P 1 -N 10 -W 1 -t 128M 128 >> lat_mem_rd-results.txt

./stream >> stream-results.txt

 ./core-to-core-latency-plus-linux-amd64 5000 300 >> core-to-core-latency-plus-results.txt

# Disk performance tests are split into separate scripts under tests/.
# Run tests/fiotest.sh to execute all local NVMe random read/write latency, IOPS, and throughput tests.



           