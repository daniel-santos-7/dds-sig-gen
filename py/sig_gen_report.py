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


import matplotlib.pyplot as plt

def generate_plots(directory, values, clk):
    os.makedirs(directory, exist_ok=True)
    
    if values.ndim > 1:
        i_vals = values[:, 0]
        q_vals = values[:, 1]
        
        plt.figure(figsize=(10, 4))
        plt.plot(i_vals, label="I Channel (Gaussian)")
        plt.plot(q_vals, label="Q Channel (DRAG)")
        plt.title("IQ Envelope Generation")
        plt.legend()
        plt.grid(True)
        plt.savefig(os.path.join(directory, "iq_envelope.png"))
        plt.close()
        
        est, spec, fit, _ = analyze(i_vals, clk)
        est.plot(os.path.join(directory, "waveform_i.png"))
        fit.plot(os.path.join(directory, "fit_compare_i.png"))
        spec.plot(os.path.join(directory, "spectrum_i.png"))
        write_report(os.path.join(directory, "analysis_i.txt"), i_vals, clk)
    else:
        est, spec, fit, _ = analyze(values, clk)
        est.plot(os.path.join(directory, "waveform.png"))
        fit.plot(os.path.join(directory, "fit_compare.png"))
        spec.plot(os.path.join(directory, "spectrum.png"))
        write_report(os.path.join(directory, "analysis.txt"), values, clk)



