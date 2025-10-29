#include <iostream>
#include <cstddef>
#include <gem5/m5ops.h>

constexpr size_t ARRAY_BYTES = 64 * 1024 * 1024;
constexpr size_t ELEMENT_COUNT = ARRAY_BYTES / sizeof(int);
constexpr int STRIDE = 64 / sizeof(int);

static int data_array[ELEMENT_COUNT];

void sequential_access() {
    volatile long long sum = 0;
    for (size_t i = 0; i < ELEMENT_COUNT; ++i)
        sum += data_array[i];
    std::cout << "[Sequential] Volatile sum: " << sum << std::endl;
}

void strided_access() {
    volatile long long sum = 0;
    for (size_t i = 0; i < ELEMENT_COUNT; i += STRIDE)
        sum += data_array[i];
    std::cout << "[Strided] Volatile sum: " << sum << std::endl;
}

int main() {
    std::cout << "=== Complex Cache Workload ===" << std::endl;
    std::cout << "Array size: " << ARRAY_BYTES / (1024 * 1024) << " MiB" << std::endl;
    std::cout << "Element count: " << ELEMENT_COUNT << std::endl;
    std::cout << "Stride: " << STRIDE * sizeof(int) << " bytes" << std::endl;
    std::cout << "================================" << std::endl;

    for (size_t i = 0; i < ELEMENT_COUNT; ++i)
        data_array[i] = i;

    std::cout << "Starting measurement..." << std::endl;

    m5_reset_stats(0, 0);

    sequential_access();
    strided_access();

    m5_dump_stats(0, 0);
    std::cout << "Measurement complete. Stats dumped to m5out/stats.txt" << std::endl;

    m5_exit(0);

    return 0;
}
