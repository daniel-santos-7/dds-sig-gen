import numpy as np

class SpectralMetrics:
    def __init__(self, spectrum):
        self._s = spectrum

    @property
    def thd_db(self):
        p_fund = self._s.fundamental_power
        p_harm = self._s.harmonic_power
        return 10 * np.log10(p_harm / p_fund) if p_fund > 0 else -float('inf')

    @property
    def sfdr_db(self):
        return 10 * np.log10(self._s.fundamental_power / self._s.spur_power)

    @property
    def snr_db(self):
        return 10 * np.log10(self._s.fundamental_power / self._s.noise_power)

    @property
    def sinad_db(self):
        p_fund = self._s.fundamental_power
        p_dist = self._s.total_power - p_fund
        return 10 * np.log10(p_fund / p_dist) if p_dist > 0 else float('inf')

    @property
    def enob(self):
        return (self.sinad_db - 1.76) / 6.02

    def report(self):
        print("Metrics")
        print(f"  THD           {self.thd_db:>13.2f} dB")
        print(f"  SFDR          {self.sfdr_db:>13.2f} dB")
        print(f"  SNR           {self.snr_db:>13.2f} dB")
        print(f"  SINAD         {self.sinad_db:>13.2f} dB")
        print(f"  ENOB          {self.enob:>13.2f} bits")
