# VGA Jupiter Renderer

Renders an animated sphere with color band patterns on VGA using either logarithmic shading or CORDIC-based wave generation. Outputs 640x480 at 60Hz with rotating color bands and a twinkling starfield. The exp/log version does smooth radial gradients, the CORDIC version adds sine-wave surface modulation. Both run on 100MHz input clock with internal pixel clock division. Tested on Nexys 3 (Spartan-6).

## Two Implementations

### Exp/Log Version
Uses logarithmic and exponential approximations for smooth radial shading. Creates a gradient from the planet's edge to center, preventing the "black hole" effect you'd get with simpler distance-based shading.

**Files:**
- `top.v` - Main design
- `testbench.v` - Simulation harness

### CORDIC Version
Uses the CORDIC algorithm to generate sine waves that modulate the color bands. This creates actual wave patterns across the surface rather than just rotation.

**Files:**
- `top_cordic.v` - Main design  
- `stimulus.v` - CORDIC unit test

## Running It

Both versions target 100MHz input clock and generate a 25MHz pixel clock internally through clock division.

**Inputs:**
- `clk100` - 100MHz system clock
- `rst` - Active high reset
- `sw[7:0]` - Color channel masks (useful for debugging)

**Outputs:**
- `vga_red[2:0]`, `vga_green[2:0]`, `vga_blue[1:0]` - 8-bit color
- `vga_hs`, `vga_vs` - Sync signals

Synthesize for your FPGA, hook up a VGA monitor, watch Jupiter spin.

## Technical Notes

- Fixed-point math throughout (Q16.16 for exp/log, Q1.15 for CORDIC)
- Sphere radius hardcoded at 120 pixels, centered at (320, 240)
- Starfield uses pseudo-random hash based on pixel coordinates
- Color bands defined in 4-bit lookup table, 7 distinct color zones
- Animation counter increments once per frame

The exp/log version trades LUT usage for smoother shading. The CORDIC version uses iterative rotation for wave generation, which costs more logic but creates more interesting surface patterns.

## Simulation

Run the testbenches in your Verilog simulator of choice. The VGA testbench runs for 10ms of simulated time (about 1.5 frames). Tested on Nexys 3 (Spartan-6 FPGA). Should be portable to other FPGAs with sufficient resources.
