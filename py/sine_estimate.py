import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

class SineEstimate:
    def __init__(self, values, clk_frequency):
        n = len(values)
        if n < 4:
            raise ValueError("not enough samples for analysis")
        self._values = values
        self._t = np.arange(n) / clk_frequency

    @property
    def offset(self):
        return np.mean(self._values)

    @property
    def amp(self):
        return np.ptp(self._values) / 2

    @property
    def freq(self):
        ac = self._values - self.offset
        signs = np.sign(ac)
        rising = np.where(np.diff(signs) > 0)[0]
        if len(rising) < 2:
            return 0.0
        dt = self._t[1] - self._t[0]
        cross_times = [(c + (-ac[c] / (ac[c + 1] - ac[c]))) * dt for c in rising]
        period = np.mean(np.diff(cross_times))
        return 1.0 / period if period > 0 else 0.0

    @property
    def phase(self):
        y0 = np.clip((self._values[0] - self.offset) / self.amp, -1, 1)
        p = np.arcsin(y0)
        if len(self._values) > 1:
            dy = self._values[1] - self._values[0]
            if (dy > 0 and np.cos(p) < 0) or (dy < 0 and np.cos(p) > 0):
                p = np.pi - p
        return p

    @property
    def phase_deg(self):
        return np.degrees(self.phase)

    def report(self):
        print("Sine Estimate")
        print(f"  Amplitude     {self.amp:>13.3f}")
        print(f"  Frequency     {self.freq:>13.6f}")
        print(f"  Phase         {self.phase_deg:>13.3f}")
        print(f"  DC offset     {self.offset:>13.3f}")

    def plot(self, path):
        t_us = self._t * 1e6
        n = len(self._values)

        fig, ax = plt.subplots(figsize=(12, 4))
        ax.step(t_us, self._values, linewidth=0.8, where="post")
        ax.set_xlabel("Time (µs)")
        ax.set_ylabel("Amplitude")
        ax.set_title(f"Waveform ({n} samples)")
        ax.grid(True, alpha=0.3)
        fig.tight_layout()
        fig.savefig(path, dpi=150)
        plt.close(fig)
