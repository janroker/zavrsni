//`timescale 1ns / 1ps

`define X 4
`define Y 4
`define data_width 256
`define pck_num 12

`define x_size $clog2(`X)
`define y_size $clog2(`Y)
`define total_width  (`x_size+`y_size+`pck_num+`data_width)

module dctSingleTest(
    wire clk,
    wire rstn,
    wire [`data_width -1:0] i_data,
    wire i_valid,
    wire [`data_width -1:0] o_data,
    wire o_valid,
    wire i_ready,
    wire o_ready
    );
    
    dct #(.data_width(`data_width)) dct
            (.clk(clk),
            .rstn(rstn),
            .i_data(i_data),
            .i_valid(i_valid),
            .o_data(o_data),
            .o_valid(o_valid),
            .i_ready(i_ready),
            .o_ready(o_ready));
            
endmodule
