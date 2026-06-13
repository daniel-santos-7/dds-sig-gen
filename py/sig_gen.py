#!/usr/bin/env python3
import argparse
import sys


def main():
    parser = argparse.ArgumentParser(description="DDS Signal Generator tools")
    subparsers = parser.add_subparsers(dest="command", required=True)

    ap = subparsers.add_parser("analyze", help="run spectral analysis on samples")
    ap.add_argument("--data", required=True)
    ap.add_argument("--clk", type=float, required=True)
    ap.add_argument("--output", required=True)

    pp = subparsers.add_parser("plot", help="generate analysis report and plots")
    pp.add_argument("--data", required=True)
    pp.add_argument("--clk", type=float, required=True)
    pp.add_argument("--dir", required=True)

    vp = subparsers.add_parser("verify", help="verify pulse envelope quality")
    vp.add_argument("--data", required=True)
    vp.add_argument("--amp", type=int, default=65535)
    vp.add_argument("--pulse", type=int, default=200)
    vp.add_argument("--bits", type=int, default=12)

    gs = subparsers.add_parser("gen-sine-lut", help="generate sine LUT VHDL package")
    gs.add_argument("lut_addr_bits", type=int, nargs="?", default=10)
    gs.add_argument("out_res_bits", type=int, nargs="?", default=12)
    gs.add_argument("initial_phase", type=int, nargs="?", default=0)
    gs.add_argument("final_phase", type=int, nargs="?", default=90)

    ge = subparsers.add_parser("gen-env-lut", help="generate envelope LUT VHDL package")
    ge.add_argument("lut_addr_bits", type=int, nargs="?", default=10)
    ge.add_argument("out_res_bits", type=int, nargs="?", default=16)

    args = parser.parse_args()

    if args.command == "analyze":
        import numpy as np
        from sig_gen_report import write_report
        values = np.loadtxt(args.data, delimiter=",")
        if values.ndim > 1:
            write_report(args.output, values[:, 0], args.clk)
        else:
            write_report(args.output, values, args.clk)

    elif args.command == "plot":
        import numpy as np
        from sig_gen_report import generate_plots
        values = np.loadtxt(args.data, delimiter=",")
        generate_plots(args.dir, values, args.clk)

    elif args.command == "verify":
        from verify_pulse import verify
        ok = verify(args.data, args.amp, args.pulse, args.bits)
        sys.exit(0 if ok else 1)

    elif args.command == "gen-sine-lut":
        from gen_sine_lut_pkg import generate_pkg
        print(generate_pkg(args.lut_addr_bits, args.out_res_bits, args.initial_phase, args.final_phase))

    elif args.command == "gen-env-lut":
        from gen_envelope_lut_pkg import generate_pkg
        print(generate_pkg(args.lut_addr_bits, args.out_res_bits))


if __name__ == "__main__":
    main()
