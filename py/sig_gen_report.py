#!/usr/bin/env python3
import argparse
import numpy as np
import os
import sys
from spectrum import Spectrum
from spectral_metrics import SpectralMetrics
from sine_estimate import SineEstimate
from sine_fit import SineFit


def analyze(values, clk):
    est = SineEstimate(values, clk)
    spec = Spectrum(values, clk)
    fit = SineFit(values, clk, spec.fund_freq)
    metrics = SpectralMetrics(spec)
    return est, spec, fit, metrics


def write_report(path, values, clk):
    est, spec, fit, metrics = analyze(values, clk)
    with open(path, "w") as f:
        old = sys.stdout
        sys.stdout = f
        est.report()
        fit.report()
        spec.report()
        metrics.report()
        sys.stdout = old


def generate_plots(directory, values, clk):
    os.makedirs(directory, exist_ok=True)
    est, spec, fit, _ = analyze(values, clk)
    est.plot(os.path.join(directory, "waveform.png"))
    fit.plot(os.path.join(directory, "fit_compare.png"))
    spec.plot(os.path.join(directory, "spectrum.png"))
    write_report(os.path.join(directory, "analysis.txt"), values, clk)


def main():
    parser = argparse.ArgumentParser(description="Analyze and/or plot sig_gen samples.")
    parser.add_argument("--data", required=True)
    parser.add_argument("--clk", type=float, required=True)
    parser.add_argument("--output", metavar="FILE", help="Write analysis report to FILE")
    parser.add_argument("--plot", metavar="DIR", help="Generate plots + analysis.txt in DIR")
    args = parser.parse_args()

    if not args.output and not args.plot:
        parser.error("at least one of --output or --plot is required")

    values = np.loadtxt(args.data)

    if args.output:
        write_report(args.output, values, args.clk)

    if args.plot:
        generate_plots(args.plot, values, args.clk)


if __name__ == "__main__":
    main()
