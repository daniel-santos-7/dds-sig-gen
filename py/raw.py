import numpy as np
from scipy.signal import hilbert, periodogram
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

class Channel:
    def __init__(self, values, clk_frequency):
        self._values = values.astype(np.float64)
        self._clk_frequency = clk_frequency
        n = len(values)
        self._t = np.arange(n) / clk_frequency

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
        ac = self._values - np.mean(self._values)
        freqs, power = periodogram(ac, fs=self._clk_frequency, window="hann")
        return float(freqs[np.argmax(power)])

    @property
    def sigma(self):
        ac = np.abs(self._values - np.mean(self._values))
        half = np.max(ac) / 2
        above = np.where(ac > half)[0]
        if len(above) >= 2:
            fwhm = self._t[above[-1]] - self._t[above[0]]
            return max(fwhm / 2.355, 1e-30)
        return (self._t[-1] - self._t[0]) / 8.0

    @property
    def phase(self):
        analytic = hilbert(self._values - np.mean(self._values))
        return float(np.angle(analytic[np.argmax(np.abs(analytic))]))

    @property
    def phase_deg(self):
        return np.degrees(self.phase)

    @property
    def pulse_duration(self):
        return 8.0 * self.sigma

    @property
    def beta(self):
        center = int(np.argmax(np.abs(self._values - np.mean(self._values))))
        t0 = self._t[center]
        amp = self.amplitude
        tau = (self._t - t0) / self.sigma
        g = amp * np.exp(-0.5 * tau ** 2)
        theta = 2 * np.pi * self.freq * (self._t - t0)
        d = tau * g
        denom = d * np.cos(theta)
        mask = np.abs(denom) > amp * 0.01
        if np.any(mask):
            res = self._values - g * np.sin(theta) - np.mean(self._values)
            return float(np.median(-res[mask] / denom[mask]))
        return 0.0

    def __str__(self):
        return (
            f"Offset:        {self.offset:>13.3f}\n"
            f"Amplitude:     {self.amplitude:>13.3f}\n"
            f"Frequency:     {self.freq:>13.6f} Hz\n"
            f"Sigma:         {self.sigma * 1e6:>13.3f} us\n"
            f"Pulse dur.:    {self.pulse_duration * 1e6:>13.3f} us\n"
            f"Phase:         {self.phase_deg:>13.3f} deg\n"
            f"DRAG beta:     {self.beta:>13.6f}"
        )


class Raw:
    
    def __init__(self, i_values, q_values, clk_frequency):
        self.i = Channel(i_values, clk_frequency)
        self.q = Channel(q_values, clk_frequency)

    def __str__(self):
        mag = np.sqrt(self.i.values ** 2 + self.q.values ** 2)
        env_amp = float(np.max(mag) - np.min(mag))
        env_center = float(self.i._t[np.argmax(mag)])

        return (
            f"Channel I:\n{self.i}\n\n"
            f"Channel Q:\n{self.q}\n\n"
            f"Envelope amplitude  {env_amp:>13.3f}\n"
            f"Envelope center     {env_center * 1e6:>13.3f} us\n"
            f"Envelope duration   {self.i.pulse_duration * 1e6:>13.3f} us"
        )

    def plot(self, output_dir):
        import os
        os.makedirs(output_dir, exist_ok=True)
        t_us = self.i._t * 1e6
        fig, (ax_i, ax_q) = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
        ax_i.step(t_us, self.i.values, linewidth=0.5, where="post", color="#1f77b4", label="Samples")
        ax_i.set_ylabel("Amplitude")
        ax_i.set_title("Channel I")
        ax_i.legend()
        ax_i.grid(True, alpha=0.3)
        ax_q.step(t_us, self.q.values, linewidth=0.5, where="post", color="#2ca02c", label="Samples")
        ax_q.set_xlabel("Time (µs)")
        ax_q.set_ylabel("Amplitude")
        ax_q.set_title("Channel Q")
        ax_q.legend()
        ax_q.grid(True, alpha=0.3)
        fig.suptitle(f"IQ Samples ({self.i.freq:.3f} Hz)")
        fig.tight_layout()
        fig.savefig(os.path.join(output_dir, "raw_compare.png"), dpi=150)
        plt.close(fig)