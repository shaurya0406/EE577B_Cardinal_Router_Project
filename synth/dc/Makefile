# synth/dc/Makefile — Synopsys DC compile flow
DC      ?= dc_shell
TCL_TOP ?= compile.tcl
LOGDIR  := ../../results/logs
RPTDIR  := reports
RES_SYN := ../../results/synthesis
NETLIST := ../../results/netlist

.PHONY: all run reports clean

all: run

run:
	@mkdir -p $(LOGDIR) $(RPTDIR) $(RES_SYN) $(NETLIST)
	$(DC) -64 -f $(TCL_TOP) | tee $(LOGDIR)/dc_shell.log

reports:
	@echo "See $(RPTDIR) for *.rpt"

clean:
	rm -rf $(RPTDIR)/* $(RES_SYN)/* $(NETLIST)/* $(LOGDIR)/dc_shell.log
