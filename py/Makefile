LUT_ADDR_BITS = 12

OUT_RES_BITS = 16

INITIAL_PHASE = 0

FINAL_PHASE = 90

../rtl/sine_lut_pkg.vhd: ./gen_sine_lut_pkg.py
	./gen_sine_lut_pkg.py $(LUT_ADDR_BITS) $(OUT_RES_BITS) $(INITIAL_PHASE) $(FINAL_PHASE) > $@

../rtl/envelope_lut_pkg.vhd: ./gen_envelope_lut_pkg.py
	./gen_envelope_lut_pkg.py $(LUT_ADDR_BITS) $(OUT_RES_BITS) > $@

all: ../rtl/sine_lut_pkg.vhd ../rtl/envelope_lut_pkg.vhd