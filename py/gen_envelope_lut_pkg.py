#!/usr/bin/env python3

import math
import sys

def int_to_vhdl_hex_str(integer: int, bits: int) -> str:
    value = (2 ** bits + integer) if integer < 0 else integer
    hex_digits = math.ceil(bits / 4)
    return f'x"{value:0{hex_digits}x}"'

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <lut_addr_bits> <out_res_bits>")
        sys.exit(1)

    lut_addr_bits = int(sys.argv[1])
    out_res_bits = int(sys.argv[2])
    
    samples = 2 ** lut_addr_bits
    amplitude = 2 ** (out_res_bits - 1) - 1
    
    # Range from -4 sigma to +4 sigma
    sigma_range = 4.0
    
    gauss_values = []
    drag_values = []
    
    for i in range(samples):
        # Normalize i to [-sigma_range, sigma_range]
        t = (i / (samples - 1)) * 2 * sigma_range - sigma_range
        
        # Gaussian envelope
        gauss = math.exp(-0.5 * (t ** 2))
        
        # DRAG derivative (proportional to derivative of Gaussian: -t * exp(-t^2/2))
        # We store just t * exp(-t^2/2), scaled to max amplitude.
        # Max of t * exp(-t^2/2) occurs at t = 1, where value is exp(-0.5) ~ 0.6065
        drag = t * math.exp(-0.5 * (t ** 2))
        
        # Scale to integer
        g_val = int(round(gauss * amplitude))
        d_val = int(round(drag * amplitude / 0.6065306597)) # normalize so max is amplitude
        
        # Clamp just in case
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

    type env_lut_array is array (0 to 2 ** ENV_LUT_ADDR_BITS-1) of std_logic_vector(ENV_OUT_RES_BITS-1 downto 0);

    constant GAUSS_TABLE : env_lut_array := (
\t\t{gauss_lut_str}
\t);

    constant DRAG_TABLE : env_lut_array := (
\t\t{drag_lut_str}
\t);

end package envelope_lut_pkg;
"""
    print(package)

if __name__ == '__main__':
    main()
