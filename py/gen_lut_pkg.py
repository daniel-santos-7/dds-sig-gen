#!/usr/bin/env python3

import math


def _int_to_vhdl_hex_str(integer: int, bits: int) -> str:
    value = (2 ** bits + integer) if integer < 0 else integer
    hex_digits = math.ceil(bits / 4)
    return f'x"{value:0{hex_digits}x}"'


def generate_pkg(lut_type, lut_addr_bits=10, out_res_bits=12, initial_phase=0, final_phase=90):
    if lut_type == "sine":
        return generate_sine_pkg(lut_addr_bits, out_res_bits, initial_phase, final_phase)
    return generate_env_pkg(lut_addr_bits, out_res_bits)


def generate_sine_pkg(lut_addr_bits=10, out_res_bits=12, initial_phase=0, final_phase=90):
    samples = 2 ** lut_addr_bits
    amplitude = 2 ** (out_res_bits - 1) - 1
    delta = (final_phase - initial_phase) / 180 * math.pi
    omega = delta / samples
    phi = initial_phase / 180 * math.pi
    sine_values = [amplitude * math.sin(omega * n + phi) for n in range(samples)]
    hex_values = [_int_to_vhdl_hex_str(int(v), out_res_bits) for v in sine_values]
    lut = ',\n\t\t'.join(hex_values)

    return f'''library IEEE;
use IEEE.std_logic_1164.all;

package sine_lut_pkg is

    constant LUT_ADDR_BITS : natural := {lut_addr_bits};

    constant OUT_RES_BITS  : natural := {out_res_bits};

    type sine_lut_array is array (0 to 2 ** LUT_ADDR_BITS-1) of std_logic_vector(OUT_RES_BITS-1 downto 0);

    constant SINE_TABLE : sine_lut_array := (
\t\t{lut}
\t);

end package sine_lut_pkg;'''


def generate_env_pkg(lut_addr_bits=10, out_res_bits=16):
    samples = 2 ** lut_addr_bits
    half_samples = samples // 2
    amplitude = 2 ** (out_res_bits - 1) - 1
    sigma_range = 4.0

    gauss_values = []
    drag_values = []

    for i in range(half_samples):
        t = (i / (samples - 1)) * 2 * sigma_range - sigma_range
        gauss = math.exp(-0.5 * (t ** 2))
        drag = -t * math.exp(-0.5 * (t ** 2))
        g_val = int(round(gauss * amplitude))
        d_val = int(round(drag * amplitude / 0.6065306597))
        g_val = max(0, min(amplitude, g_val))
        d_val = max(-amplitude, min(amplitude, d_val))
        gauss_values.append(_int_to_vhdl_hex_str(g_val, out_res_bits))
        drag_values.append(_int_to_vhdl_hex_str(d_val, out_res_bits))

    gauss_lut = ',\n\t\t'.join(gauss_values)
    drag_lut = ',\n\t\t'.join(drag_values)

    return f'''library IEEE;
use IEEE.std_logic_1164.all;

package envelope_lut_pkg is

    constant ENV_LUT_ADDR_BITS : natural := {lut_addr_bits};
    constant ENV_OUT_RES_BITS  : natural := {out_res_bits};

    type env_lut_array is array (0 to 2 ** (ENV_LUT_ADDR_BITS-1) - 1) of std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);

    constant GAUSS_TABLE : env_lut_array := (
\t\t{gauss_lut}
\t);

    constant DRAG_TABLE : env_lut_array := (
\t\t{drag_lut}
\t);

end package envelope_lut_pkg;'''
