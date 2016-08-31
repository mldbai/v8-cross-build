ARCHS?=x64 arm64 arm

# Ubuntu names for arches
ARCH2_x64:=amd64
ARCH2_x32:=x86
ARCH2_arm64:=aarch64
ARCH2_arm:=armhf

# GCC host triple names for raches
ARCH3_x64:=x86_64-linux-gnu
ARCH3_x32:=x86-linux-gnu
ARCH3_arm64:=aarch64-linux-gnu
ARCH3_arm:=arm-linux-gnueabihf

# v8 ssroot names for arches
ARCH4_x64:=amd64
ARCH4_x32:=i386
ARCH4_arm64:=arm64
ARCH4_arm:=arm

PWD:=$(shell pwd)

default: all

.PHONY: setup

depot_tools/fetch:
	git submodule sync && git submodule update --init

v8/third_party/icu: | depot_tools/gclient
	cd v8 && PATH=$(PWD)/depot_tools:$(PATH) ../depot_tools/gclient sync

v8/third_party/icu/ispatched: third_party-icu-use-system-icu.diff
	cd v8/third_party/icu && patch -p1 < ../../../$<
	touch $@

setup: 	| v8/third_party/icu v8/third_party/icu/ispatched


all: setup

PORT_DEV_PACKAGES:=libicu52 libicu-dev

define build_v8_on_arch

osdeps/$(1)/tmp/installed-%:
	./install-port-package.sh $$* $(ARCH2_$(1)) osdeps/$(1)
	touch $$@

PORT_DEPS_$(1):=$$(foreach package,$$(PORT_DEV_PACKAGES),osdeps/$(1)/tmp/installed-$$(package))

port_deps: $$(PORT_DEPS_$(1))

osdeps/$(1)/tmp/sysroot:
	cd v8 && build/linux/sysroot_scripts/install-sysroot.py --arch=$$(ARCH4_$(1))
	mkdir -p $(dir $$@) && touch $$@

# enable_profiling=true is necessary for anything that links with tcmalloc,
# which will attempt to trace stacks back through v8 when a C++ callback
# is called from JS.  Otherwise the stack traces will cause a segfault.
v8/out/$(1)/libv8.so: $$(PORT_DEPS_$(1)) | osdeps/$(1)/tmp/sysroot
	cd v8 && PATH=$(PWD)/depot_tools:$(PATH) ../depot_tools/gn gen out/$(1) --args='is_debug=false target_cpu="$(1)" v8_target_cpu="$(1)" is_component_build=true cc_wrapper="ccache" icu_use_system=true icu_include_dir="$(PWD)/osdeps/$(1)/usr/include/$$(ARCH3_$(1))" icu_lib_dir="$(PWD)/osdeps/$(1)/usr/lib/$$(ARCH3_$(1))" v8_enable_gdbjit=true v8_enable_disassembler=true enable_profiling=true $$(if $$(findstring x64,$(1)),linux_use_bundled_binutils=false use_sysroot=false)'
	PATH=$(PWD)/depot_tools:$(PATH) nice ninja -C v8/out/$(1)

v8/out/$(1)/snapshot_blob.bin v8/out/$(1)/natives_blob.bin: | v8/out/$(1)/libv8.so

out/$(1)/libv8.so:	v8/out/$(1)/libv8.so
	mkdir -p $$(dir $$@)
	cp $$< $$@~ && mv $$@~ $$@

out/$(1)/snapshot_blob.bin:	v8/out/$(1)/snapshot_blob.bin
	mkdir -p $$(dir $$@)
	cp $$< $$@~ && mv $$@~ $$@

out/$(1)/natives_blob.bin:	v8/out/$(1)/natives_blob.bin
	mkdir -p $$(dir $$@)
	cp $$< $$@~ && mv $$@~ $$@


all: out/$(1)/libv8.so out/$(1)/snapshot_blob.bin out/$(1)/natives_blob.bin

endef

$(foreach arch,$(ARCHS),$(eval $(call build_v8_on_arch,$(arch))))

HEADERS_SOURCE:=$(wildcard v8/include/*.h v8/include/libplatform/*.h)
HEADERS:=$(HEADERS_SOURCE:v8/include/%=%)

out/include/%:	v8/include/%
	mkdir -p $(dir $@)
	cp $< $@~ && mv $@~ $@

all:	$(foreach header,$(HEADERS),out/include/$(header))
