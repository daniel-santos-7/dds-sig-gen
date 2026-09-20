# DDS Signal Generator

A Wishbone-peripheral VHDL Direct Digital Synthesis (DDS) signal generator with programmable Gaussian pulse envelopes and DRAG correction, designed for quantum control applications.

Written in VHDL-93, simulated with GHDL, analyzed with a Python/numpy/scipy toolchain.

## Architecture

```
wb_sig_gen (Wishbone peripheral, ADDR_WIDTH=3)
├── sig_gen_csrs      — 7 CSR registers; latches TRIG into valid_reg, held until sig_gen_ctrl reports ready
└── sig_gen
    ├── sig_gen_ctrl  — FSM (IDLE/ACTIVE/DELAY): latches FTW/POW/AMP/ENV/DRAG on trigger, drives the enable, runs the inter-pulse delay counter
    ├── env_seq       — envelope step accumulator; its address feeds env_gen, its done flag ends the pulse
    ├── pha_acc       — phase accumulator, cleared between pulses so each one starts at POW
    ├── sin_pac       — quarter-wave LUT + full-wave reconstruction (sin + cos)
    ├── env_gen       — Gaussian envelope lookup + amplitude/DRAG scaling
    └── iq_mod        — IQ modulator: I = gauss·cos − drag·sin, Q = gauss·sin + drag·cos
```

`iq_mod` computes the complex product `(gauss + j·drag)·e^{jθ}` (I = Re, Q = Im), the standard IQ-upconversion convention. Its output is the top `OUT_RES_BITS` of the `2*OUT_RES_BITS+1`-bit product with a half-LSB carry-in, so the slice rounds rather than floors.

Total latency from the phase accumulator to `sig_i_o`/`sig_q_o` is 5 clock cycles (3 in `sin_pac`, 2 in `iq_mod`), matched by the envelope path.

## CSR Map

