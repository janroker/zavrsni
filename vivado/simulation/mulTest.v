//`timescale 1ns / 1ps

module mulTest(input clock,
               input rstn,
               input s_axis_a_tvalid,
               output s_axis_a_tready,
               input [31 : 0] s_axis_a_tdata,
               input s_axis_b_tvalid,
               output s_axis_b_tready,
               input [31 : 0] s_axis_b_tdata,
               output m_axis_result_tvalid,
               input m_axis_result_tready,
               output [31 : 0] m_axis_result_tdata);
    
    
    
fpMul your_instance_name (
    .aclk(clock),                                  // input wire aclk
    .aresetn(rstn),                            // input wire aresetn
    .s_axis_a_tvalid(s_axis_a_tvalid),            // input wire s_axis_a_tvalid
    .s_axis_a_tready(s_axis_a_tready),            // output wire s_axis_a_tready
    .s_axis_a_tdata(s_axis_a_tdata),              // input wire [31 : 0] s_axis_a_tdata
    .s_axis_b_tvalid(s_axis_b_tvalid),            // input wire s_axis_b_tvalid
    .s_axis_b_tready(s_axis_b_tready),            // output wire s_axis_b_tready
    .s_axis_b_tdata(s_axis_b_tdata),              // input wire [31 : 0] s_axis_b_tdata
    .m_axis_result_tvalid(m_axis_result_tvalid),  // output wire m_axis_result_tvalid
    .m_axis_result_tready(m_axis_result_tready),  // input wire m_axis_result_tready
    .m_axis_result_tdata(m_axis_result_tdata)    // output wire [31 : 0] m_axis_result_tdata
    );
endmodule
