GHDL = ghdl
GHDL_OPTS = --std=08 --workdir=$(WORKDIR)

GHDL_RUNOPTS = --wave=$(OUTDIR)/sig_gen_tb.ghw --ieee-asserts=disable
GHDL_RUNOPTS += -gNUM_PERIODS=$(NUM_PERIODS)
GHDL_RUNOPTS += -gSAMPLES_FILE=$(OUTDIR)/samples.txt
GHDL_RUNOPTS += -gCASE_FILE=$(OUTDIR)/test_case.txt
GHDL_RUNOPTS += -gREG_FILE=$(OUTDIR)/reg_values.txt
GHDL_RUNOPTS += -gFREQ_HZ=$(FREQ_HZ)
GHDL_RUNOPTS += -gPHASE_DEG=$(PHASE_DEG)
GHDL_RUNOPTS += -gAMP_VAL=$(AMP_VAL)

WORKDIR = work
OUTDIR  = output/test_$(FREQ_HZ)hz_$(PHASE_DEG)deg_$(AMP_VAL)
VENVDIR = py/.venv

RTL_SRC = $(wildcard ./rtl/*.vhd)
TBS_SRC = $(wildcard ./tbs/*.vhd)

RTL_TOP = sig_gen
TBS_TOP = sig_gen_tb

FREQ_HZ     ?= 100000
PHASE_DEG   ?= 0
AMP_VAL     ?= 2047
NUM_PERIODS ?= 4

.PHONY: run analyze plot clean distclean

$(WORKDIR) $(OUTDIR):
	@mkdir -p $@

$(VENVDIR): py/requirements.txt
	@python3 -m venv $(VENVDIR)
	$(VENVDIR)/bin/python3 -m pip install -r $<

.import: $(RTL_SRC) $(TBS_SRC) | $(WORKDIR)
	@$(GHDL) import $(GHDL_OPTS) $(RTL_SRC) $(TBS_SRC) | tee $@

.make: .import
	@$(GHDL) make $(GHDL_OPTS) $(TBS_TOP) | tee $@

run: .make | $(OUTDIR)
	@$(GHDL) run $(TBS_TOP) $(GHDL_RUNOPTS)

analyze: $(VENVDIR) | $(OUTDIR)
	$(VENVDIR)/bin/python3 py/analyze_sig_gen.py --data $(OUTDIR)/samples.txt --clk 50e6 > $(OUTDIR)/analysis.txt

plot: $(VENVDIR) | $(OUTDIR)
	$(VENVDIR)/bin/python3 py/plot_sig_gen.py --data $(OUTDIR)/samples.txt --output $(OUTDIR) --clk 50e6

clean:
	@$(GHDL) clean $(GHDL_OPTS)
	@rm -rf $(WORKDIR) output .import .make

distclean: clean
	@rm -rf $(VENVDIR)
