GHDL = ghdl
GHDL_OPTS = --workdir=$(WORKDIR)
GHDL_RUNOPTS = --wave=$(WAVESDIR)/$(TBS_TOP).ghw

WORKDIR   = work
WAVESDIR  = waves
VENVDIR   = py/.venv
VENV_PYTHON = $(VENVDIR)/bin/python3
VENV_STAMP  = $(VENVDIR)/.installed

REG_INC_VAL ?= 85899345
REG_PHA_VAL ?= 0
REG_AMP_VAL ?= 4095
NUM_PERIODS ?= 4

RTL_PKGS = ./rtl/sine_lut_pkg.vhd ./rtl/sig_gen_pkg.vhd
RTL_SRC  = $(RTL_PKGS) $(filter-out $(RTL_PKGS),$(wildcard ./rtl/*.vhd))
TBS_SRC  = ./tbs/sig_gen_tb_pkg.vhd ./tbs/sig_gen_tb.vhd

RTL_TOP = sig_gen
TBS_TOP = sig_gen_tb

GHDL_RUNOPTS += -gREG_INC_VAL=$(REG_INC_VAL)
GHDL_RUNOPTS += -gREG_PHA_VAL=$(REG_PHA_VAL)
GHDL_RUNOPTS += -gREG_AMP_VAL=$(REG_AMP_VAL)
GHDL_RUNOPTS += -gNUM_PERIODS=$(NUM_PERIODS)
GHDL_RUNOPTS += -gDATA_FILE=$(TBS_TOP).txt

.PHONY: all run analyze clean distclean

all: run

$(WORKDIR) $(WAVESDIR):
	@mkdir -p $@

$(VENVDIR):
	python3 -m venv $(VENVDIR)

$(VENV_STAMP): $(VENVDIR) py/requirements.txt
	$(VENV_PYTHON) -m pip install -r py/requirements.txt
	@touch $@

$(WORKDIR)/.import: $(RTL_SRC) $(TBS_SRC) | $(WORKDIR)
	@$(GHDL) analyze $(GHDL_OPTS) $(RTL_SRC) $(TBS_SRC) | tee $@

$(WORKDIR)/.make: $(WORKDIR)/.import
	@$(GHDL) make $(GHDL_OPTS) $(TBS_TOP) | tee $@

run: $(WORKDIR)/.make | $(WAVESDIR)
	@$(GHDL) run  $(TBS_TOP) $(GHDL_RUNOPTS)

analyze: run $(VENV_STAMP)
	@$(VENV_PYTHON) py/analyze_sig_gen.py \
		--data $(TBS_TOP).txt \
		--clk-frequency 50e6

clean:
	@$(GHDL) clean $(GHDL_OPTS) 2>/dev/null || true
	@rm -rf $(WORKDIR) $(WAVESDIR) $(TBS_TOP).txt

distclean: clean
	@rm -rf $(VENVDIR)
