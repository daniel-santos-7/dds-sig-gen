import numpy as np
from scipy.signal import periodogram

class Spectrum:
    def __init__(self, values, clk_frequency):
        n = len(values)
        if n < 4:
            raise ValueError("not enough samples for analysis")

        ac = values - np.mean(values)
        self._freqs, self._power = periodogram(ac, fs=clk_frequency, window='hann')

        freq0 = self._freq_guess()
        if freq0 is None:
            raise ValueError("could not determine initial frequency")

        self._fund_freq = freq0
        self._fund_bins = self._bins_around(freq0, 1)
        self._harm_bins = self._compute_harm_bins()

    def _bins_around(self, target_freq, half_width):
        center = np.argmin(np.abs(self._freqs - target_freq))
        return set(range(max(0, center - half_width), min(len(self._freqs), center + half_width + 1)))

    def _freq_guess(self):
        peak = np.argmax(self._power)
        return None if peak == 0 else self._freqs[peak]

    def _compute_harm_bins(self):
        harm_bins = set()
        for h in range(2, 6):
            hf = self._fund_freq * h
            if hf >= self._freqs[-1] * 2:
                break
            harm_bins |= self._bins_around(hf, 1)
        return (harm_bins - {0}) - self._fund_bins

    @property
    def fund_freq(self):
        return self._fund_freq

    @fund_freq.setter
    def fund_freq(self, value):
        self._fund_freq = value
        self._fund_bins = self._bins_around(value, 1)
        self._harm_bins = self._compute_harm_bins()

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

    def report(self):
        print("Spectrum")
        print(f"  Fundamental   {self.fundamental_power:>13.4e}")
        print(f"  Harmonic      {self.harmonic_power:>13.4e}")
        print(f"  Spur          {self.spur_power:>13.4e}")
        print(f"  Noise         {self.noise_power:>13.4e}")
        print(f"  Total         {self.total_power:>13.4e}")
