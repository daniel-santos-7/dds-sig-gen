#!/usr/bin/env python3
import argparse
import numpy as np
from scipy.optimize import curve_fit
from scipy.signal import periodogram

def sine_model(t, amp, freq, phase, offset):
    return amp * np.sin(2 * np.pi * freq * t + phase) + offset

def freq_guess(power, freqs):
    peak = np.argmax(power)
    return None if peak == 0 else freqs[peak]

def trim_leading(values):
    first = values[0]
    n_repeat = np.argmax(values != first)
    return values[n_repeat:] if n_repeat > 0 else values


def bins_around(freqs, target_freq, half_width):
    center = np.argmin(np.abs(freqs - target_freq))
    return set(range(max(0, center - half_width), min(len(freqs), center + half_width + 1)))

def fundamental_power(power, freqs, fund_freq):
    fund_bins = bins_around(freqs, fund_freq, 1)
    return np.sum(power[list(fund_bins - {0})])

def harmonic_bins(freqs, fund_freq):
    fund_bins = bins_around(freqs, fund_freq, 1)
    harm_bins = set()
    for h in range(2, 6):
        hf = fund_freq * h
        if hf >= freqs[-1] * 2:
            break
        harm_bins |= bins_around(freqs, hf, 1)
    harm_bins -= {0} | fund_bins
    return harm_bins

def harmonic_power(power, freqs, fund_freq):
    harm_bins = harmonic_bins(freqs, fund_freq)
    return np.sum(power[list(harm_bins)]) if harm_bins else 0

def spur_power(power, freqs, fund_freq):
    fund_bins = bins_around(freqs, fund_freq, 1)
    harm_bins = harmonic_bins(freqs, fund_freq)
    excluded = {0} | fund_bins | harm_bins
    candidates = [b for b in range(1, len(freqs)) if b not in excluded]
    return np.max(power[candidates]) if candidates else 1e-30

def sfdr_db(power, freqs, fund_freq):
    p_fund = fundamental_power(power, freqs, fund_freq)
    p_spur = spur_power(power, freqs, fund_freq)
    return 10 * np.log10(p_fund / p_spur)

def thd(power, freqs, fund_freq):
    p_fund = fundamental_power(power, freqs, fund_freq)
    p_harm = harmonic_power(power, freqs, fund_freq)
    return p_harm / p_fund if p_fund > 0 else 0.0

def noise_power(power, freqs, fund_freq):
    p_fund = fundamental_power(power, freqs, fund_freq)
    p_harm = harmonic_power(power, freqs, fund_freq)
    p_spur = spur_power(power, freqs, fund_freq)
    p_total = np.sum(power[1:])
    p_noise = p_total - p_fund - p_harm - p_spur
    return p_noise if p_noise > 0 else 1e-30

def snr_db(power, freqs, fund_freq):
    p_fund = fundamental_power(power, freqs, fund_freq)
    p_noise = noise_power(power, freqs, fund_freq)
    return 10 * np.log10(p_fund / p_noise)

def sinad_db(power, freqs, fund_freq):
    p_fund = fundamental_power(power, freqs, fund_freq)
    p_total = np.sum(power[1:])
    p_dist = p_total - p_fund
    return 10 * np.log10(p_fund / p_dist) if p_dist > 0 else float('inf')

def enob(power, freqs, fund_freq):
    return (sinad_db(power, freqs, fund_freq) - 1.76) / 6.02

def jitter_ui(ac, t, freq):
    signs = np.sign(ac)
    rising = np.where(np.diff(signs) > 0)[0]
    if len(rising) < 2:
        return None
    dt_sample = t[1] - t[0]
    cross_times = [(c + (-ac[c] / (ac[c + 1] - ac[c]))) * dt_sample
                   for c in rising]
    periods = np.diff(cross_times)
    return np.std(periods) * freq


def fit_sine(values, clk_frequency, freq0):
    n = len(values)
    if n < 4:
        return None

    t = np.arange(n) / clk_frequency

    offset0 = np.mean(values)
    amp0 = np.ptp(values) / 2

    try:
        popt, _ = curve_fit(sine_model, t, values,
                             p0=[amp0, freq0, 0, offset0],
                             maxfev=5000)
    except (RuntimeError, ValueError):
        return None

    return (*popt, t)


def main():
    parser = argparse.ArgumentParser(description="Analyze sig_gen samples.")
    parser.add_argument("--data", required=True)
    parser.add_argument("--clk-frequency", type=float, required=True)
    args = parser.parse_args()

    values = np.loadtxt(args.data)
    values = trim_leading(values)
    n = len(values)

    if n < 4:
        print("Error: not enough samples for analysis")
        return

    ac = values - np.mean(values)
    freqs, power = periodogram(ac, fs=args.clk_frequency, window='hann')

    freq0 = freq_guess(power, freqs)
    if freq0 is None:
        print("Error: could not determine initial frequency")
        return

    result = fit_sine(values, args.clk_frequency, freq0)
    if result is None:
        print("Error: sine fit did not converge")
        return

    amp, freq, phase, offset, t = result

    ac = values - offset
    jitter = jitter_ui(ac, t, freq)

    thd_val = thd(power, freqs, freq)

    sinad_val = sinad_db(power, freqs, freq)
    enob_val = enob(power, freqs, freq)
    snr_val = snr_db(power, freqs, freq)
    sfdr_val = sfdr_db(power, freqs, freq)
    phase_deg = np.degrees(phase)

    print(f"Samples: {n}")
    print(f"Amplitude: {amp:.3f} counts")
    print(f"Frequency: {freq:.6f} Hz")
    print(f"Phase: {phase_deg:.3f} deg")
    print(f"DC offset: {offset:.3f} counts")
    print(f"THD: {thd_val:.6f}")
    print(f"SFDR: {sfdr_val:.2f} dB")
    print(f"SNR: {snr_val:.2f} dB")
    print(f"SINAD: {sinad_val:.2f} dB")
    print(f"ENOB: {enob_val:.2f} bits")
    if jitter is not None:
        print(f"Phase jitter: {jitter:.2e} UI ({jitter / freq:.2e} s)")
    else:
        print("Phase jitter: unavailable")


if __name__ == "__main__":
    main()
