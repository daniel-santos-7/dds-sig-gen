#!/usr/bin/env python3

import math


def int_to_vhdl_hex_str(integer: int, bits: int) -> str:
    value = (2 ** bits + integer) if integer < 0 else integer
    hex_digits = math.ceil(bits / 4)
    return f'x"{value:0{hex_digits}x}"'


def generate_pkg(lut_addr_bits=10, out_res_bits=16):
    samples = 2 ** lut_addr_bits
    half_samples = samples // 2
    amplitude = 2 ** (out_res_bits - 1) - 1

    sigma_range = 4.0

    gauss_values = []
    drag_values = []

    for i in range(half_samples):
        t = (i / (samples - 1)) * 2 * sigma_range - sigma_range

        gauss = math.exp(-0.5 * (t ** 2))

        drag = t * math.exp(-0.5 * (t ** 2))

        g_val = int(round(gauss * amplitude))
        d_val = int(round(drag * amplitude / 0.6065306597))

        g_val = max(0, min(amplitude, g_val))
        d_val = max(-amplitude, min(amplitude, d_val))

        gauss_values.append(int_to_vhdl_hex_str(g_val, out_res_bits))
        drag_values.append(int_to_vhdl_hex_str(d_val, out_res_bits))

    gauss_lut_str = ',\n\t\t'.join(gauss_values)
    drag_lut_str = ',\n\t\t'.join(drag_values)

    package = f"""library IEEE;
use IEEE.std_logic_1164.all;

package envelope_lut_pkg is
    
    constant ENV_LUT_ADDR_BITS : natural := {lut_addr_bits};
    constant ENV_OUT_RES_BITS  : natural := {out_res_bits};

    type env_lut_array is array (0 to 2 ** (ENV_LUT_ADDR_BITS-1) - 1) of std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);

    constant GAUSS_TABLE : env_lut_array := (
\t\t{gauss_lut_str}
\t);

    constant DRAG_TABLE : env_lut_array := (
\t\t{drag_lut_str}
\t);

end package envelope_lut_pkg;
"""
    return package
