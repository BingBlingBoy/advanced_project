import m5
import os
from m5.objects import (
        System,
        SrcClockDomain,
        VoltageDomain,
        AddrRange,
        X86TimingSimpleCPU,
        SystemXBar,
        MemCtrl,
        DDR3_1600_8x8,
        SEWorkload,
        Process,
        L2XBar,
        Root
        )
from caches import (
        L1ICache,
        L1DCache,
        L2Cache,
        )
m5.util.addToPath("../../")
from common import SimpleOpts


thispath = os.path.dirname(os.path.realpath(__file__))
default_binary = os.path.join(
    thispath,
    "cache_workload",
)

SimpleOpts.add_option("binary", nargs="?", default=default_binary)

args = SimpleOpts.parse_args()

system = System()

system.clk_domain = SrcClockDomain()
system.clk_domain.clock = "2GHz"
system.clk_domain.voltage_domain = VoltageDomain()
system.cache_line_size = "64"

system.mem_mode = "timing"
system.mem_ranges = [AddrRange("8GiB")]

system.cpu = X86TimingSimpleCPU()

system.cpu.icache = L1ICache(args)
system.cpu.dcache = L1DCache(args)

system.cpu.icache.connectCPU(system.cpu)
system.cpu.dcache.connectCPU(system.cpu)

system.l2bus = L2XBar()

system.cpu.icache.connectBus(system.l2bus)
system.cpu.dcache.connectBus(system.l2bus)

system.l2cache = L2Cache(args)
system.l2cache.connectCPUSideBus(system.l2bus)

system.membus = SystemXBar()

system.l2cache.connectMemSideBus(system.membus)

system.cpu.createInterruptController()
system.cpu.interrupts[0].pio = system.membus.mem_side_ports
system.cpu.interrupts[0].int_requestor = system.membus.cpu_side_ports
system.cpu.interrupts[0].int_responder = system.membus.mem_side_ports

system.system_port = system.membus.cpu_side_ports

system.mem_ctrl = MemCtrl()
system.mem_ctrl.dram = DDR3_1600_8x8()
system.mem_ctrl.dram.range = system.mem_ranges[0]
system.mem_ctrl.port = system.membus.mem_side_ports

system.workload = SEWorkload.init_compatible(args.binary)

process = Process()
process.cmd = [args.binary]
system.cpu.workload = process
system.cpu.createThreads()

root = Root(full_system=False, system=system)
m5.instantiate()

print("Beginning simulation!")
exit_event = m5.simulate()
print(f"Exiting @ tick {m5.curTick()} because {exit_event.getCause()}")
