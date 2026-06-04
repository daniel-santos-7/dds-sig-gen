# AGENTS.md

## Build & Simulation

- `make` / `make run` — compile and run GHDL simulation. Outputs `waves/sig_gen_tb.ghw` + `waves/sig_gen_tb.txt`.
- `make analyze` — after a run, fits a sine wave to output and reports frequency/amplitude/phase error.
- `make clean` — removes `work/` and `waves/`.
- Override generics (raw register values) at the command line:

  ```bash
  make run REG_INC_VAL=85899345 REG_PHA_VAL=0 REG_AMP_VAL=2047
  ```

## Architecture

Testbench instantiates `wb_sig_gen` (Wishbone wrapper), not `sig_gen` directly:

```
wb_sig_gen (Wishbone peripheral)
├── sig_gen_csrs   — 4 CSR registers (inc, pha, amp, we) at addresses 0x0/0x4/0x8/0xc
└── sig_gen        — core DDS datapath
    ├── pha_acc    — phase accumulator
    ├── sine_lut   — quarter-wave LUT + full-wave reconstruction
    └── amp_scale  — amplitude multiplier
```

## Lookup Table Generation

`sine_lut_pkg.vhd` is **generated**, not built. The default `py/Makefile` produces a **quarter-wave** LUT (0–90°):

```bash
cd py && make
```

Edit `py/gen_sine_lut_pkg.py` or override make variables (`LUT_ADDR_BITS`, `OUT_RES_BITS`, `INITIAL_PHASE`, `FINAL_PHASE`).
