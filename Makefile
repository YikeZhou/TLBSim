OBJS = sim.o walker.o config.o stats.o util.o tlb.o validator.o offline.o

CXX=g++
CXX_FLAGS=-Iinclude/ -std=gnu++17 -O3 -flto -Wall -Werror -fpic $(shell pkg-config --cflags jsoncpp)

LD=g++
LD_FLAGS=-g -O3 -flto -shared -fpic

QEMU_SYSTEM_RISCV64 ?= qemu-system-riscv64
FEDORA_ELF ?= Fedora-Developer-Rawhide-*-fw_payload-uboot-qemu-virt-smode.elf
FEDORA_IMG_RAW ?= Fedora-Developer-Rawhide-*.raw

all: libtlbsim.so

.PHONY: all clean show-symbols fedora

clean:
	rm $(patsubst %,bin/%,$(OBJS) $(OBJS:.o=.d))

libtlbsim.so: $(patsubst %,bin/%,$(OBJS))
	$(LD) $(LD_FLAGS) $^  $(shell pkg-config --libs jsoncpp) -o $@

-include $(patsubst %,bin/%,$(OBJS:.o=.d))

bin/%.o: src/%.cc
	@mkdir -p $(dir $@)
	$(CXX) -c -MMD -MP $(CXX_FLAGS) $< -o $@

# Useful for check that we don't mistakenly export symbols that are not intended for exporting,
# which could conflict with symbols in application
show-symbols:
	@nm -D --defined-only libtlbsim.so | c++filt | grep -v tlbsim::

replay: src/replay.cc libtlbsim.so
	$(CXX) $(CXX_FLAGS) -Iinclude/ $< -L. -ltlbsim -o $@

fedora: libtlbsim.so
	$(QEMU_SYSTEM_RISCV64) \
	-nographic \
	-machine virt \
	-smp 8 \
	-m 2G \
	-kernel $(FEDORA_ELF) \
	-object rng-random,filename=/dev/urandom,id=rng0 \
	-device virtio-rng-device,rng=rng0 \
	-device virtio-blk-device,drive=hd0 \
	-drive file=$(FEDORA_IMG_RAW),format=raw,id=hd0 \
	-device virtio-net-device,netdev=usernet \
	-netdev user,id=usernet,hostfwd=tcp::10000-:22
