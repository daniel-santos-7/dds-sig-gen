MAKEFLAGS += --no-print-directory

GHDL = ghdl
GHDL_OPTS = --std=08 --workdir=$(WORKDIR)
GHDL_RUNOPTS = --wave=$(WAVESDIR)/$(TBS_TOP)_$(TEST_INDEX).ghw --ieee-asserts=disable

WORKDIR  = work
WAVESDIR = waves
OUTDIR   = output
VENVDIR   = py/.venv
VENV_PYTHON = $(VENVDIR)/bin/python3
VENV_STAMP  = $(VENVDIR)/.installed

TEST_INDEX  ?= 0
NUM_PERIODS ?= 4

RTL_PKGS = ./rtl/sine_lut_pkg.vhd ./rtl/sig_gen_pkg.vhd
RTL_SRC  = $(RTL_PKGS) $(filter-out $(RTL_PKGS),$(wildcard ./rtl/*.vhd))
TBS_SRC  = ./tbs/sig_gen_tb_pkg.vhd ./tbs/sig_gen_test_pkg.vhd ./tbs/sig_gen_tb.vhd

RTL_TOP = sig_gen
TBS_TOP = sig_gen_tb

GHDL_RUNOPTS += -gNUM_PERIODS=$(NUM_PERIODS)
GHDL_RUNOPTS += -gDATA_FILE=$(OUTDIR)/test_$(TEST_INDEX)/samples.txt
GHDL_RUNOPTS += -gCASE_FILE=$(OUTDIR)/test_$(TEST_INDEX)/test_case.txt
GHDL_RUNOPTS += -gTEST_INDEX=$(TEST_INDEX)
GHDL_RUNOPTS += -gTEST_VECTORS=test_vectors.csv

.PHONY: all run analyze tests clean distclean

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
	@mkdir -p $(OUTDIR)/test_$(TEST_INDEX)
	@$(GHDL) run  $(TBS_TOP) $(GHDL_RUNOPTS)

analyze: run $(VENV_STAMP)
	@mkdir -p $(OUTDIR)/test_$(TEST_INDEX)
	@$(VENV_PYTHON) py/analyze_sig_gen.py --data $(OUTDIR)/test_$(TEST_INDEX)/samples.txt --clk-frequency 50e6 > $(OUTDIR)/test_$(TEST_INDEX)/analysis.txt

clean:
	@$(GHDL) clean $(GHDL_OPTS) 2>/dev/null || true
	@rm -rf $(WORKDIR) $(WAVESDIR) $(OUTDIR)

distclean: clean
	@rm -rf $(VENVDIR)

tests:
	@pass=0; fail=0; \
	for i in $$(seq 0 127); do \
	    printf "[%3d/128] TEST_INDEX=$$i ... " $$((i+1)); \
	    if $(MAKE) --no-print-directory run TEST_INDEX=$$i > /tmp/tests_run.log 2>&1; then \
	        echo "OK"; pass=$$((pass+1)); \
	    else \
	        echo "FAIL"; sed 's/^/  /' /tmp/tests_run.log; fail=$$((fail+1)); \
	    fi; \
	done; \
	echo ""; \
	echo "=== Summary: $$pass passed, $$fail failed, $$((pass+fail)) total ==="; \
	exit $$fail