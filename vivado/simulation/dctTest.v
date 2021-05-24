`timescale 1ns / 1ps

`define X 4
`define Y 4
`define data_width 256
`define pck_num 12

`define x_size $clog2(`X)
`define y_size $clog2(`Y)
`define total_width  (`x_size+`y_size+`pck_num+`data_width)

module dctTest();
    
    reg clk;
    reg rstn;
    wire [`data_width - 1 :0] o_data;
    reg [`data_width - 1 :0] o_data_tmp;
    reg [`data_width - 1 :0] i_data;
    reg i_valid;
    wire o_valid;
    reg i_ready = 1;
    wire o_ready;
    
    reg sendDone = 0;
    
    integer fileIN;
    integer fileOUT;
    integer counter = 0;
    
    integer x;
    
    integer rtn1;
    // wire [`total_width -1:0] i_data,
    // wire i_valid,
    // wire [`total_width -1:0] o_data,
    // wire o_valid,
    // wire i_ready,
    // wire o_ready
    
    initial
    begin
        fileIN  = $fopen("D:/vivado_ws/zavrsni/zavrsni/zavrsni.srcs/sim_1/new/izlaz.b","rb");
        fileOUT = $fopen("D:/vivado_ws/zavrsni/zavrsni/zavrsni.srcs/sim_1/new/izlaz2.b","wb");
        if (fileIN == 0)
        begin
            $display("Cannot open the image file");
            $fclose(fileIN);
            $fclose(fileOUT);
            $finish;
        end
        
        clk = 1'b0;
        forever
        begin
            clk = ~clk;
            #1;
        end
    end
    
    initial
    begin
        rstn = 0;
        #10;
        rstn = 1;
    end
    
    always@(negedge clk)
    begin
        if (o_ready && !sendDone && !$feof(fileIN) && rstn)
        begin
            for(x=0;x<32;x=x+1) // block0 | block1 | ... | block7 | pck_no | y | x
                rtn1 = $fscanf(fileIN,"%c",i_data[`data_width - (x+1)*8 +: 8]);
                // rtn1 = $fscanf(fileIN,"%c",i_data[`data_width - (x+1)*8 +: 8]);
                //rtn1 = $fscanf(fileIN,"%c",i_data[x*8 +: 8]);
                
            i_valid <= 1'b1;
            counter <= counter + 1;
        end
        else if ($feof(fileIN))
        begin
            $fclose(fileIN);
            $strobe("send DONE");
            sendDone = 1'b1;
        end
    end
            
            
    integer y;
    reg writeReady = 'b0;
    
    always @(negedge clk)
    begin
        if (o_valid)
        begin
            o_data_tmp <= o_data;
            writeReady <= 'b1;
        end
        if(writeReady)
        begin
            for(y = 0;y<32;y = y+1)
                $fwrite(fileOUT,"%c",o_data_tmp[`data_width - (y+1)*8 +: 8]);
                // $fwrite(fileOUT,"%c",o_data_tmp[`data_width - (y+1)*8 +: 8]);
            
            writeReady <= 'b0;
            
            if (sendDone)
            begin
                $fclose(fileOUT);
                $stop;
            end
        end
    end
            
            
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
