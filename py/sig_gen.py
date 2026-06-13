#!/usr/bin/env python3
import argparse
import sys


def main():
    parser = argparse.ArgumentParser(description="DDS Signal Generator tools")
    subparsers = parser.add_subparsers(dest="command", required=True)

    fp = subparsers.add_parser("fit", help="fit sine wave with Gaussian envelope to I/Q samples")
    fp.add_argument("--data", required=True)
    fp.add_argument("--clk", type=float, required=True)
    fp.add_argument("--freq", type=float, required=True)
    fp.add_argument("--pulse-len", type=int, default=None, help="pulse length in clock cycles (optional, sigma estimate)")
    fp.add_argument("--output", default=None)
    fp.add_argument("--plot", default=None)

    pp = subparsers.add_parser("params", help="estimate I/Q parameters from samples")
    pp.add_argument("--data", required=True)
    pp.add_argument("--clk", type=float, required=True)
    pp.add_argument("--freq", type=float, default=None, help="expected frequency (optional, FFT if omitted)")
    pp.add_argument("--pulse-len", type=int, default=None, help="pulse length in clock cycles (optional, sigma estimate)")
    pp.add_argument("--output", default=None)
    pp.add_argument("--plot", default=None)

    sp = subparsers.add_parser("spectrum", help="compute spectrum and spectral metrics")
    sp.add_argument("--data", required=True)
    sp.add_argument("--clk", type=float, required=True)
    sp.add_argument("--output", default=None)
    sp.add_argument("--plot", default=None)

    gs = subparsers.add_parser("gen-sine-lut", help="generate sine LUT VHDL package")
    gs.add_argument("lut_addr_bits", type=int, nargs="?", default=10)
    gs.add_argument("out_res_bits", type=int, nargs="?", default=12)
    gs.add_argument("initial_phase", type=int, nargs="?", default=0)
    gs.add_argument("final_phase", type=int, nargs="?", default=90)

    ge = subparsers.add_parser("gen-env-lut", help="generate envelope LUT VHDL package")
    ge.add_argument("lut_addr_bits", type=int, nargs="?", default=10)
    ge.add_argument("out_res_bits", type=int, nargs="?", default=16)

    args = parser.parse_args()

    if args.command == "fit":
        import numpy as np
        from sine_fit import IQFit
        values = np.loadtxt(args.data, delimiter=",")
        if values.ndim > 1:
            i_values = values[:, 0]
            q_values = values[:, 1]
        else:
            i_values = values
            q_values = np.zeros_like(values)
        fit = IQFit(i_values, q_values, args.clk, args.freq, args.pulse_len)
        if args.output:
            with open(args.output, "w") as f:
                f.write(str(fit))
                f.write("\n")
        else:
            print(fit)
        if args.plot:
            import os
            os.makedirs(args.plot, exist_ok=True)
            fit.plot(os.path.join(args.plot, "fit_compare.png"))

    elif args.command == "params":
        import numpy as np
        from sig_gen_param import SigGenParam
        values = np.loadtxt(args.data, delimiter=",")
        if values.ndim > 1:
            i_values = values[:, 0]
            q_values = values[:, 1]
        else:
            i_values = values
            q_values = np.zeros_like(values)
        param = SigGenParam(i_values, q_values, args.clk, args.freq, args.pulse_len)
        if args.output:
            with open(args.output, "w") as f:
                f.write(str(param))
                f.write("\n")
        else:
            print(param)
        if args.plot:
            import os
            os.makedirs(args.plot, exist_ok=True)
            param.plot(os.path.join(args.plot, "params_compare.png"))

    elif args.command == "spectrum":
        import numpy as np
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        from spectrum import Spectrum
        from spectral_metrics import SpectralMetrics
        values = np.loadtxt(args.data, delimiter=",")
        if values.ndim > 1:
            i_sig = values[:, 0]
            q_sig = values[:, 1]
        else:
            i_sig = values
            q_sig = np.zeros_like(values)
        spec_i = Spectrum(i_sig, args.clk)
        spec_q = Spectrum(q_sig, args.clk)
        met_i = SpectralMetrics(spec_i)
        met_q = SpectralMetrics(spec_q)
        freq_mhz_i = spec_i.fund_freq / 1e6
        freq_mhz_q = spec_q.fund_freq / 1e6

        lines = [
            "Spectrum",
            "",
            "  Channel I:",
            f"    Fundamental   {spec_i.fundamental_power:>13.4e}  ({freq_mhz_i:.3f} MHz)",
            f"    Harmonic      {spec_i.harmonic_power:>13.4e}",
            f"    Spur          {spec_i.spur_power:>13.4e}",
            f"    Noise         {spec_i.noise_power:>13.4e}",
            f"    Total         {spec_i.total_power:>13.4e}",
            f"    THD           {met_i.thd_db:>13.2f} dB",
            f"    SFDR          {met_i.sfdr_db:>13.2f} dB",
            f"    SNR           {met_i.snr_db:>13.2f} dB",
            f"    SINAD         {met_i.sinad_db:>13.2f} dB",
            f"    ENOB          {met_i.enob:>13.2f} bits",
            "",
            "  Channel Q:",
            f"    Fundamental   {spec_q.fundamental_power:>13.4e}  ({freq_mhz_q:.3f} MHz)",
            f"    Harmonic      {spec_q.harmonic_power:>13.4e}",
            f"    Spur          {spec_q.spur_power:>13.4e}",
            f"    Noise         {spec_q.noise_power:>13.4e}",
            f"    Total         {spec_q.total_power:>13.4e}",
            f"    THD           {met_q.thd_db:>13.2f} dB",
            f"    SFDR          {met_q.sfdr_db:>13.2f} dB",
            f"    SNR           {met_q.snr_db:>13.2f} dB",
            f"    SINAD         {met_q.sinad_db:>13.2f} dB",
            f"    ENOB          {met_q.enob:>13.2f} bits",
        ]
        report = "\n".join(lines)
        if args.output:
            with open(args.output, "w") as f:
                f.write(report)
                f.write("\n")
        else:
            print(report)
        if args.plot:
            import os
            os.makedirs(args.plot, exist_ok=True)
            fig, (ax_i, ax_q) = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
            ax_i.plot(spec_i._freqs / 1e6, 10 * np.log10(spec_i._power + 1e-30),
                      linewidth=0.8, color="#1f77b4")
            ax_i.set_ylabel("Power (dB)")
            ax_i.set_title("Spectrum — Channel I")
            ax_i.grid(True, alpha=0.3)
            ax_q.plot(spec_q._freqs / 1e6, 10 * np.log10(spec_q._power + 1e-30),
                      linewidth=0.8, color="#2ca02c")
            ax_q.set_xlabel("Frequency (MHz)")
            ax_q.set_ylabel("Power (dB)")
            ax_q.set_title("Spectrum — Channel Q")
            ax_q.grid(True, alpha=0.3)
            fig.tight_layout()
            fig.savefig(os.path.join(args.plot, "spectrum.png"), dpi=150)
            plt.close(fig)

    elif args.command == "gen-sine-lut":
        from gen_sine_lut_pkg import generate_pkg
        print(generate_pkg(args.lut_addr_bits, args.out_res_bits, args.initial_phase, args.final_phase))

    elif args.command == "gen-env-lut":
        from gen_envelope_lut_pkg import generate_pkg
        print(generate_pkg(args.lut_addr_bits, args.out_res_bits))


if __name__ == "__main__":
    main()
