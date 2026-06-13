GHDL = ghdl
GHDL_OPTS = --std=08 --workdir=$(WORKDIR)

WORKDIR = work
OUTDIR  = output
VENVDIR = py/.venv

RTL_SRC = $(wildcard ./rtl/*.vhd)
TBS_SRC = $(wildcard ./tbs/*.vhd)

RTL_TOP = sig_gen
TBS_TOP = sig_gen_tb

CLK_FREQ_HZ ?= 100e6
CLK_PERIODS ?= 4
FREQ_HZ     ?= 100000
PHASE_DEG   ?= 0
AMP_VAL     ?= 65535
PULSE_LEN   ?= 200
DRAG_COEFF  ?= 0.5
OUT_RES_BITS ?= 12
LUT_ADDR_BITS ?= 10
ENV_LUT_ADDR_BITS ?= 10
ENV_OUT_RES_BITS ?= 16
INITIAL_PHASE ?= 0
FINAL_PHASE ?= 90
DRAG_COEFF_INT = $(shell python3 -c "print(int(round($(DRAG_COEFF) * 32768)))")

TESTDIR = $(OUTDIR)/test_$(FREQ_HZ)hz_$(PHASE_DEG)deg_$(AMP_VAL)

SAMPLES_FILE    = $(TESTDIR)/samples.txt
TEST_CASE_FILE  = $(TESTDIR)/test_case.txt
REG_VALUES_FILE = $(TESTDIR)/reg_values.txt

LUT_PKGS = rtl/sine_lut_pkg.vhd rtl/envelope_lut_pkg.vhd

GHDL_RUNOPTS = --wave=$(OUTDIR)/sig_gen_tb.ghw --ieee-asserts=disable
GHDL_RUNOPTS += -gNUM_PERIODS=$(CLK_PERIODS)
GHDL_RUNOPTS += -gFREQ_HZ=$(FREQ_HZ)
GHDL_RUNOPTS += -gPHASE_DEG=$(PHASE_DEG)
GHDL_RUNOPTS += -gAMP_VAL=$(AMP_VAL)
GHDL_RUNOPTS += -gPULSE_LEN=$(PULSE_LEN)
GHDL_RUNOPTS += -gDRAG_COEFF=$(DRAG_COEFF_INT)
GHDL_RUNOPTS += -gSAMPLES_FILE=$(SAMPLES_FILE)
GHDL_RUNOPTS += -gCASE_FILE=$(TEST_CASE_FILE)
GHDL_RUNOPTS += -gREG_FILE=$(REG_VALUES_FILE)

.PHONY: run fit params spectrum clean distclean luts

$(WORKDIR) $(OUTDIR) $(TESTDIR):
	@mkdir -p $@

$(VENVDIR): py/requirements.txt
	@python3 -m venv $(VENVDIR)
	$(VENVDIR)/bin/python3 -m pip install -r $<

rtl/sine_lut_pkg.vhd: py/gen_lut_pkg.py py/sig_gen.py
	python3 py/sig_gen.py gen-sine-lut $(LUT_ADDR_BITS) $(OUT_RES_BITS) $(INITIAL_PHASE) $(FINAL_PHASE) > $@

rtl/envelope_lut_pkg.vhd: py/gen_lut_pkg.py py/sig_gen.py
	python3 py/sig_gen.py gen-env-lut $(ENV_LUT_ADDR_BITS) $(ENV_OUT_RES_BITS) > $@

luts: $(LUT_PKGS)

.import: $(RTL_SRC) $(TBS_SRC) $(LUT_PKGS) | $(WORKDIR)
	@$(GHDL) import $(GHDL_OPTS) $^ | tee $@

.make: .import
	@$(GHDL) make $(GHDL_OPTS) $(TBS_TOP) | tee $@

run: .make | $(OUTDIR) $(TESTDIR)
	@$(GHDL) run $(TBS_TOP) $(GHDL_RUNOPTS)

fit: $(VENVDIR) $(SAMPLES_FILE)
	@$(VENVDIR)/bin/python3 py/sig_gen.py fit --data $(SAMPLES_FILE) --clk $(CLK_FREQ_HZ) --freq $(FREQ_HZ) --pulse-len $(PULSE_LEN) --output $(TESTDIR)/fit.txt --plot $(TESTDIR)

params: $(VENVDIR) $(SAMPLES_FILE)
	@$(VENVDIR)/bin/python3 py/sig_gen.py params --data $(SAMPLES_FILE) --clk $(CLK_FREQ_HZ) --freq $(FREQ_HZ) --pulse-len $(PULSE_LEN) --output $(TESTDIR)/params.txt --plot $(TESTDIR)

spectrum: $(VENVDIR) $(SAMPLES_FILE)
	@$(VENVDIR)/bin/python3 py/sig_gen.py spectrum --data $(SAMPLES_FILE) --clk $(CLK_FREQ_HZ) --output $(TESTDIR)/spectrum.txt --plot $(TESTDIR)

clean:
	@$(GHDL) clean $(GHDL_OPTS)
	@rm -rf $(WORKDIR) $(OUTDIR) .import .make

distclean: clean
	@rm -rf $(VENVDIR)
