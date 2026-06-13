#!/usr/bin/env python3
import argparse
import sys

from gen_lut_pkg import generate_pkg

def load_iq_data(path):
    import numpy as np
    values = np.loadtxt(path, delimiter=",")
    if values.ndim > 1:
        return values[:, 0], values[:, 1]
    return values, np.zeros_like(values)


def create_parser():
    parser = argparse.ArgumentParser(description="DDS Signal Generator tools")
    subparsers = parser.add_subparsers(dest="command", required=True)

    pp = subparsers.add_parser("raw", help="estimate raw I/Q parameters from samples")
    pp.add_argument("--data", required=True)
    pp.add_argument("--clk", type=float, required=True)
    pp.add_argument("--output", default=None)
    pp.add_argument("--plot", default=None)

    fp = subparsers.add_parser("fit", help="fit sine wave with Gaussian envelope to I/Q samples")
    fp.add_argument("--data", required=True)
    fp.add_argument("--clk", type=float, required=True)
    fp.add_argument("--output", default=None)
    fp.add_argument("--plot", default=None)

    sp = subparsers.add_parser("spectrum", help="compute spectrum and spectral metrics")
    sp.add_argument("--data", required=True)
    sp.add_argument("--clk", type=float, required=True)
    sp.add_argument("--output", default=None)
    sp.add_argument("--plot", default=None)

    gl = subparsers.add_parser("gen-lut", help="generate LUT VHDL package")
    gl.add_argument("--type", required=True, choices=["sine", "env"])
    gl.add_argument("--addr-bits", type=int, default=10)
    gl.add_argument("--res-bits", type=int, default=12)
    gl.add_argument("--init-phase", type=int, default=0)
    gl.add_argument("--final-phase", type=int, default=90)

    return parser.parse_args()

def write_output(text, path=None):
    if path:
        with open(path, "w") as f:
            f.write(text)
            f.write("\n")
    else:
        print(text)

def main(args):
    if args.command in ("raw", "fit", "spectrum"):
        i_values, q_values = load_iq_data(args.data)

    if args.command == "raw":
        from raw import Raw
        param = Raw(i_values, q_values, args.clk)
        write_output(str(param), args.output)
        if args.plot: param.plot(args.plot)
        return
    
    if args.command == "fit":
        from sine_fit import IQFit
        fit = IQFit(i_values, q_values, args.clk)
        write_output(str(fit), args.output)
        if args.plot: fit.plot(args.plot)
        return

    if args.command == "spectrum":
        from spectrum import Spectrum
        spec = Spectrum(i_values, q_values, args.clk)
        write_output(str(spec), args.output)
        if args.plot: spec.plot(args.plot)
        return
        
    if args.command == "gen-lut":
        print(generate_pkg(args.type, args.addr_bits, args.res_bits, args.init_phase, args.final_phase))
        return

if __name__ == "__main__":
    args = create_parser()
    main(args)
