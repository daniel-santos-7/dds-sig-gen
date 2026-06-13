import numpy as np
from scipy.optimize import curve_fit
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from sig_gen_param import SigGenParam


def _i_model(t, A, sigma, t0, freq, phase, beta, offset):
    tau = (t - t0) / sigma
    g = A * np.exp(-0.5 * tau ** 2)
    d = tau * g
    omega_t = 2 * np.pi * freq * (t - t0) + phase
    return g * np.sin(omega_t) - beta * d * np.cos(omega_t) + offset


def _q_model(t, A, sigma, t0, freq, phase, beta, offset):
    tau = (t - t0) / sigma
    g = A * np.exp(-0.5 * tau ** 2)
    d = tau * g
    omega_t = 2 * np.pi * freq * (t - t0) + phase
    return g * np.cos(omega_t) + beta * d * np.sin(omega_t) + offset


class Channel:
    def __init__(self, values, t, model_func, p0, label):
        self._label = label
        self._model_func = model_func
        self._t = t
        self._values = values.astype(np.float64)

        try:
            popt, _ = curve_fit(model_func, t, self._values, p0=p0, maxfev=20000)
        except (RuntimeError, ValueError):
            raise RuntimeError(
                f"Channel {label}: fit did not converge "
                f"({len(values)} samples, {len(p0)} parameters). "
                "Try a higher FREQ_HZ or PULSE_LEN."
            )
        self._A, self._sigma, self._t0, self._freq, self._phase, self._beta, self._offset = popt
        self._rms = np.sqrt(np.mean((self._values - self.model_values()) ** 2))

    @property
    def A(self):
        return self._A

    @property
    def sigma(self):
        return self._sigma

    @property
    def t0(self):
        return self._t0

    @property
    def freq(self):
        return self._freq

    @property
    def phase(self):
        return self._phase

    @property
    def beta(self):
        return self._beta

    @property
    def phase_deg(self):
        return np.degrees(self._phase)

    @property
    def offset(self):
        return self._offset

    @property
    def rms(self):
        return self._rms

    def model_values(self):
        return self._model_func(self._t, self._A, self._sigma, self._t0,
                                self._freq, self._phase, self._beta, self._offset)

    def __str__(self):
        return (
            f"Channel {self._label}:\n"
            f"  Amplitude           {self._A:>13.3f}\n"
            f"  Sigma               {self._sigma * 1e6:>13.3f} us\n"
            f"  Center              {self._t0 * 1e6:>13.3f} us\n"
            f"  Frequency           {self._freq:>13.6f} Hz\n"
            f"  Phase               {self.phase_deg:>13.3f} deg\n"
            f"  DRAG coeff (beta)   {self._beta:>13.6f}\n"
            f"  DC offset           {self._offset:>13.3f}\n"
            f"  Fit error (RMS)     {self._rms:>13.3f}"
        )




class IQFit:
    @classmethod
    def from_file(cls, path, clk, freq, pulse_len=None):
        values = np.loadtxt(path, delimiter=",")
        if values.ndim > 1:
            i_values = values[:, 0]
            q_values = values[:, 1]
        else:
            i_values = values
            q_values = np.zeros_like(values)
        return cls(i_values, q_values, clk, freq, pulse_len)

    def __init__(self, i_values, q_values, clk_frequency, freq0, pulse_len=None):
        n = len(i_values)
        if n < 4:
            raise ValueError("not enough samples for analysis")

        window_us = n / clk_frequency * 1e6
        ncycles = window_us * freq0 * 1e-6
        if ncycles < 1.0:
            raise ValueError(
                f"Data window ({window_us:.1f} µs) contains only {ncycles:.2f} cycle(s) "
                f"at {freq0} Hz. Need at least ~1 full cycle for a reliable fit. "
                "Use higher FREQ_HZ or increase CLK_PERIODS."
            )

        self._t = np.arange(n) / clk_frequency
        est = SigGenParam(i_values, q_values, clk_frequency, freq0, pulse_len)

        p0_i = [est.amp, est.sigma, est.center, est.freq, est.phase, est.beta, est.off_i]
        p0_q = [est.amp, est.sigma, est.center, est.freq, est.phase, est.beta, est.off_q]

        self._i = Channel(i_values, self._t, _i_model, p0_i, "I")
        self._q = Channel(q_values, self._t, _q_model, p0_q, "Q")

    @property
    def i(self):
        return self._i

    @property
    def q(self):
        return self._q

    @property
    def jitter(self):
        g = self._i.A * np.exp(-0.5 * ((self._t - self._i.t0) / self._i.sigma) ** 2)
        mask = g > self._i.A * 0.1
        if np.sum(mask) < 4:
            return None
        ac = self._i._values - self._i.offset
        ac_norm = ac / np.maximum(g, 1e-30)
        signs = np.sign(ac_norm)
        rising = np.where(np.diff(signs) > 0)[0]
        if len(rising) < 2:
            return None
        dt = self._t[1] - self._t[0]
        cross_times = [(c + (-ac_norm[c] / (ac_norm[c + 1] - ac_norm[c]))) * dt for c in rising]
        periods = np.diff(cross_times)
        return np.std(periods) * self._i.freq

    def __str__(self):
        lines = ["IQ Fit (Gaussian envelope + DRAG)", "",
                 str(self._i), "", str(self._q), ""]
        j = self.jitter
        if j is not None:
            lines.append(f"Jitter (UI)             {j:>13.2e}")
            lines.append(f"Jitter (s)              {j / self._i.freq:>13.2e}")
        else:
            lines.append("Jitter                  unavailable")
        return "\n".join(lines)

    def plot(self, output_dir):
        import os
        os.makedirs(output_dir, exist_ok=True)
        t_us = self._t * 1e6
        i_fit = self._i.model_values()
        q_fit = self._q.model_values()

        fig, (ax_i, ax_q) = plt.subplots(2, 1, figsize=(12, 8), sharex=True)

        ax_i.step(t_us, self._i._values, linewidth=0.5, where="post",
                  alpha=0.6, color="#1f77b4", label="Samples")
        ax_i.plot(t_us, i_fit, linewidth=1.5, color="#ff7f0e", label="Fit")
        ax_i.set_ylabel("Amplitude")
        ax_i.set_title("Channel I")
        ax_i.legend()
        ax_i.grid(True, alpha=0.3)

        ax_q.step(t_us, self._q._values, linewidth=0.5, where="post",
                  alpha=0.6, color="#2ca02c", label="Samples")
        ax_q.plot(t_us, q_fit, linewidth=1.5, color="#9467bd", label="Fit")
        ax_q.set_xlabel("Time (µs)")
        ax_q.set_ylabel("Amplitude")
        ax_q.set_title("Channel Q")
        ax_q.legend()
        ax_q.grid(True, alpha=0.3)

        fig.suptitle(f"IQ Fit (Gaussian envelope + DRAG, {self._i.freq:.3f} Hz)")
        fig.tight_layout()
        fig.savefig(os.path.join(output_dir, "fit_compare.png"), dpi=150)
        plt.close(fig)
