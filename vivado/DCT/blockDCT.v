// `timescale 1ns / 1ps

module blockDCT #(parameter total_width = 0,
                  x_size = 0,
                  y_size = 0,
                  pck_num = 0,
                  data_width = 0)
                 (input wire clk,
                  input wire rstn,
                  input wire [total_width-1:0] i_data,
                  input wire i_valid,
                  output wire [total_width-1:0] o_data, // fifo i data i O_data ... TODO width je 280... a mi imamo ovdje total_width.. kako to radi?
                  output wire o_valid,
                  input wire i_ready,
                  output reg o_ready = 'b1);
    
    reg [total_width - 1 : 0] block88 [0:7]; // 8 redaka blocka tj. 8x8 polje pixela + routing i packet info...
    // 8 * block0 | block1 | ... | block7 | pck_no | y | x
    reg [total_width - 1 : 0] block88Out [0:7];
    
    reg blockReceived = 'b0;
    integer counter   = 0;
    always @(posedge clk) // primi pakete
    begin
        if (i_valid && o_ready && rstn)
        begin
            block88[i_data[x_size + y_size +: pck_num] % 8] <= i_data; // na poziciju broj paketa % 8 stavi redak ... //  [total_width -1 -: (data_width + pck_num)]
            block88[i_data[x_size + y_size +: pck_num] % 8] [x_size+y_size-1 : 0]                      <= 'h0; // daj koordinate 0 0
            if (counter == 7)
            begin
                counter       <= 0;
                o_ready       <= 'b0;
                blockReceived <= 'b1;
            end
            else
                counter <= counter + 1;
        end
    end
    
    reg [data_width - 1 : 0] dct_i_data;
    wire [data_width -1 : 0] dct_o_data;
    reg dct_i_valid = 'b0;
    wire dct_o_ready;
    wire dct_o_valid;
    reg dct_i_ready = 'b0;
    
    integer countProgress = 0; // < 8 rows... > = 8 ... columns
    reg writeFifo         = 'b0;
    integer toX; // x for loops...
    integer fromX;
    integer x;
    reg sendDCT = 'b1; // boolean if send to dct
    always @(posedge clk) // posalji pakete
    begin
        if (blockReceived && rstn)
        begin
        
            ///////// dct input
            if (countProgress < 8 && dct_o_ready && sendDCT) // rows
            begin
                dct_i_valid <= 'b1;
                dct_i_data  <= block88[countProgress] [total_width -1 -: data_width];
                countProgress <= countProgress + 1;
                sendDCT <= 'b0;
            end
            else if (countProgress < 16 && dct_o_ready && sendDCT)// columns
            begin
                dct_i_valid <= 'b1;
                for(toX = 0; toX < 8; toX = toX + 1)
                    dct_i_data[data_width - 1 - toX*32 -: 32] <= block88[toX] [total_width - 1 - (((countProgress) % 8) *32) -: 32];
                countProgress <= countProgress + 1;
                sendDCT <= 'b0;
            end
            else
                dct_i_valid <= 'b0;
            
            ///////// dct output
            if (dct_o_valid && (countProgress <= 8))
            begin
                dct_i_ready                                             <= 'b1;
                block88[countProgress - 1] [total_width -1 -: data_width] <= dct_o_data; // spremi izlaz za prethodni redak...
                sendDCT <= 'b1;
            end
            else if (dct_o_valid && (countProgress <= 16)) // spremi izlaz za prehodni column
            begin
                dct_i_ready <= 'b1;
                for(fromX = 0; fromX < 8; fromX = fromX + 1)
                    block88[fromX] [total_width - 1 - (((countProgress-1) % 8) *32) -: 32] <= dct_o_data[data_width - 1 - fromX*32 -: 32];
                sendDCT <= 'b1;
                
                if(countProgress == 16) countProgress <= countProgress + 1;
            end
            else
                dct_i_ready <= 'b0;
            
            
            if (countProgress == 17 && ~writeFifo)
            begin
                blockReceived <= 'b0;
                writeFifo     <= 'b1;
                sendDCT <= 'b1;
                for(x = 0; x < 8; x = x+1) // prebaci u drugi array za van...
                   block88Out[x] <= block88[x];
                countProgress <= 0;
                o_ready       <= 'b1;
            end
        end
    end
    
    reg [total_width - 1 : 0] fifo_i_data;
    wire fifo_o_ready;
    reg fifo_i_valid = 'b0;
    
    integer countFifo = 0;
    always @(posedge clk) // posalji pakete
    begin
        if (writeFifo && rstn && fifo_o_ready && countFifo < 8)
        begin
            fifo_i_valid <= 'b1;
            fifo_i_data  <= block88Out[countFifo];
            countFifo    <= countFifo + 1;
        end
        else if (countFifo == 8)
        begin
            countFifo    <= 0;
            fifo_i_valid <= 'b0;
            writeFifo    <= 'b0;
        end
    end
                
    always @(rstn) // primi pakete
    begin
        if (~rstn)
        begin
            o_ready       = 'b1;
            blockReceived = 'b0;
            counter       = 0;
            dct_i_data    = 0;
            dct_i_valid   = 'b0;
            dct_i_ready   = 'b0;
            
            countProgress = 0;
            writeFifo     = 'b0;
            toX           = 0;
            fromX         = 0;
            x             = 0;
            
            fifo_i_data  = 0;
            fifo_i_valid = 'b0;
            
            countFifo = 0;
        end
    end
                
    axis_data_fifo_0 myFifo ( // kapacitet je 4 bloka... ima 32 polja po 280 bitova...
    .s_axis_aresetn(rstn),          // input wire s_axis_aresetn
    .s_axis_aclk(clk),                // input wire s_axis_aclk
    .s_axis_tvalid(fifo_i_valid),            // input wire s_axis_tvalid
    .s_axis_tready(fifo_o_ready),            // output wire s_axis_tready
    .s_axis_tdata(fifo_i_data),              // input wire [279 : 0] s_axis_tdata
    .m_axis_tvalid(o_valid),            // output wire m_axis_tvalid
    .m_axis_tready(i_ready),            // input wire m_axis_tready
    .m_axis_tdata(o_data),              // output wire [279 : 0] m_axis_tdata
    .axis_wr_data_count(),  // output wire [31 : 0] axis_wr_data_count
    .axis_rd_data_count()  // output wire [31 : 0] axis_rd_data_count
    );
    
    dct #(.data_width(data_width)) dct
    (
    .clk(clk),
    .rstn(rstn),
    .i_data(dct_i_data),
    .i_valid(dct_i_valid),
    .o_data(dct_o_data),
    .o_valid(dct_o_valid),
    .i_ready(dct_i_ready),
    .o_ready(dct_o_ready)
    );
    
endmodule
