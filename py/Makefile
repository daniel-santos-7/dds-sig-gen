LUT_ADDR_BITS = 10

OUT_RES_BITS = 12
ENV_LUT_ADDR_BITS = 10
ENV_OUT_RES_BITS = 16

INITIAL_PHASE = 0

FINAL_PHASE = 90

../rtl/sine_lut_pkg.vhd: ./gen_sine_lut_pkg.py
	./gen_sine_lut_pkg.py $(LUT_ADDR_BITS) $(OUT_RES_BITS) $(INITIAL_PHASE) $(FINAL_PHASE) > $@

../rtl/envelope_lut_pkg.vhd: ./gen_envelope_lut_pkg.py
	./gen_envelope_lut_pkg.py $(ENV_LUT_ADDR_BITS) $(ENV_OUT_RES_BITS) > $@

all: ../rtl/sine_lut_pkg.vhd ../rtl/envelope_lut_pkg.vhd