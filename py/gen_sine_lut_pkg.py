#!/usr/bin/python3

from typing import List
import math


def gen_sine_values(samples: int, amplitude: int, initial_phase: int, final_phase: int) -> List[float]:
    delta = (final_phase - initial_phase) / 180 * math.pi
    omega = delta / samples
    phi = initial_phase / 180 * math.pi
    return [amplitude * math.sin(omega*n + phi) for n in range(0, samples)]


def int_to_vhdl_hex_str(integer: int, bits: int) -> str:
    value = (2 ** bits + integer) if integer < 0 else integer
    hex_digits = math.ceil(bits / 4)
    return f'x"{value:0{hex_digits}x}"'


def gen_vhdl_sine_lut(sine_values: List[float], bits: int) -> str:
    values = [int_to_vhdl_hex_str(integer, bits) for integer in map(int, sine_values)]
    lut = ',\n\t\t'.join(values)
    return f'(\n\t\t{lut}\n\t)'


PACKAGE_TEMPLATE = '''library IEEE;
use IEEE.std_logic_1164.all;

package sine_lut_pkg is
    
    constant LUT_ADDR_BITS : natural := {lut_addr_bits};

    constant OUT_RES_BITS  : natural := {out_res_bits};

    type sine_lut_array is array (0 to 2 ** LUT_ADDR_BITS-1) of std_logic_vector(OUT_RES_BITS-1 downto 0);

    constant SINE_TABLE : sine_lut_array := {lut_values};

end package sine_lut_pkg;'''


def generate_pkg(lut_addr_bits=10, out_res_bits=12, initial_phase=0, final_phase=90):
    samples = 2 ** lut_addr_bits
    amplitude = 2 ** (out_res_bits - 1) - 1
    sine_values = gen_sine_values(samples, amplitude, initial_phase, final_phase)
    lut_values = gen_vhdl_sine_lut(sine_values, out_res_bits)
    return PACKAGE_TEMPLATE.format(lut_addr_bits=lut_addr_bits, out_res_bits=out_res_bits, lut_values=lut_values)
