#!/usr/bin/env python3
import argparse
import numpy as np
from spectrum import Spectrum
from spectral_metrics import SpectralMetrics
from sine_estimate import SineEstimate
from sine_fit import SineFit

def main():
    parser = argparse.ArgumentParser(description="Analyze sig_gen samples.")
    parser.add_argument("--data", required=True)
    parser.add_argument("--clk", type=float, required=True)
    args = parser.parse_args()

    values = np.loadtxt(args.data)

    try:
        est = SineEstimate(values, args.clk)
        spec = Spectrum(values, args.clk)
        fit = SineFit(values, args.clk, spec.fund_freq)
        metrics = SpectralMetrics(spec)

        est.report()
        fit.report()
        spec.report()
        metrics.report()
    except ValueError as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
