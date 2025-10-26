# =========================
# Unit-level VCS Makefile
# =========================

# Usage:
#   RTL: make TB=tb_vc_phase run
#   GLS: make TB=tb_vc_phase GL=1 run
#   Clean: make clean

# Select testbench top (module name in your tb_*.sv)
TB ?= tb_vc_phase

# GL=1 to run gate-level; default RTL
GL ?= 0

# Paths
PROJ_ROOT := $(abspath ../..)
RTL_DIR   := $(PROJ_ROOT)/rtl
NET_DIR   := $(PROJ_ROOT)/netlist
TB_DIR    := $(PROJ_ROOT)/tb/unit_tb
FILESET   := $(TB_DIR)/fileset

# Filelists
RTL_COMMON_F := $(FILESET)/rtl_common.f
GLS_COMMON_F := $(FILESET)/gls_common.f
TB_SINGLE_F  := $(FILESET)/tb_single.f

# Command files
VCS_CMD_RTL := $(TB_DIR)/vcs-cmd.rtl.txt
VCS_CMD_GLS := $(TB_DIR)/vcs-cmd.gls.txt

# Build artifacts
SIMV := $(TB_DIR)/simv
CSRC := $(TB_DIR)/csrc
LOG  := $(TB_DIR)/vcs.log

# Tools
VCS ?= vcs

# Default target
.PHONY: run
run: prep filelists build sim

# Prepare dirs
.PHONY: prep
prep:
	@mkdir -p $(FILESET)

# Filelists:
#  - rtl_common.f: all RTL units needed by most unit TBs
#  - gls_common.f: the synthesized netlist (and libs, if any)
#  - tb_single.f : just the chosen TB file
.PHONY: filelists
filelists:
	@echo "+incdir+$(RTL_DIR)"                                >  $(RTL_COMMON_F)
	@echo "$(RTL_DIR)/vc_phase.v"                            >> $(RTL_COMMON_F)
	@echo "$(RTL_DIR)/inbuf_cell.v"                          >> $(RTL_COMMON_F)
	@echo "$(RTL_DIR)/outbuf_cell.v"                         >> $(RTL_COMMON_F)
	@echo "$(RTL_DIR)/hdr_fields.v"                          >> $(RTL_COMMON_F)
	@echo "$(RTL_DIR)/route_xy.v"                            >> $(RTL_COMMON_F)

	@echo "$(NET_DIR)/cardinal_unit_netlist.v"               >  $(GLS_COMMON_F)
	# If you need stdcell models, add them here:
	# @echo "/path/to/stdcells.v"                            >> $(GLS_COMMON_F)

	@echo "$(TB_DIR)/$(TB).sv"                               >  $(TB_SINGLE_F)

# Build (RTL or GLS)
.PHONY: build
build: $(SIMV)

$(SIMV): $(VCS_CMD_RTL) $(VCS_CMD_GLS) filelists
ifeq ($(GL),1)
	$(VCS) -full64 -file $(VCS_CMD_GLS) -top $(TB)
else
	$(VCS) -full64 -file $(VCS_CMD_RTL) -top $(TB)
endif

# Run simv
.PHONY: sim
sim:
	@./simv | tee run.log

# Optional SDF back-annotation example:
.PHONY: build_sdf
build_sdf: $(SIMV)
	$(VCS) -full64 -file $(VCS_CMD_GLS) -top $(TB) \
	  -sdf max:$(TB):$(NET_DIR)/cardinal_unit.sdf

.PHONY: clean
clean:
	@rm -rf $(SIMV) $(CSRC) $(LOG) ucli.key simv.daidir *.vpd *.vcd *.fsdb *.log
	@rm -f $(TB_SINGLE_F) $(RTL_COMMON_F) $(GLS_COMMON_F)