| Address | Register | Description |
|---------|----------|-------------|
| `0x0` | FTW | Frequency tuning word (32-bit) |
| `0x1` | POW | Phase offset word (32-bit), added to the accumulator on trigger |
| `0x2` | AMP | Amplitude scalar (16-bit, unsigned) |
| `0x3` | DRAG | Pre-scaled DRAG value, Q1.15 (16-bit) — **not** β; see [DRAG scaling](#drag-scaling) |
| `0x4` | ENV | Envelope step (32-bit); see [Pulse length](#pulse-length) |
| `0x5` | DELAY | Inter-pulse delay in clock cycles (24-bit), written independently of TRIG |
| `0x6` | TRIG | Write bit-0 to request a trigger; readback `{30'b0, ready, valid}` |

Writing TRIG sets `valid`, which stays high — even across further register writes — until the FSM returns to IDLE. Triggering during an active pulse or its post-pulse delay therefore queues the request instead of dropping it. FTW/POW/AMP/ENV/DRAG are latched atomically at the instant the pulse starts, not when they are written.

### Pulse length

`env_seq` accumulates the ENV step and ends the pulse when the accumulator overflows, so the value to write is

```
ENV = 2^ENV_ACC_BITS / PULSE_LEN
```

with `ENV_ACC_BITS` defaulting to 32. That division lives in software, not in the RTL.

### DRAG scaling

The DRAG register does **not** hold the DRAG coefficient β directly. Two factors sit between them:

```
DRAG_csr = β · 0.6065306597 · (AMP / 65535)     in Q1.15
```

- `0.6065306597` is the peak of `-t·exp(-t²/2)`, by which `DRAG_TABLE` is normalised so it spans full scale (`DRAG_PEAK` in `py/gen_lut_pkg.py`).
- `AMP / 65535` is required because `env_gen` scales only the gaussian path by `amp_i`. The DRAG register is expected to arrive already scaled by the amplitude, which keeps a multiplier out of the sample-rate datapath and moves it into software, where it runs once per pulse.

β is the coefficient of the Motzoi et al. (2009) / Qiskit Pulse `Drag` convention, and may be negative. Writing β directly instead yields `β_eff = β · 1.6488 · 65535/AMP` — wrong by 1.65× at full scale, and inversely proportional to amplitude below it.

Resolution of the register falls with `AMP` (~11 bits at `AMP=16384`), since the DRAG path has no amplitude multiplier of its own.

## Generics

Set on `wb_sig_gen` and forwarded down unchanged.

| Generic | Default | Description |
|---------|---------|-------------|
| `DATA_WIDTH` | 32 | Wishbone data width |
| `ADDR_WIDTH` | 3 | Wishbone address width |
| `PHA_ACC_BITS` | 32 | Phase accumulator width; sets FTW/POW resolution |
| `ENV_ACC_BITS` | 32 | Envelope accumulator width; sets the ENV contract above |
| `DRAG_DERIV_EN` | false | `false` reads `DRAG_TABLE`; `true` derives DRAG as the finite difference of consecutive `GAUSS_TABLE` samples |
| `DRAG_K_SHIFT` | 0 | Left shift applied to the derived DRAG term, only when `DRAG_DERIV_EN` is true |

The derivative path is step-size dependent (its scaling varies with `PULSE_LEN`), unlike the LUT path. It also has a known overflow at short pulse lengths — see issue #4.

## Building & Running

Requires [GHDL](https://ghdl.github.io/ghdl/) (the build uses `--std=93 -fsynopsys`) and Python 3 for the analysis.

```bash
make run        # compile + simulate one pulse (default: 100 kHz, 200-cycle pulse)
make analyze    # raw + fit + spectrum together
make raw        # estimate raw I/Q parameters from the samples
make fit        # fit a sine + Gaussian-envelope model to the I/Q samples
make spectrum   # spectral metrics (SFDR/SNR/SINAD/ENOB)
make luts       # regenerate rtl/sine_lut_pkg.vhd + rtl/envelope_lut_pkg.vhd
make sweep SWEEP_ARGS="--freq 1e5,1e6 --drag 0,0.25,0.5"   # batch run+fit over a grid
make clean      # remove work/, output/, .import, .make
make distclean  # also remove py/.venv
```

Run `make run` before `analyze`/`raw`/`fit`/`spectrum` — those read the samples file the simulation produces. `make sweep` is the exception: it invokes `make run` itself for each grid point and writes one CSV row per combination to `output/sweep_results.csv`.

Each `make run` performs one full pulse simulation; there is no test-suite runner and no lint/format tooling in this repository.

### Simulation overrides

```bash
make run FREQ_HZ=1000000 PHASE_DEG=45 AMP_VAL=65535 PULSE_LEN=500 DRAG_COEFF=0.3
```

| Variable | Default | Description |
|----------|---------|-------------|
| `FREQ_HZ` | 100000 | Output sine frequency |
| `PHASE_DEG` | 0 | Initial phase (degrees) |
| `AMP_VAL` | 65535 | Written to the AMP CSR; scales envelope amplitude |
| `PULSE_LEN` | 200 | Envelope pulse length in clock cycles |
| `DRAG_COEFF` | 0.5 | Raw DRAG CSR value, **not** the physical β (converted to Q1.15 by the Makefile); see [DRAG scaling](#drag-scaling) |
| `OUT_RES_BITS` | 10 | Signed datapath / DAC width (bits) |
| `LUT_ADDR_BITS` | 10 | Sine LUT address bits |
| `ENV_LUT_ADDR_BITS` | 10 | Envelope LUT address bits |
| `ENV_OUT_RES_BITS` | 12 | Envelope datapath width (bits) |
| `INITIAL_PHASE` | 0 | Sine LUT start phase in degrees (`make luts` only) |
| `FINAL_PHASE` | 90 | Sine LUT end phase in degrees (`make luts` only) |
| `CLK_FREQ_HZ` | 100e6 | Python analysis only; the VHDL simulation hardcodes 100 MHz |

Changing `OUT_RES_BITS`, `LUT_ADDR_BITS` or either `ENV_*` requires regenerating the LUT packages before the next `make run`, since the RTL derives its widths from them.

## Testbench

`tbs/sig_gen_tb.vhd` runs a **single pulse**: it writes FTW, POW, AMP, DRAG and ENV, then TRIG, and captures I/Q while the output is active.

Two limits are worth knowing before trusting a green `make run`:

- **There are no assertions.** The testbench only reports and dumps samples; nothing in VHDL checks a value. A passing run means "it elaborated and ran", not "it is correct" — every actual check happens in the Python analysis afterwards.
- **DELAY is never written**, so neither the inter-pulse delay state nor the queued-trigger-while-active path is exercised.

## Lookup table generation

`rtl/sine_lut_pkg.vhd` and `rtl/envelope_lut_pkg.vhd` are generated, not hand-edited:

```bash
make luts
```

Their widths come from `OUT_RES_BITS`, `LUT_ADDR_BITS`, `ENV_LUT_ADDR_BITS` and `ENV_OUT_RES_BITS` in the table above.

**Gotcha:** the make rules depend only on the Python scripts, not on those width variables, so `make luts OUT_RES_BITS=14` is a silent no-op when the packages are already newer than the scripts. Delete the two `rtl/*_lut_pkg.vhd` files first, then run it.

All three tables store unsigned magnitude only — the sign comes from the RTL, which applies the quadrant bits for sine and mirrors/negates the half-table for the envelope.

## Python analysis

`py/sig_gen.py` is the CLI entry point (subcommands `raw`, `fit`, `spectrum`, `gen-lut`). The analysis targets auto-create a virtualenv at `py/.venv` from `py/requirements.txt` (numpy, scipy, matplotlib).

`make fit` needs enough carrier cycles inside the pulse window: the defaults (100 kHz over 200 cycles at 100 MHz = 0.2 cycle) make it fail outright. A usable test point is `FREQ_HZ=1234567 PULSE_LEN=2000`, deliberately non-commensurate with the clock so phase-truncation spurs are not masked by an exact FTW.

`make spectrum`'s SFDR/SNR/SINAD/ENOB are misleading for pulsed signals — they measure the envelope's spectral spread rather than DDS non-idealities, though THD remains meaningful. To isolate DDS errors from the envelope, use the residual SFDR reported by `make sweep`; for a single run, `make fit`'s fit-error RMS is the usable proxy.

## Generated artifacts

Simulation output lands in a directory named after the run's parameters, `output/test_<freq>hz_<phase>deg_<amp>_<len>len_<drag>drag/`:

| Path | Description |
|------|-------------|
| `work/` | GHDL compilation output (removed by `make clean`) |
| `output/test_*/samples.txt` | Raw I/Q samples, one `i,q` pair per line |
| `output/test_*/test_case.txt` | The parameters the run was given |
| `output/test_*/reg_values.txt` | The CSR values derived from them |
| `output/test_*/sig_gen_tb.ghw` | Simulation waveforms |
| `output/test_*/{raw,fit,spectrum}.txt` | Analysis results, plus their PNG plots |
| `output/sweep_results.csv` | One row per grid point from `make sweep` |

## License

MIT — see [LICENSE](LICENSE).
