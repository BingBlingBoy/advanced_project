#ifndef __MEM_RUBY_STRUCTURES_FOURSPLITLATENCY_HH__
#define __MEM_RUBY_STRUCTURES_FOURSPLITLATENCY_HH__

#include "mem/ruby/common/TypeDefines.hh"
#include "mem/ruby/system/RubySystem.hh"

namespace gem5 {

namespace ruby {

class FourSplitLatency {
private:
    double m_percentage_of_low_retention_sets;

    struct AccessLatency {
        Cycles data_read;
        Cycles tag_read;
        Cycles data_write;
        Cycles tag_write;
    };

    AccessLatency m_low_retention;
    AccessLatency m_mediumlow_retention;
    AccessLatency m_mediumhigh_retention;
    AccessLatency m_high_retention;
};

} // namespace ruby
} // namespace gem5

#endif // !__MEM_RUBY_STRUCTURES_FOURSPLITLATENCY_HH__


