GHDL = ghdl
GHDL_OPTS = --workdir=$(WORKDIR)
GHDL_RUNOPTS = --wave=$(WAVESDIR)/$(TBS_TOP).ghw

STEPSDIR = steps
WORKDIR  = work
WAVESDIR = waves

RTL_SRC      = $(wildcard ./rtl/*.vhd)
TBS_PKG_SRC  = ./tbs/sig_gen_tb_pkg.vhd
TBS_TB_SRC   = ./tbs/sig_gen_tb.vhd
TBS_SRC      = $(TBS_PKG_SRC) $(TBS_TB_SRC)

RTL_TOP = sig_gen
TBS_TOP = sig_gen_tb

.PHONY: all run clean

all: run

run: $(STEPSDIR)/run

clean: | $(WORKDIR)
	@$(GHDL) clean $(GHDL_OPTS)
	@rm -rf $(STEPSDIR) $(WORKDIR) $(WAVESDIR)

$(STEPSDIR) $(WORKDIR) $(WAVESDIR):
	@mkdir $@

$(STEPSDIR)/import: $(RTL_SRC) $(TBS_SRC) | $(STEPSDIR) $(WORKDIR) 
	@$(GHDL) import $(GHDL_OPTS) $(RTL_SRC) $(TBS_SRC) | tee $@

$(STEPSDIR)/make: $(STEPSDIR)/import
	@$(GHDL) make $(GHDL_OPTS) $(TBS_TOP) | tee $@

$(STEPSDIR)/run: $(STEPSDIR)/make | $(WAVESDIR)
	@$(GHDL) run  $(TBS_TOP) $(GHDL_RUNOPTS) | tee $@
