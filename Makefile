GHDL = ghdl
GHDL_OPTS = --workdir=$(WORKDIR)
GHDL_RUNOPTS = --wave=$(WAVESDIR)/$(TBS_TOP).ghw

WORKDIR  = work
WAVESDIR = waves

RTL_SRC = $(wildcard ./rtl/*.vhd)
TBS_SRC = $(wildcard ./tbs/*.vhd)

RTL_TOP = sig_gen
TBS_TOP = sig_gen_tb

ifdef CLK_FREQUENCY
GHDL_RUNOPTS += -gCLK_FREQUENCY=$(CLK_FREQUENCY)
endif

ifdef OUT_FREQUENCY
GHDL_RUNOPTS += -gOUT_FREQUENCY=$(OUT_FREQUENCY)
endif

.PHONY: all run clean

all: run

$(WORKDIR) $(WAVESDIR):
	@mkdir -p $@

$(WORKDIR)/.import: $(RTL_SRC) $(TBS_SRC) | $(WORKDIR)
	@$(GHDL) import $(GHDL_OPTS) $(RTL_SRC) $(TBS_SRC) | tee $@

$(WORKDIR)/.make: $(WORKDIR)/.import
	@$(GHDL) make $(GHDL_OPTS) $(TBS_TOP) | tee $@

run: $(WORKDIR)/.make | $(WAVESDIR)
	@$(GHDL) run  $(TBS_TOP) $(GHDL_RUNOPTS)

clean: | $(WORKDIR)
	@$(GHDL) clean $(GHDL_OPTS)
	@rm -rf $(WORKDIR) $(WAVESDIR)
