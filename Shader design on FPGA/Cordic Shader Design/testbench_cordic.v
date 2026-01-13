`timescale 1ns/1ps
`default_nettype none

module stimulus;

    parameter P = 18;
    parameter N = 16;

    reg  signed [N-1:0] theta_d;
    wire signed [P-1:0] x_o;
    wire signed [P-1:0] y_o;

    integer i;
    integer outFile;

    CORDIC_Merged #(
        .N    (N),
        .P1   (P),
        .ITER (16)
    ) dut (
        .bin       (theta_d),
        .cos_theta (x_o),
        .sin_theta (y_o)
    );

    initial begin
        outFile = $fopen("monitor_merge.txt", "w");
    end

    always @(x_o or y_o) begin
        $fwrite(outFile, "%d %d\n", x_o, y_o);
    end

    initial begin
        theta_d = 0;
        #5;
        // Step is 3276 in Q1.15 (approximately 0.1 rad)
        for (i = 0; i < 16; i = i + 1) begin
            #20 theta_d = theta_d + 16'sd3276;
        end
        #400;
        $fclose(outFile);
        $finish;
    end

    initial begin
        $monitor($time,
                 " theta %d, cos theta %d, sine theta %d",
                 theta_d, x_o, y_o);
    end

endmodule

`default_nettype wire