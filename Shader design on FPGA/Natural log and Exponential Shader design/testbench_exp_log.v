`timescale 1ns/1ps
`default_nettype none

module testbench;

    reg clk100 = 1'b0;
    reg rst    = 1'b1;
    reg [7:0] sw = 8'hFF;

    wire [2:0] vga_red;
    wire [2:0] vga_green;
    wire [1:0] vga_blue;
    wire       vga_hs;
    wire       vga_vs;

    always #5 clk100 = ~clk100;

    top dut(
        .clk100 (clk100),
        .rst    (rst),
        .sw     (sw),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue),
        .vga_hs (vga_hs),
        .vga_vs (vga_vs)
    );

    initial begin
        #200;
        rst = 1'b0;

        #10_000_000;
        $finish;
    end

endmodule

`default_nettype wire