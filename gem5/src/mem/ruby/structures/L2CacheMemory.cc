#include "mem/ruby/structures/L2CacheMemory.hh"

namespace gem5 {
namespace ruby {

L2CacheMemory::L2CacheMemory(const Params &p)
    : CacheMemory(p, "L2CacheMemory")
{
}

}
}
