#!/usr/bin/env python3
import argparse
import numpy as np
from spectrum import Spectrum
from spectral_metrics import SpectralMetrics
from sine_estimate import SineEstimate
from sine_fit import SineFit

def trim_leading(values):
    first = values[0]
    n_repeat = np.argmax(values != first)
    return values[n_repeat:] if n_repeat > 0 else values

def main():
    parser = argparse.ArgumentParser(description="Analyze sig_gen samples.")
    parser.add_argument("--data", required=True)
    parser.add_argument("--clk-frequency", type=float, required=True)
    args = parser.parse_args()

    values = np.loadtxt(args.data)
    values = trim_leading(values)
    n = len(values)

    try:
        est = SineEstimate(values, args.clk_frequency)
    except ValueError as e:
        print(f"Error: {e}")
        return

    try:
        spec = Spectrum(values, args.clk_frequency)
    except ValueError as e:
        print(f"Error: {e}")
        return

    try:
        fit = SineFit(values, args.clk_frequency, spec.fund_freq)
    except ValueError as e:
        print(f"Error: {e}")
        return

    spec.fund_freq = fit.freq

    metrics = SpectralMetrics(spec)

    print(f"Samples: {n}")
    est.report()
    fit.report()
    spec.report()
    metrics.report()

if __name__ == "__main__":
    main()
