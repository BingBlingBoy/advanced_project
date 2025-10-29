#ifndef __MEM_RUBY_STRUCTURES_L2CACHEMEMORY_HH__
#define __MEM_RUBY_STRUCTURES_L2CACHEMEMORY_HH__


#include "mem/ruby/structures/CacheMemory.hh"
#include "params/RubyCache.hh"

namespace gem5 {

namespace ruby {

class L2CacheMemory : public CacheMemory
{
public:
    using Params = RubyCacheParams;
    L2CacheMemory(const Params &p);
};

}
}

#endif // !__MEM_RUBY_STRUCTURES_L1CACHEMEMORY_HH__
