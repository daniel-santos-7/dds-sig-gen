#!/usr/bin/env python3
import argparse
import sys

from gen_lut_pkg import generate_env_pkg, generate_sine_pkg
from sig_gen_param import SigGenParam
from sine_fit import IQFit
from spectrum import Spectrum


def write_output(text, path=None):
    if path:
        with open(path, "w") as f:
            f.write(text)
            f.write("\n")
    else:
        print(text)


def main(args):
    if args.command == "fit":
        fit = IQFit.from_file(args.data, args.clk, args.freq, args.pulse_len)
        write_output(str(fit), args.output)
        if args.plot:
            fit.plot(args.plot)

    elif args.command == "params":
        param = SigGenParam.from_file(args.data, args.clk, args.freq, args.pulse_len)
        write_output(str(param), args.output)
        if args.plot:
            param.plot(args.plot)

    elif args.command == "spectrum":
        spec = Spectrum.from_file(args.data, args.clk)
        write_output(str(spec), args.output)
        if args.plot:
            spec.plot(args.plot)

    elif args.command == "gen-sine-lut":
        print(generate_sine_pkg(args.lut_addr_bits, args.out_res_bits, args.initial_phase, args.final_phase))

    elif args.command == "gen-env-lut":
        print(generate_env_pkg(args.lut_addr_bits, args.out_res_bits))


def create_parser():
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

    return parser.parse_args()


if __name__ == "__main__":
    main(create_parser())
