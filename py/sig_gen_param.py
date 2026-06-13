import numpy as np
from scipy.signal import periodogram
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


class ChannelParam:
    def __init__(self, values, clk_frequency, freq0=None):
        self._values = values.astype(np.float64)
        self._clk_frequency = clk_frequency
        self._freq0 = freq0

    @property
    def values(self):
        return self._values

    @property
    def offset(self):
        return float(np.mean(self._values))

    @property
    def amplitude(self):
        return float(np.max(self._values) - np.min(self._values))

    @property
    def freq(self):
        if self._freq0 is not None:
            return float(self._freq0)
        ac = self._values - self.offset
        freqs, power = periodogram(ac, fs=self._clk_frequency, window="hann")
        return float(freqs[np.argmax(power)])


class SigGenParam:
    def __init__(self, i_values, q_values, clk_frequency, freq0=None, pulse_len=None):
        self.i = ChannelParam(i_values, clk_frequency, freq0)
        self.q = ChannelParam(q_values, clk_frequency, freq0)
        n = len(i_values)
        self._t = np.arange(n) / clk_frequency
        self._clk_frequency = clk_frequency
        self._pulse_len = pulse_len

    @property
    def _mag(self):
        return np.sqrt(self.i.values ** 2 + self.q.values ** 2)

    @property
    def _center_idx(self):
        return int(np.argmax(self._mag))

    @property
    def off_i(self):
        return self.i.offset

    @property
    def off_q(self):
        return self.q.offset

    @property
    def amp(self):
        m = self._mag
        return float(np.max(m) - np.min(m))

    @property
    def center(self):
        return float(self._t[self._center_idx])

    @property
    def sigma(self):
        if self._pulse_len is not None:
            return self._pulse_len / (8.0 * self._clk_frequency)
        m = self._mag
        half = np.max(m) / 2
        above = np.where(m > half)[0]
        if len(above) >= 2:
            fwhm = self._t[above[-1]] - self._t[above[0]]
            return max(fwhm / 2.355, 1e-30)
        return (self._t[-1] - self._t[0]) / 8.0

    @property
    def freq(self):
        return self.i.freq

    @property
    def phase(self):
        return float(np.arctan2(
            self.i.values[self._center_idx] - self.i.offset,
            self.q.values[self._center_idx] - self.q.offset
        ))

    @property
    def phase_deg(self):
        return np.degrees(self.phase)

    @property
    def beta(self):
        tau = (self._t - self.center) / self.sigma
        g = self.amp * np.exp(-0.5 * tau ** 2)
        theta = 2 * np.pi * self.freq * (self._t - self.center) + self.phase
        d = tau * g
        denom = d * np.sin(theta)
        mask = np.abs(denom) > self.amp * 0.01
        if np.any(mask):
            q_res = self.q.values - g * np.cos(theta) - self.q.offset
            return float(np.median(q_res[mask] / denom[mask]))
        return 0.0

    def __str__(self):
        lines = [
            "IQ Parameters (estimated)",
            "",
            f"I amplitude         {self.i.amplitude:>13.3f}",
            f"Q amplitude         {self.q.amplitude:>13.3f}",
            f"Envelope amplitude  {self.amp:>13.3f}",
            f"Envelope center     {self.center * 1e6:>13.3f} us",
            f"Envelope sigma      {self.sigma * 1e6:>13.3f} us",
            f"Frequency           {self.freq:>13.6f} Hz",
            f"Phase               {self.phase_deg:>13.3f} deg",
            f"DRAG coeff (beta)   {self.beta:>13.6f}",
            f"DC offset (I)       {self.off_i:>13.3f}",
            f"DC offset (Q)       {self.off_q:>13.3f}",
        ]
        return "\n".join(lines)

    def plot(self, path):
        t_us = self._t * 1e6
        fig, (ax_i, ax_q) = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
        ax_i.step(t_us, self.i.values, linewidth=0.5, where="post",
                  color="#1f77b4", label="Samples")
        ax_i.set_ylabel("Amplitude")
        ax_i.set_title("Channel I")
        ax_i.legend()
        ax_i.grid(True, alpha=0.3)
        ax_q.step(t_us, self.q.values, linewidth=0.5, where="post",
                  color="#2ca02c", label="Samples")
        ax_q.set_xlabel("Time (µs)")
        ax_q.set_ylabel("Amplitude")
        ax_q.set_title("Channel Q")
        ax_q.legend()
        ax_q.grid(True, alpha=0.3)
        fig.suptitle(f"IQ Samples ({self.freq:.3f} Hz)")
        fig.tight_layout()
        fig.savefig(path, dpi=150)
        plt.close(fig)
