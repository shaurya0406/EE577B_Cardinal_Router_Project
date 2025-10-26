# Top-level Makefile — orchestrates sim and synth
.PHONY: all sim synth lint clean reports tree

all: sim synth

sim:
	$(MAKE) -C sim

synth:
	$(MAKE) -C synth/dc

lint:
	@echo "[lint] (placeholder) — add your linter here"

reports:
	@echo "Reports live in synth/dc/reports and results/synthesis"

tree:
	@find . -maxdepth 3 -type d | sort

clean:
	$(MAKE) -C sim clean || true
	$(MAKE) -C synth/dc clean || true
	rm -rf results/logs/* results/vcd/* results/simv/* results/netlist/* results/synthesis/*

# Root Makefile – convenience targets
.PHONY: unit run clean

TB ?= tb_vc_phase
GL ?= 0

unit:
	$(MAKE) -C tb/unit_tb TB=$(TB) GL=$(GL) run

clean-tb:
	$(MAKE) -C tb/unit_tb clean
