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

    try:
        est = SineEstimate(values, args.clk_frequency)
        spec = Spectrum(values, args.clk_frequency)
        fit = SineFit(values, args.clk_frequency, spec.fund_freq)
        metrics = SpectralMetrics(spec)

        est.report()
        fit.report()
        spec.report()
        metrics.report()
    except ValueError as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
