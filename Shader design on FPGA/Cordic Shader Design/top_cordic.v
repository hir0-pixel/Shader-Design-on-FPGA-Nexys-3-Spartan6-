`timescale 1ns/1ps
`default_nettype none

module top_cordic(
    input  wire clk100,     
    input  wire rst,        
    input  wire [7:0] sw,   

    output wire [2:0] vga_red,
    output wire [2:0] vga_green,
    output wire [1:0] vga_blue,
    output wire       vga_hs,
    output wire       vga_vs
);

    // 25 MHz Pixel Clock
    reg [1:0] div4 = 0;
    always @(posedge clk100) div4 <= div4 + 1'b1;
    wire pix_stb = (div4 == 2'b11);

    wire [9:0] o_x; wire [8:0] o_y;
    wire o_active, o_animate, o_hs, o_vs;

    vga640x480 vga_inst (
        .i_clk(clk100), .i_pix_stb(pix_stb), .i_rst(rst),
        .o_hs(o_hs), .o_vs(o_vs), .o_active(o_active),
        .o_animate(o_animate), .o_x(o_x), .o_y(o_y)
    );

    reg [15:0] t = 0;
    always @(posedge clk100) if (o_animate) t <= t + 1'b1;

    // Planet Geometry
    wire signed [10:0] dx = $signed({1'b0, o_x}) - 11'sd320;
    wire signed [10:0] dy = $signed({1'b0, o_y}) - 11'sd240;
    wire [21:0] r2 = (dx*dx) + (dy*dy);
    wire inside = (r2 < 14400); 

    // CORDIC Wave Generation
    wire signed [15:0] wave_angle = (dy << 7) + (t << 7); 
    wire signed [17:0] cos_out, sin_out;

    CORDIC_Merged cordic_unit (
        .bin(wave_angle),
        .cos_theta(cos_out),
        .sin_theta(sin_out)
    );

    // Transition and Shading (Bottom-Right)
    wire signed [17:0] light_mask = (dx + dy + sin_out[17:8]); 
    wire visible_side = (light_mask > 18'sd0);
    wire [15:0] intensity = (visible_side) ? (light_mask[15:0] | 16'h8000) : 16'h0000;
    
    // Wavy Swirl Logic
    wire [7:0] swirl = (dy[8:1] + sin_out[15:8] + t[7:0]); 

    reg [2:0] pr, pg; reg [1:0] pb;
    always @* begin
        if (inside && visible_side) begin
            case (swirl[7:4]) 
                4'h0, 4'h1: {pr, pg, pb} = {3'b111, 3'b111, 2'b00};
                4'h2, 4'h3: {pr, pg, pb} = {3'b111, 3'b011, 2'b01};
                4'h4, 4'h5: {pr, pg, pb} = {3'b101, 3'b101, 2'b11};
                4'h6, 4'h7: {pr, pg, pb} = {3'b011, 3'b111, 2'b11};
                4'h8, 4'h9: {pr, pg, pb} = {3'b111, 3'b010, 2'b00};
                default:    {pr, pg, pb} = {3'b111, 3'b101, 2'b11};
            endcase
        end else {pr, pg, pb} = 0;
    end

    wire [2:0] fr = (pr & {3{intensity[15]}});
    wire [2:0] fg = (pg & {3{intensity[15]}});
    wire [1:0] fb = (pb & {2{intensity[15]}});

    // Starfield Background
    wire [15:0] star_hash = (o_x[9:1] * 10'd41) ^ (o_y[8:1] * 10'd97);
    wire is_star = (!inside) && ((star_hash & 16'h03FF) == 16'h00A) && t[4];

    assign vga_red   = o_active ? ((inside ? fr : {3{is_star}}) & sw[7:5]) : 0;
    assign vga_green = o_active ? ((inside ? fg : {3{is_star}}) & sw[4:2]) : 0;
    assign vga_blue  = o_active ? ((inside ? fb : {2{is_star}}) & sw[1:0]) : 0;
    assign vga_hs = o_hs; assign vga_vs = o_vs;
endmodule

// CORDIC Algorithm Implementation
module CORDIC_Merged
#(
    parameter N    = 16,   
    parameter P1   = 18,   
    parameter ITER = 16    
)
(
    input wire signed [N-1:0]  bin,           
    output reg signed [P1-1:0] cos_theta, 
    output reg signed [P1-1:0] sin_theta  
);
    localparam signed [P1-1:0] K_VAL = 18'sd39797;
    reg signed [N-1:0] atan_table [0:ITER-1];
    reg signed [P1-1:0] x [0:ITER];
    reg signed [P1-1:0] y [0:ITER];
    reg signed [N-1:0]  z [0:ITER];
    integer i;
    
    initial begin
        atan_table[0] = 16'sd25736; atan_table[1] = 16'sd15193;
        atan_table[2] = 16'sd8027;  atan_table[3] = 16'sd4075;
        atan_table[4] = 16'sd2045;  atan_table[5] = 16'sd1024;
        atan_table[6] = 16'sd512;   atan_table[7] = 16'sd256;
        atan_table[8] = 16'sd128;   atan_table[9] = 16'sd64;
        atan_table[10]= 16'sd32;    atan_table[11]= 16'sd16;
        atan_table[12]= 16'sd8;     atan_table[13]= 16'sd4;
        atan_table[14]= 16'sd2;     atan_table[15]= 16'sd1;
    end
    
    always @* begin
        x[0] = K_VAL; y[0] = 18'sd0; z[0] = bin;
        for (i = 0; i < ITER; i = i + 1) begin
            if (z[i][N-1] == 1'b0) begin
                x[i+1] = x[i] - (y[i] >>> i);
                y[i+1] = y[i] + (x[i] >>> i);
                z[i+1] = z[i] - atan_table[i];
            end else begin
                x[i+1] = x[i] + (y[i] >>> i);
                y[i+1] = y[i] - (x[i] >>> i);
                z[i+1] = z[i] + atan_table[i];
            end
        end
        cos_theta = x[ITER]; sin_theta = y[ITER];
    end
endmodule

// VGA 640x480 Timing Generator
module vga640x480(
    input wire i_clk, i_pix_stb, i_rst,
    output wire o_hs, o_vs, o_active, o_animate,
    output wire [9:0] o_x, output wire [8:0] o_y
);
    reg [9:0] h = 0, v = 0;
    assign o_hs = ~(h >= 656 && h < 752);
    assign o_vs = ~(v >= 490 && v < 492);
    assign o_active = (h < 640 && v < 480);
    assign o_x = h; assign o_y = v[8:0];
    assign o_animate = (v == 480 && h == 0);
    
    always @(posedge i_clk) if (i_pix_stb) begin
        if (h == 799) begin h <= 0; v <= (v == 524) ? 0 : v + 1; end
        else h <= h + 1;
    end
endmodule

`default_nettype wire