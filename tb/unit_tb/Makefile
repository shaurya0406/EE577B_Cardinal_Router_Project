# =========================
# Unit-level Makefile (VCS + Icarus)
# =========================
#
# Usage:
#   RTL (VCS):  make TB=vc_phase_tb run
#   GLS (VCS):  make TB=vc_phase_tb GL=1 run
#   RTL (IVL):  make TB=vc_phase_tb SIM=IVL run
#   Clean:      make clean
#
# Notes:
#   - TB is the **module name** and the TB filename base (vc_phase_tb.{v,sv}).
#   - SIM can be VCS (default) or IVL.
#   - GL=1 only applies to VCS.

TB ?= vc_phase_tb
GL ?= 0
SIM ?= VCS

PROJ_ROOT := $(abspath ../..)
RTL_DIR   := $(PROJ_ROOT)/rtl
ROUTER_DIR:= $(RTL_DIR)/router
NET_DIR   := $(PROJ_ROOT)/netlist
TB_DIR    := $(PROJ_ROOT)/tb/unit_tb
FILESET   := $(TB_DIR)/fileset

# Detect TB filename extension automatically (.v or .sv)
TB_SVFILE := $(TB_DIR)/$(TB).sv
TB_VFILE  := $(TB_DIR)/$(TB).v
TB_FILE   := $(if $(wildcard $(TB_VFILE)),$(TB_VFILE),$(TB_SVFILE))

RTL_COMMON_F := $(FILESET)/rtl_common.f
GLS_COMMON_F := $(FILESET)/gls_common.f
TB_SINGLE_F  := $(FILESET)/tb_single.f

VCS_CMD_RTL := $(TB_DIR)/vcs-cmd.rtl.txt
VCS_CMD_GLS := $(TB_DIR)/vcs-cmd.gls.txt

SIMV    := $(TB_DIR)/simv
CSRC    := $(TB_DIR)/csrc
LOG     := $(TB_DIR)/vcs.log
IVL_OUT := $(TB_DIR)/a.out

VCS ?= vcs
IVL ?= iverilog
VVP ?= vvp

.PHONY: run
run: check_tb prep filelists build sim

.PHONY: check_tb
check_tb:
	@if [ ! -f "$(TB_FILE)" ]; then \
	  echo "ERROR: $(TB_FILE) not found. Provide TB=<name> where tb/unit_tb/<name>.v or .sv exists."; \
	  exit 1; \
	fi

.PHONY: prep
prep:
	@mkdir -p $(FILESET)

# Filelists contain ONLY file paths (IVL-friendly).
$(RTL_COMMON_F):
	# Core router RTL (add more files as they appear)
	@echo "$(ROUTER_DIR)/vc_phase.v"   >  $(RTL_COMMON_F)
	# If you have more RTL files under rtl/ or rtl/router/, append them here:
	# @find $(RTL_DIR) -maxdepth 1 -name '*.v' -print         >> $(RTL_COMMON_F)
	# @find $(ROUTER_DIR) -maxdepth 1 -name '*.v' -print      >> $(RTL_COMMON_F)

$(GLS_COMMON_F):
	@echo "$(NET_DIR)/cardinal_unit_netlist.v" > $(GLS_COMMON_F)
	# Add stdcell models here if needed:
	# @echo "/path/to/stdcells.v"              >> $(GLS_COMMON_F)

$(TB_SINGLE_F):
	@echo "$(TB_FILE)" > $(TB_SINGLE_F)

.PHONY: filelists
filelists: $(RTL_COMMON_F) $(GLS_COMMON_F) $(TB_SINGLE_F)

.PHONY: build
build:
ifeq ($(SIM),VCS)
	$(MAKE) build_vcs
else ifeq ($(SIM),IVL)
	$(MAKE) build_ivl
else
	$(error Unknown SIM='$(SIM)'. Use SIM=VCS or SIM=IVL)
endif

.PHONY: build_vcs
build_vcs: $(SIMV)

$(SIMV): $(VCS_CMD_RTL) $(VCS_CMD_GLS) $(RTL_COMMON_F) $(TB_SINGLE_F)
ifeq ($(GL),1)
	$(VCS) -full64 -file $(VCS_CMD_GLS) -top $(TB)
else
	$(VCS) -full64 -file $(VCS_CMD_RTL) -top $(TB)
endif

.PHONY: build_ivl
build_ivl: $(RTL_COMMON_F) $(TB_SINGLE_F)
	# Mirrors your working command with router include path
	$(IVL) -g2012 -Wall -o $(IVL_OUT) \
	  -I $(RTL_DIR) -I $(ROUTER_DIR) \
	  @$(RTL_COMMON_F) @$(TB_SINGLE_F)

.PHONY: sim
sim:
ifeq ($(SIM),VCS)
	@./simv | tee run.log
else ifeq ($(SIM),IVL)
	@$(VVP) $(IVL_OUT) | tee run.log
endif

.PHONY: build_sdf
build_sdf: $(SIMV)
	$(VCS) -full64 -file $(VCS_CMD_GLS) -top $(TB) \
	  -sdf max:$(TB):$(NET_DIR)/cardinal_unit.sdf

.PHONY: clean
clean:
	@rm -rf $(SIMV) $(CSRC) $(LOG) ucli.key simv.daidir *.vpd *.vcd *.fsdb *.log run.log $(IVL_OUT)
	@rm -f $(TB_SINGLE_F) $(RTL_COMMON_F) $(GLS_COMMON_F)
