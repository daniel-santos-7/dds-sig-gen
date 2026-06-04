import numpy as np
from scipy.optimize import curve_fit

class SineFit:
    @staticmethod
    def _sine_model(t, amp, freq, phase, offset):
        return amp * np.sin(2 * np.pi * freq * t + phase) + offset
    def __init__(self, values, clk_frequency, freq0):
        n = len(values)
        if n < 4:
            raise ValueError("not enough samples for analysis")

        t = np.arange(n) / clk_frequency
        offset0 = np.mean(values)
        amp0 = np.ptp(values) / 2

        try:
            popt, _ = curve_fit(SineFit._sine_model, t, values, p0=[amp0, freq0, 0, offset0], maxfev=5000)
        except (RuntimeError, ValueError):
            raise ValueError("sine fit did not converge")

        self._amp, self._freq, self._phase, self._offset = popt
        self._t = t
        self._values = values

    @property
    def amp(self):
        return self._amp

    @property
    def freq(self):
        return self._freq

    @property
    def phase(self):
        return self._phase

    @property
    def phase_deg(self):
        return np.degrees(self._phase)

    @property
    def offset(self):
        return self._offset

    @property
    def jitter(self):
        ac = self._values - self._offset
        signs = np.sign(ac)
        rising = np.where(np.diff(signs) > 0)[0]
        if len(rising) < 2:
            return None
        dt = self._t[1] - self._t[0]
        cross_times = [(c + (-ac[c] / (ac[c + 1] - ac[c]))) * dt for c in rising]
        periods = np.diff(cross_times)
        return np.std(periods) * self._freq

    def report(self):
        print("Curve Fit")
        print(f"  Amplitude     {self._amp:>13.3f}")
        print(f"  Frequency     {self._freq:>13.6f}")
        print(f"  Phase         {self.phase_deg:>13.3f}")
        print(f"  DC offset     {self._offset:>13.3f}")
        j = self.jitter
        if j is not None:
            print(f"  Jitter (UI)   {j:>13.2e}")
            print(f"  Jitter (s)    {j / self._freq:>13.2e}")
        else:
            print("  Jitter        unavailable")
