`timescale 1ns/1ps
`default_nettype none

module top(
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
    always @(posedge clk100) div4 <= div4 + 1;
    wire pix_stb = (div4 == 2'b11);

    // VGA Core
    wire [9:0] o_x; wire [8:0] o_y;
    wire o_active, o_animate, o_hs, o_vs;

    vga640x480 vga_inst (
        .i_clk(clk100), .i_pix_stb(pix_stb), .i_rst(rst),
        .o_hs(o_hs), .o_vs(o_vs), .o_active(o_active),
        .o_animate(o_animate), .o_x(o_x), .o_y(o_y)
    );

    // Animation Counter
    reg [15:0] t = 0;
    always @(posedge clk100) if (o_animate) t <= t + 1;

    // Q16.16 Fixed Point Multiplication
    function signed [31:0] q16_mul;
        input signed [31:0] a, b;
        reg signed [63:0] p;
        begin p = a * b; q16_mul = p >>> 16; end
    endfunction

    // 1.5 / ln(2) for smoother falloff
    localparam signed [31:0] SMOOTH_EXP_FACTOR = 32'sd141823; 

    // Planet Geometry
    wire signed [10:0] cx = 320; 
    wire signed [10:0] cy = 240;
    wire signed [10:0] dx = $signed({1'b0, o_x}) - cx;
    wire signed [10:0] dy = $signed({1'b0, o_y}) - cy;
    
    wire [21:0] r2 = (dx*dx) + (dy*dy);
    wire inside = (r2 < 14400); // Radius 120

    // Smooth Log/Exp Shading: d = 1.0 - (r^2 / R^2)
    wire signed [31:0] d_raw = 32'sh0001_0000 - q16_mul({10'd0, r2}, 32'sh0000_0127);
    // Clamp d_safe: 0.0001 to 0.9999 to keep log/exp stable
    wire signed [31:0] d_safe = (d_raw >= 32'sh0001_0000) ? 32'sh0000_FFFF : 
                                (d_raw <= 32'sh0000_0001) ? 32'sh0000_0005 : d_raw;

    wire signed [31:0] ln_d, exp_out;
    log_fast u_log(.x(d_safe), .y(ln_d));
    exp2_fast u_exp(.x(q16_mul(ln_d, SMOOTH_EXP_FACTOR)), .y(exp_out));

    // Blend intensity: center at least 80% bright to remove black hole
    wire [15:0] intensity = inside ? (exp_out[15:0] | 16'hC000) : 16'd0;

    // Rotational Band Logic
    wire signed [11:0] angle_approx = dx + dy; 
    wire [7:0] swirl = (r2[15:8] + angle_approx[10:3] + t[7:0]);

    reg [2:0] pr, pg; reg [1:0] pb;
    always @* begin
        if (inside) begin
            case (swirl[7:4]) 
                4'h0, 4'h1: {pr, pg, pb} = {3'b111, 3'b111, 2'b00};
                4'h2, 4'h3: {pr, pg, pb} = {3'b111, 3'b011, 2'b01};
                4'h4, 4'h5: {pr, pg, pb} = {3'b101, 3'b101, 2'b11};
                4'h6, 4'h7: {pr, pg, pb} = {3'b011, 3'b111, 2'b11};
                4'h8, 4'h9: {pr, pg, pb} = {3'b111, 3'b010, 2'b00};
                4'hA, 4'hB: {pr, pg, pb} = {3'b110, 3'b110, 2'b10};
                default:    {pr, pg, pb} = {3'b111, 3'b101, 2'b11};
            endcase
        end else {pr, pg, pb} = 0;
    end

    wire [2:0] fr = (pr & {3{intensity[15]}});
    wire [2:0] fg = (pg & {3{intensity[15]}});
    wire [1:0] fb = (pb & {2{intensity[15]}});

    // High Density Twinkling Starfield
    wire [15:0] star_seed = (o_x * 10'd41) ^ (o_y * 10'd97) ^ {t[5:0], 10'd0};
    wire star_twinkle = (t[5] ^ star_seed[3]); 
    wire is_star = (!inside) && ((star_seed & 16'h01FF) == 16'h00A) && star_twinkle;

    // Output Mixing
    assign vga_red   = o_active ? ((inside ? fr : {3{is_star}}) & sw[7:5]) : 0;
    assign vga_green = o_active ? ((inside ? fg : {3{is_star}}) & sw[4:2]) : 0;
    assign vga_blue  = o_active ? ((inside ? fb : {2{is_star}}) & sw[1:0]) : 0;
    
    assign vga_hs = o_hs; assign vga_vs = o_vs;

endmodule

// Fast Log Approximation
module log_fast (input wire signed [31:0] x, output wire signed [31:0] y);
    integer i; reg [4:0] msb;
    always @* begin
        msb = 0;
        for (i=0; i<31; i=i+1) if (x[i]) msb = i;
    end
    wire signed [31:0] log2_val = (($signed({27'd0, msb}) - 32'sd16) << 16);
    assign y = (log2_val * 32'h0000_B172) >>> 16; 
endmodule

// Fast Exp2 Approximation
module exp2_fast (input wire signed [31:0] x, output wire signed [31:0] y);
    wire signed [15:0] intp = x[31:16];
    reg [31:0] lut;
    always @* lut = 32'h00010000 + (x[15:0] & 16'hFFFF); 
    assign y = (intp[15]) ? (lut >>> -intp) : (lut <<< intp);
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