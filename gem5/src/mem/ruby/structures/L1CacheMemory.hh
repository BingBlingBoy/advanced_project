#ifndef __MEM_RUBY_STRUCTURES_L1CACHEMEMORY_HH__
#define __MEM_RUBY_STRUCTURES_L1CACHEMEMORY_HH__


#include "mem/ruby/structures/CacheMemory.hh"
#include "params/RubyCache.hh"

namespace gem5 {

namespace ruby {

class L1CacheMemory : public CacheMemory
{
public:
    using Params = RubyCacheParams;
    L1CacheMemory(const Params &p);
};

}
}

#endif // !__MEM_RUBY_STRUCTURES_L1CACHEMEMORY_HH__
