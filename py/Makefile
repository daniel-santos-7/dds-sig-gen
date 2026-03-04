LUT_ADDR_BITS = 10

OUT_RES_BITS = 12

INITIAL_PHASE = 0

FINAL_PHASE = 90

../rtl/sine_lut_pkg.vhd: ./gen_sine_lut_pkg.py
	./gen_sine_lut_pkg.py $(LUT_ADDR_BITS) $(OUT_RES_BITS) $(INITIAL_PHASE) $(FINAL_PHASE) > $@