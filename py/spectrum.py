import os

import numpy as np
from scipy.signal import periodogram
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


class Channel:
    def __init__(self, values, clk_frequency):
        n = len(values)
        if n < 4:
            raise ValueError("not enough samples for analysis")

        ac = values - np.mean(values)
        self._freqs, self._power = periodogram(ac, fs=clk_frequency, window='hann')

        peak = np.argmax(self._power)
        if peak == 0:
            raise ValueError("could not determine initial frequency")
        freq0 = self._freqs[peak]

        self._fund_freq = freq0
        self._fund_bins = self._bins_around(freq0, 1)
        self._harm_bins = self._compute_harm_bins()
        self._max_spur_bin = self._compute_max_spur_bin()

    def _bins_around(self, target_freq, half_width):
        center = np.argmin(np.abs(self._freqs - target_freq))
        return set(range(max(0, center - half_width), min(len(self._freqs), center + half_width + 1)))

    def _compute_harm_bins(self):
        harm_bins = set()
        for h in range(2, 6):
            hf = self._fund_freq * h
            if hf >= self._freqs[-1]:
                break
            harm_bins |= self._bins_around(hf, 1)
        return (harm_bins - {0}) - self._fund_bins

    @property
    def fund_freq(self):
        return self._fund_freq

    @property
    def fundamental_power(self):
        return np.sum(self._power[list(self._fund_bins - {0})])

    @property
    def harmonic_power(self):
        return np.sum(self._power[list(self._harm_bins)]) if self._harm_bins else 0

    @property
    def spur_power(self):
        excluded = {0} | self._fund_bins | self._harm_bins
        candidates = [b for b in range(1, len(self._freqs)) if b not in excluded]
        return np.max(self._power[candidates]) if candidates else 1e-30

    @property
    def total_power(self):
        return np.sum(self._power[1:])

    @property
    def noise_power(self):
        p = self.total_power - self.fundamental_power - self.harmonic_power - self.spur_power
        return p if p > 0 else 1e-30

    @property
    def thd_db(self):
        p_fund = self.fundamental_power
        p_harm = self.harmonic_power
        return 10 * np.log10(p_harm / p_fund) if p_fund > 0 else -float('inf')

    def _compute_max_spur_bin(self):
        candidates = [b for b in range(1, len(self._freqs)) if b not in ({0} | self._fund_bins)]
        if not candidates: return None
        return candidates[np.argmax(self._power[candidates])]

    @property
    def max_spur_freq(self):
        return self._freqs[self._max_spur_bin] if self._max_spur_bin is not None else 0.0

    @property
    def max_spur_power(self):
        return self._power[self._max_spur_bin] if self._max_spur_bin is not None else 1e-30

    @property
    def sfdr_db(self):
        return 10 * np.log10(self.fundamental_power / self.max_spur_power)

    @property
    def snr_db(self):
        return 10 * np.log10(self.fundamental_power / self.noise_power)

    @property
    def sinad_db(self):
        p_fund = self.fundamental_power
        p_dist = self.total_power - p_fund
        return 10 * np.log10(p_fund / p_dist) if p_dist > 0 else float('inf')

    @property
    def enob(self):
        return (self.sinad_db - 1.76) / 6.02

    def report_lines(self, label):
        freq_mhz = self.fund_freq / 1e6
        return [
            f"  Channel {label}:",
            f"    Fundamental   {self.fundamental_power:>13.4e}  ({freq_mhz:.3f} MHz)",
            f"    Harmonic      {self.harmonic_power:>13.4e}",
            f"    Spur          {self.spur_power:>13.4e}",
            f"    Noise         {self.noise_power:>13.4e}",
            f"    Total         {self.total_power:>13.4e}",
            f"    THD           {self.thd_db:>13.2f} dB",
            f"    SFDR          {self.sfdr_db:>13.2f} dB",
            f"    SNR           {self.snr_db:>13.2f} dB",
            f"    SINAD         {self.sinad_db:>13.2f} dB",
            f"    ENOB          {self.enob:>13.2f} bits",
        ]

    def plot(self, ax=None, color=None, title="Spectrum"):
        ax = ax or plt.subplots(figsize=(12, 5))[1]
        ax.plot(self._freqs / 1e6, 10 * np.log10(self._power + 1e-30), linewidth=0.8, color=color)
        ax.set_ylabel("Power (dB)")
        ax.set_title(title)
        ax.grid(True, alpha=0.3)

        fund_mhz = self._fund_freq / 1e6
        fund_dB = 10 * np.log10(self.fundamental_power)
        ax.axvline(fund_mhz, color="#2ca02c", linestyle="--", linewidth=0.8, alpha=0.7,
                   label=f"Fund: {fund_mhz:.3f} MHz ({fund_dB:.1f} dB)")

        if self._max_spur_bin is not None:
            spur_mhz = self.max_spur_freq / 1e6
            spur_dB = 10 * np.log10(self.max_spur_power)
            ax.axvline(spur_mhz, color="#d62728", linestyle="--", linewidth=0.8, alpha=0.7,
                       label=f"Spur: {spur_mhz:.3f} MHz ({spur_dB:.1f} dB)")

        ax.legend(loc="upper right", fontsize=7)


class Spectrum:
    def __init__(self, i_values, q_values, clk_frequency):
        self._i = Channel(i_values, clk_frequency)
        self._q = Channel(q_values, clk_frequency)

    @property
    def i(self):
        return self._i

    @property
    def q(self):
        return self._q

    def __str__(self):
        lines = ["Spectrum", ""]
        lines += self._i.report_lines("I")
        lines += [""]
        lines += self._q.report_lines("Q")
        return "\n".join(lines)

    def plot(self, output_dir):
        os.makedirs(output_dir, exist_ok=True)
        fig, (ax_i, ax_q) = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
        self._i.plot(ax=ax_i, color="#1f77b4", title="Spectrum — Channel I")
        self._q.plot(ax=ax_q, color="#2ca02c", title="Spectrum — Channel Q")
        ax_q.set_xlabel("Frequency (MHz)")
        fig.tight_layout()
        fig.savefig(os.path.join(output_dir, "spectrum.png"), dpi=150)
        plt.close(fig)
