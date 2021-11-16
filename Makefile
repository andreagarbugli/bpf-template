# Variables
SHELL=/bin/bash
V=1
SRC_DIR=./src
OUT_DIR=./.output

# Set the quiet mode on off
ifeq ($(V),1)
	Q = 
else
	Q = @
endif

# All targets
.PHONY: all
all: $(OUT_DIR)/bpfstart

# Clean target
.PHONY: clean
clean:
	$(info "cleaning")
	rm -rf $(OUT_DIR)/

# Settings the output dir name as a target is like checking its existence
# If the directory is not present, then we create it.
$(OUT_DIR):
	@echo "[info] creating the output dir"
	$(Q)mkdir -p $@

$(OUT_DIR)/bpfstart.bpf.o: $(SRC_DIR)/bpfstart.bpf.c | $(OUT_DIR)
	@echo "[info] compiling BPF program"
	$(Q)clang -g -O2 -target bpf -D__TARGET_ARCH_x86 -Iinclude -c $(SRC_DIR)/bpfstart.bpf.c -o $@
	$(Q)llvm-strip -g $(OUT_DIR)/bpfstart.bpf.o 

$(OUT_DIR)/bpfstart.skel.h: $(OUT_DIR)/bpfstart.bpf.o | $(OUT_DIR)
	@echo "[info] generating the skeleton"
	$(Q)./tools/bpftool gen skeleton $< > $@

$(OUT_DIR)/bpfstart.o: $(SRC_DIR)/bpfstart.c
	$(Q)gcc -I$(OUT_DIR) -Iinclude -Ilibbpf/include/uapi -c $(SRC_DIR)/bpfstart.c -o $(OUT_DIR)/bpfstart.o

$(OUT_DIR)/bpfstart: $(OUT_DIR)/bpfstart.o | $(OUT_DIR)
	$(Q)gcc -g -Wall $(OUT_DIR)/bpfstart.o -lbpf -lelf -lz -o $@

# delete failed targets
.DELETE_ON_ERROR:

# keep intermediate (.skel.h, .bpf.o, etc) targets
.SECONDARY: