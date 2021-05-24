`timescale 1ns / 1ps

`include "include_file.vh"

`define x_size $clog2(`X)
`define y_size $clog2(`Y)
`define total_width  (`x_size+`y_size+`pck_num+`data_width)

module dctOnNoCTest();
    
    reg  clk;
    reg  [255:0] o_data;
    //reg  [7:0] o_data;
    wire [255:0] tb_o_data_pci;
    wire tb_o_ready_pci ;
    reg tb_i_ready_pci = 1'b1;
    reg tb_i_valid_pci;
    wire tb_o_valid_pci;
    reg sendDone = 0;
    integer fileIN;
    integer fileOUT;
    integer x;
    integer i;
    
    reg[255:0] i_data;
    integer rtn1;
    reg rstn;
    
    initial
    begin
        fileIN  = $fopen("D:/vivado_ws/zavrsni/zavrsni/zavrsni.srcs/sim_1/new/izlaz.b","rb");
        fileOUT = $fopen("D:/vivado_ws/zavrsni/zavrsni/zavrsni.srcs/sim_1/new/izlaz2.b","wb");
        if (fileIN == 0)
        begin
            $display("Cannot open the image fileIN");
            $fclose(fileIN);
            $fclose(fileOUT);
            $finish;
        end
        
        clk     = 1'b0;
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
    
    always@(posedge clk)
    begin
        if (tb_o_ready_pci & !sendDone)
        begin
            for(x=0;x<32;x=x+1) // block0 | block1 | ... | block7 | pck_no | y | x
                rtn1 = $fscanf(fileIN,"%c",i_data[`data_width - (x+1)*8 +: 8]);
            // $strobe("i_data %H", i_data[`total_width -1 -: `data_width]);
            o_data         <= i_data;
            tb_i_valid_pci <= 1'b1;
            if ($feof(fileIN))
            begin
                $fclose(fileIN);
                sendDone = 1'b1;
            end
            else
            begin
                sendDone = 1'b0;
            end
        end
        else if (tb_i_valid_pci & ~tb_o_ready_pci)
        begin
            tb_i_valid_pci <= 1'b1;
        end
        else
            tb_i_valid_pci <= 1'b0;
    end
    
    integer counter = 0; /// count clocks before end...
    integer y;
    always @(posedge clk)
    begin
        if (counter < 10000 )
        begin
            if (tb_o_valid_pci)
            begin
                for(y = 0;y<32;y = y+1)
                    $fwrite(fileOUT,"%c",tb_o_data_pci[`data_width - (y+1)*8 +: 8]);
                counter <= 0;
            end
            if(sendDone) counter <= counter + 1;
        end
        else
        begin
            $fclose(fileOUT);
            $stop;
        end
    end
    
    wire [(`X*`Y)-1:0] r_valid_pe;
    wire [(`total_width*`X*`Y)-1:0] r_data_pe;
    wire [(`X*`Y)-1:0] r_ready_pe;
    wire [(`X*`Y)-1:0] w_valid_pe;
    wire [(`total_width*`X*`Y)-1:0] w_data_pe;
    wire [(`X*`Y)-1:0] w_ready_pe;
    
    openNocTop #(.X(`X),.Y(`Y),.data_width(`data_width),.pkt_no_field_size(`pck_num))
    ON
    (
    .clk(clk),
    .rstn(rstn),
    .r_valid_pe(r_valid_pe),
    .r_data_pe(r_data_pe),
    .r_ready_pe(r_ready_pe),
    .w_valid_pe(w_valid_pe),
    .w_data_pe(w_data_pe),
    .w_ready_pe(w_ready_pe)
    );
    
    procTop #(.X(`X),.Y(`Y),.data_width(`data_width),.pck_num(`pck_num))
    pT(
    .clk(clk),
    .rstn(rstn),
    //PE interfaces
    .r_valid_pe(r_valid_pe),
    .r_data_pe(r_data_pe),
    .r_ready_pe(r_ready_pe),
    .w_valid_pe(w_valid_pe),
    .w_data_pe(w_data_pe),
    .w_ready_pe(w_ready_pe),
    //PCIe interfaces
    .i_valid(tb_i_valid_pci),
    .i_data(o_data),
    .o_ready(tb_o_ready_pci),
    .o_data(tb_o_data_pci),
    .o_valid(tb_o_valid_pci),
    .i_ready(tb_i_ready_pci)
    );
    
endmodule
