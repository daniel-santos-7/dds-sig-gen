#!/usr/bin/env python3
import argparse
import numpy as np
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sine_fit import SineFit
from spectrum import Spectrum


def plot_waveform(values, clk, path):
    n = len(values)
    t = np.arange(n) / clk * 1e6

    fig, ax = plt.subplots(figsize=(12, 4))
    ax.step(t, values, linewidth=0.8, where="post")
    ax.set_xlabel("Time (µs)")
    ax.set_ylabel("Amplitude")
    ax.set_title(f"Waveform ({n} samples @ {clk/1e6:.0f} MHz)")
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def plot_fit_compare(values, clk, path):
    from sine_estimate import SineEstimate
    from spectral_metrics import SpectralMetrics

    est = SineEstimate(values, clk)
    spec = Spectrum(values, clk)
    fit = SineFit(values, clk, spec.fund_freq)

    n = len(values)
    t_s = np.arange(n) / clk
    t_us = t_s * 1e6
    y_fit = fit._sine_model(t_s, fit._amp, fit._freq, fit._phase, fit._offset)

    fig, ax = plt.subplots(figsize=(12, 5))
    ax.step(t_us, values, linewidth=0.5, where="post", alpha=0.6, label="Samples")
    ax.plot(t_us, y_fit, linewidth=1.5, color="red", label="Fit")
    ax.set_xlabel("Time (µs)")
    ax.set_ylabel("Amplitude")
    ax.set_title(f"Fit comparison (freq={fit._freq:.3f} Hz, amp={fit._amp:.3f})")
    ax.legend()
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def plot_spectrum(values, clk, path):
    spec = Spectrum(values, clk)

    ac = values - np.mean(values)
    freqs, power = spec._freqs, spec._power

    fig, ax = plt.subplots(figsize=(12, 5))
    ax.plot(freqs / 1e6, 10 * np.log10(power + 1e-30), linewidth=0.8)
    ax.set_xlabel("Frequency (MHz)")
    ax.set_ylabel("Power (dB)")
    ax.set_title("Spectrum")
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser(description="Plot sig_gen samples.")
    parser.add_argument("--data", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--clk", type=float, default=50e6)
    args = parser.parse_args()

    values = np.loadtxt(args.data)

    plot_waveform(values, args.clk, os.path.join(args.output, "waveform.png"))
    plot_fit_compare(values, args.clk, os.path.join(args.output, "fit_compare.png"))
    plot_spectrum(values, args.clk, os.path.join(args.output, "spectrum.png"))


if __name__ == "__main__":
    main()
