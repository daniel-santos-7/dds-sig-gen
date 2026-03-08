SHELL = bash

GHDL = ghdl
GHDL_OPTS = --workdir=$(WORKDIR)
GHDL_RUNOPTS = --wave=$(WAVESDIR)/$(TBS_TOP).ghw

WORKDIR  = work
WAVESDIR = waves

RTL_SRC = $(wildcard ./rtl/*.vhd)
TBS_SRC = $(wildcard ./tbs/*.vhd)

RTL_TOP = sig_gen
TBS_TOP = sig_gen_tb

.PHONY: all simulation clean

all: run

simulation: $(WORKDIR)/.run

clean: | $(WORKDIR)
	@$(GHDL) clean $(GHDL_OPTS)
	@rm -rf $(WORKDIR) $(WAVESDIR)

$(WORKDIR) $(WAVESDIR):
	@mkdir $@

$(WORKDIR)/.import: $(RTL_SRC) $(TBS_SRC) | $(WORKDIR)
	@set -o pipefail; $(GHDL) import $(GHDL_OPTS) $(RTL_SRC) $(TBS_SRC) | tee $@

$(WORKDIR)/.make: $(WORKDIR)/.import
	@set -o pipefail; $(GHDL) make $(GHDL_OPTS) $(TBS_TOP) | tee $@

$(WORKDIR)/.run: $(WORKDIR)/.make | $(WAVESDIR)
	@set -o pipefail; $(GHDL) run  $(TBS_TOP) $(GHDL_RUNOPTS) | tee $@
