# sim/Makefile — behavioral simulation (VCS or Icarus)
SHELL := /bin/bash
TOP ?= mesh_tb
FILELIST := ../tb/filelist.f
OUTDIR := ../results/simv
VCDDIR := ../results/vcd

.PHONY: all vcs iverilog run clean

all: vcs

vcs:
	@echo "[VCS] Compiling $(TOP)"
	@mkdir -p $(OUTDIR) $(VCDDIR)
	@if command -v vcs >/dev/null 2>&1; then \
	  vcs -full64 -sverilog -timescale=1ns/1ps -f $(FILELIST) +define+TOP=$(TOP) -o $(OUTDIR)/simv; \
	  echo "[VCS] Built $(OUTDIR)/simv"; \
	else \
	  echo "[VCS] Not found; try 'make iverilog'"; \
	fi

iverilog:
	@echo "[Icarus] Compiling $(TOP)"
	@mkdir -p $(OUTDIR) $(VCDDIR)
	iverilog -g2012 -f $(FILELIST) -s $(TOP) -o $(OUTDIR)/a.out

run:
	@if [ -x $(OUTDIR)/simv ]; then \
	  $(OUTDIR)/simv; \
	elif [ -f $(OUTDIR)/a.out ]; then \
	  vvp $(OUTDIR)/a.out; \
	else \
	  echo "No simulator binary found. Run 'make vcs' or 'make iverilog' first."; \
	fi

clean:
	rm -rf $(OUTDIR)/* $(VCDDIR)/* csrc simv.daidir ucli.key verdiLog *.vcd
