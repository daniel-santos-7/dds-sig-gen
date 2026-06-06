GHDL = ghdl
GHDL_OPTS = --std=08 --workdir=$(WORKDIR)

GHDL_RUNOPTS =
GHDL_RUNOPTS += --wave=$(OUTDIR)/test_$(TEST_INDEX)/$(TBS_TOP)_$(TEST_INDEX).ghw --ieee-asserts=disable
GHDL_RUNOPTS += -gNUM_PERIODS=$(NUM_PERIODS)
GHDL_RUNOPTS += -gDATA_FILE=$(OUTDIR)/test_$(TEST_INDEX)/samples.txt
GHDL_RUNOPTS += -gCASE_FILE=$(OUTDIR)/test_$(TEST_INDEX)/test_case.txt
GHDL_RUNOPTS += -gTEST_INDEX=$(TEST_INDEX)
GHDL_RUNOPTS += -gTEST_VECTORS=test_vectors.csv

WORKDIR  = work
OUTDIR   = output
VENVDIR  = py/.venv

RTL_SRC = $(wildcard ./rtl/*.vhd)
TBS_SRC = $(wildcard ./tbs/*.vhd)

RTL_TOP = sig_gen
TBS_TOP = sig_gen_tb

TEST_INDEX  ?= 0
NUM_PERIODS ?= 4

.PHONY: all run analyze tests clean distclean

all: run

$(WORKDIR) $(OUTDIR)/test_$(TEST_INDEX):
	@mkdir -p $@

$(VENVDIR): py/requirements.txt
	@python3 -m venv $(VENVDIR)
	$(VENVDIR)/bin/python3 -m pip install -r py/requirements.txt

.import: $(RTL_SRC) $(TBS_SRC) | $(WORKDIR)
	@$(GHDL) import $(GHDL_OPTS) $(RTL_SRC) $(TBS_SRC) | tee $@

import: .import

.make: .import
	@$(GHDL) make $(GHDL_OPTS) $(TBS_TOP) | tee $@

make: .make

run: .make | $(OUTDIR)/test_$(TEST_INDEX)
	@$(GHDL) run $(TBS_TOP) $(GHDL_RUNOPTS)

analyze: run $(VENVDIR) | $(OUTDIR)/test_$(TEST_INDEX)
	$(VENVDIR)/bin/python3 py/analyze_sig_gen.py --data $(OUTDIR)/test_$(TEST_INDEX)/samples.txt --clk-frequency 50e6 > $(OUTDIR)/test_$(TEST_INDEX)/analysis.txt

clean:
	@$(GHDL) clean $(GHDL_OPTS)
	@rm -rf $(WORKDIR) $(OUTDIR) .import .make

distclean: clean
	@rm -rf $(VENVDIR)

tests: test_vectors.csv
	@for idx in $$(tail -n +2 $< | cut -d, -f1); do $(MAKE) --no-print-directory analyze TEST_INDEX=$$idx; done