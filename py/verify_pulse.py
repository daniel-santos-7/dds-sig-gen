#!/usr/bin/env python3
import argparse
import csv
import math
import sys


def verify(data_file, amp_val, pulse_len, out_bits=12):
    with open(data_file) as f:
        vals = [(int(r[0]), int(r[1])) for r in csv.reader(f)]

    if not vals:
        print("[FAIL] No samples found")
        sys.exit(1)

    half_range = 2 ** (out_bits - 1)
    peak_scale = 2 ** (out_bits - 2) - 1
    def from_twos(v): return v if v < half_range else v - 2 * half_range
    i = [from_twos(v[0]) for v in vals]
    q = [from_twos(v[1]) for v in vals]
    mags = [math.sqrt(v[0] ** 2 + v[1] ** 2) for v in zip(i, q)]

    n = len(vals)
    pass_count = 0
    fail_count = 0

    def check(name, ok, detail=""):
        nonlocal pass_count, fail_count
        if ok:
            print(f"  [PASS] {name}" + (f" ({detail})" if detail else ""))
            pass_count += 1
        else:
            print(f"  [FAIL] {name}" + (f" ({detail})" if detail else ""))
            fail_count += 1

    # Extinction: first 5 and last 5 samples should be near zero
    # Small non-zero values are expected from initial Gaussian LUT entry (~11) * amp scaling
    pre_max = max(mags[:5])
    check("Extinction pre-pulse", pre_max < max(50, half_range // 20),
          f"max deviation={pre_max:.0f} LSBs")

    post_max = max(mags[-5:])
    check("Extinction post-pulse", post_max < max(50, half_range // 20),
          f"max deviation={post_max:.0f} LSBs")

    # Glitch check: pulse should be a single contiguous block
    active_regions = []
    in_pulse = False
    start = 0
    threshold = max(1, half_range // 1000)
    for idx, m in enumerate(mags):
        if m > threshold and not in_pulse:
            start = idx
            in_pulse = True
        elif m <= threshold and in_pulse:
            active_regions.append((start, idx - 1))
            in_pulse = False
    if in_pulse:
        active_regions.append((start, n - 1))

    check("Single active region", len(active_regions) == 1,
          f"got {len(active_regions)} regions")

    if active_regions:
        start, end = active_regions[0]
        width = end - start + 1
        check("Pulse width", abs(width - pulse_len) <= max(3, pulse_len // 25),
              f"{width} cycles, expected {pulse_len}")

        # Envelope symmetry: peak at ~50% of pulse
        peak_idx = max(range(start, end + 1), key=lambda k: mags[k])
        peak_pos = (peak_idx - start) / width
        check("Envelope symmetry", 0.4 <= peak_pos <= 0.6,
              f"peak at {peak_pos:.1%} of pulse")

        # Peak magnitude
        peak_mag = max(mags[start:end + 1])
        expected_peak = amp_val / 65535.0 * peak_scale * 0.9
        check("Peak magnitude", peak_mag >= expected_peak,
              f"{peak_mag:.0f} >= {expected_peak:.0f}")

    total = pass_count + fail_count
    print(f"\n{pass_count}/{total} checks passed" +
          ("" if fail_count == 0 else f", {fail_count} FAILED"))
    return fail_count == 0



