#include "mem/ruby/structures/L1CacheMemory.hh"

namespace gem5 {
namespace ruby {

L1CacheMemory::L1CacheMemory(const Params &p)
    : CacheMemory(p, "L1CacheMemory")
{
}

}
}
