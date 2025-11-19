#include <iostream>
#include <cstddef>
#include <gem5/m5ops.h>

constexpr size_t ARRAY_BYTES = 512 * 1024; 
constexpr size_t ELEMENT_COUNT = ARRAY_BYTES / sizeof(int);
constexpr int STRIDE = 64 / sizeof(int);

static int data_array[ELEMENT_COUNT];

void access_memory() {
    volatile long long sum = 0;
    // Loop multiple times to amplify the latency difference
    for (int iter = 0; iter < 100; ++iter) {
        for (size_t i = 0; i < ELEMENT_COUNT; i += STRIDE) {
            sum += data_array[i];
        }
    }
    std::cout << "Volatile sum: " << sum << std::endl;
}

int main() {
    std::cout << "=== L2 Latency Verification Workload ===" << std::endl;
    std::cout << "Array size: " << ARRAY_BYTES / 1024 << " KiB" << std::endl;
    
    // Initialize
    for (size_t i = 0; i < ELEMENT_COUNT; ++i)
        data_array[i] = i;

    std::cout << "1. Warming up cache (fetching from DRAM)..." << std::endl;
    access_memory(); // First pass: Loads data into L2

    std::cout << "2. Resetting stats..." << std::endl;
    m5_reset_stats(0, 0);

    std::cout << "3. Running measurement (Should be all L2 Hits)..." << std::endl;
    access_memory(); // Second pass: Should hit in L2

    m5_dump_stats(0, 0);
    std::cout << "Measurement complete." << std::endl;
    m5_exit(0);

    return 0;
}
