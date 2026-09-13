#!/usr/bin/env python3
"""Batch-sweep make run + fit analysis over a grid of simulation parameters.

Runs `make run` for every combination of FREQ_HZ / DRAG_COEFF / PULSE_LEN
(and optionally AMP_VAL / PHASE_DEG), fits each resulting samples.txt with
sine_fit.IQFit, and appends one row per combination to a CSV. Meant to
replace point-by-point `make run && make fit` exploration with a systematic
sweep (e.g. characterizing the valid DRAG_COEFF range, or frequency-dependent
phase-truncation spurs).
"""
import argparse
import csv
import itertools
import os
import subprocess
import sys
import time

import numpy as np
from scipy.signal import periodogram

from raw import Raw
from sine_fit import IQFit

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def parse_grid(s, cast=float):
    return [cast(x) for x in s.split(",")]


def fmt_int(v):
    return str(int(round(v)))


def fmt_real(v):
    s = f"{float(v):.6f}".rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def testdir_for(freq, phase, amp, pulse_len, drag):
    name = f"test_{freq}hz_{phase}deg_{amp}_{pulse_len}len_{drag}drag"
    return os.path.join(REPO_ROOT, "output", name)


def run_make(freq, phase, amp, pulse_len, drag):
    cmd = [
        "make", "run",
        f"FREQ_HZ={freq}",
        f"PHASE_DEG={phase}",
        f"AMP_VAL={amp}",
        f"PULSE_LEN={pulse_len}",
        f"DRAG_COEFF={drag}",
    ]
    subprocess.run(cmd, cwd=REPO_ROOT, check=True, capture_output=True, text=True)


def residual_sfdr_db(values, model_values, clk_freq_hz):
    """SFDR-like metric: fundamental power of the ideal fit vs. the largest
    spectral peak in (data - fit). Isolates DDS non-idealities (quantization,
    phase truncation) from the pulse envelope itself, unlike raw-sample SFDR."""
    residual = values - model_values
    _, resid_power = periodogram(residual - np.mean(residual), fs=clk_freq_hz, window="hann")
    _, model_power = periodogram(model_values - np.mean(model_values), fs=clk_freq_hz, window="hann")
    fund_power = np.max(model_power)
    max_spur_power = np.max(resid_power[1:]) if len(resid_power) > 1 else 0.0
    if max_spur_power <= 0:
        return float("inf")
    return 10 * np.log10(fund_power / max_spur_power)


FIELDS = [
    "freq_hz", "phase_deg", "amp_val", "pulse_len", "drag_coeff",
    "fit_ok", "error",
    "i_rms", "i_freq_fit_hz", "i_freq_err_ppm", "i_phase_fit_deg",
    "i_beta_fit", "i_beta_ratio", "i_residual_sfdr_db",
    "q_rms", "q_freq_fit_hz", "q_phase_fit_deg",
    "q_beta_fit", "q_beta_ratio", "q_residual_sfdr_db",
    "jitter_ui",
]


def analyze_combo(freq, phase, amp, pulse_len, drag_str, clk_freq_hz):
    testdir = testdir_for(freq, phase, amp, pulse_len, drag_str)
    samples_path = os.path.join(testdir, "samples.txt")
    data = np.loadtxt(samples_path, delimiter=",")
    i_vals, q_vals = data[:, 0], data[:, 1]

    fit = IQFit(i_vals, q_vals, clk_freq_hz)

    drag = float(drag_str)
    row = {
        "freq_hz": freq, "phase_deg": phase, "amp_val": amp,
        "pulse_len": pulse_len, "drag_coeff": drag,
        "fit_ok": True, "error": "",
    }
    for label, ch, values in (("i", fit.i, i_vals), ("q", fit.q, q_vals)):
        row[f"{label}_rms"] = ch.rms
        row[f"{label}_freq_fit_hz"] = ch.freq
        row[f"{label}_phase_fit_deg"] = ch.phase_deg
        row[f"{label}_beta_fit"] = ch.beta
        row[f"{label}_beta_ratio"] = ch.beta / drag if drag != 0 else float("nan")
        row[f"{label}_residual_sfdr_db"] = residual_sfdr_db(values, ch.model_values(), clk_freq_hz)
    row["i_freq_err_ppm"] = (fit.i.freq - freq) / freq * 1e6 if freq else float("nan")
    j = fit.jitter
    row["jitter_ui"] = j if j is not None else float("nan")
    return row


def error_row(freq, phase, amp, pulse_len, drag, message):
    row = {f: "" for f in FIELDS}
    row.update({
        "freq_hz": freq, "phase_deg": phase, "amp_val": amp,
        "pulse_len": pulse_len, "drag_coeff": drag,
        "fit_ok": False, "error": message,
    })
    return row


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--freq", default="100000", help="comma-separated FREQ_HZ values")
    ap.add_argument("--phase", default="0", help="comma-separated PHASE_DEG values")
    ap.add_argument("--amp", default="65535", help="comma-separated AMP_VAL values")
    ap.add_argument("--pulse-len", default="200", help="comma-separated PULSE_LEN values")
    ap.add_argument("--drag", default="0.5", help="comma-separated DRAG_COEFF values")
    ap.add_argument("--clk", type=float, default=100e6, help="clock frequency for analysis (Hz)")
    ap.add_argument("--out", default=os.path.join(REPO_ROOT, "output", "sweep_results.csv"))
    args = ap.parse_args()

    freqs = parse_grid(args.freq, int)
    phases = parse_grid(args.phase, int)
    amps = parse_grid(args.amp, int)
    pulse_lens = parse_grid(args.pulse_len, int)
    drags = parse_grid(args.drag, float)

    combos = list(itertools.product(freqs, phases, amps, pulse_lens, drags))
    print(f"Sweeping {len(combos)} combination(s) -> {args.out}", file=sys.stderr)

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()

        for n, (freq, phase, amp, pulse_len, drag_raw) in enumerate(combos, 1):
            drag = fmt_real(drag_raw)
            t0 = time.time()
            print(f"[{n}/{len(combos)}] FREQ_HZ={freq} PHASE_DEG={phase} "
                  f"AMP_VAL={amp} PULSE_LEN={pulse_len} DRAG_COEFF={drag} ...",
                  end=" ", file=sys.stderr, flush=True)
            try:
                run_make(freq, phase, amp, pulse_len, drag)
                row = analyze_combo(freq, phase, amp, pulse_len, drag, args.clk)
                writer.writerow(row)
                print(f"ok ({time.time() - t0:.1f}s) RMS(I)={row['i_rms']:.2f} "
                      f"beta_ratio(I)={row['i_beta_ratio']:.3f} "
                      f"resSFDR(I)={row['i_residual_sfdr_db']:.1f}dB",
                      file=sys.stderr)
            except subprocess.CalledProcessError as e:
                msg = f"make run failed: {e.stderr.strip()[-300:]}"
                writer.writerow(error_row(freq, phase, amp, pulse_len, drag, msg))
                print(f"FAILED ({msg[:120]})", file=sys.stderr)
            except (RuntimeError, ValueError) as e:
                writer.writerow(error_row(freq, phase, amp, pulse_len, drag, str(e)))
                print(f"FIT FAILED ({e})", file=sys.stderr)
            f.flush()

    print(f"Done. Results in {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
