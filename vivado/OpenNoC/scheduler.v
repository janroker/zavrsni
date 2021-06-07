module scheduler #(parameter X = 0,
                   Y = 0,
                   total_width = 0,
                   x_size = 0,
                   y_size = 0,
                   pck_num = 0,
                   data_width = 0,
                   max_pcks_in_NoC = ((X*Y)-1)*8*2 ) // // MOJE DODANO MAX NUM PCKS IN NOC = (X*Y - 1) * 8 * 2 = (X*Y-1) * 16 jer u svaki PE stane 8 paketa za obradu i 8 paketa na izlazu (salje se po osam komada)
                 (input clk,
                   input wire rstn, // MOJE DODANO
                    // PCI - Scheduler interface 
                   input i_valid_pci,
                   input [data_width-1:0] i_data_pci,
                   output o_ready_pci,
                   // From scheduler to PCI
                   output reg [data_width-1:0] o_data_pci,
                   output reg o_valid_pci,
                   input i_ready_pci,
                   //Scheduler-NOC interfaces
                   input i_ready,
                   output reg o_valid,
                   output reg [total_width-1:0] o_data,
                   //from NOC to Schedler
                   input wea,
                   input [total_width-1:0] i_data_pe
                   //output o_ready_pe
                   );
    
    reg [pck_num-1:0]rd_addr;
    wire [pck_num-1:0] wr_addr;
    reg [x_size-1:0] x_coord;
    reg [y_size-1:0] y_coord;
    reg [pck_num-1:0] pck_no;
    wire valid_flag;
    
    reg [data_width:0] my_mem [(2**pck_num)-1:0];
    
    reg [$clog2(max_pcks_in_NoC) : 0] pck_in_NoC = 0; // npr max pck 4 => treba nam 3 bita
    
    initial
    begin
        x_coord = 'd0;
        y_coord = 'd1;
        pck_no  = 'd0;
        rd_addr <= 'd0;
    end
    
    always @(posedge clk)
    begin
        if(!rstn) // reset je
        begin
            pck_in_NoC <= 0;
        end
        else if(i_valid_pci & o_ready_pci & ~(wea) ) // ako odlazi, a ne dolazi
        begin
            pck_in_NoC <= pck_in_NoC + 1;
        end
        else if(i_valid_pci & o_ready_pci & wea) // dolazi i odlazi
        begin
            
        end
        else if(wea) // samo dolazi
        begin
            pck_in_NoC <= pck_in_NoC - 1;
        end 
    end
    
    always @(posedge clk)
    begin
        if(!rstn)
        begin
            o_valid <= 1'b0;
        end
        else if (i_valid_pci & o_ready_pci) // ako je u NoC-u manje od max...
        begin
           // $strobe("pck_no = %d, pck in NoC = %d", pck_no, pck_in_NoC);
            o_data[total_width-1:y_size+x_size+pck_num]   <= i_data_pci;
            o_data[x_size+y_size+pck_num-1:y_size+x_size] <= pck_no;
            o_data[x_size+y_size-1:x_size]                <= y_coord;
            o_data[x_size-1:0]                            <= x_coord;
            o_valid                                       <= 1'b1;
            pck_no                                        <= pck_no+1;
            
            if((pck_no+1) % 8 == 0)
            begin
                if (y_coord < Y-1)
                begin
                    y_coord <= y_coord+1;
                end
                else
                begin
                    if (x_coord < X-1)
                    begin
                        x_coord <= x_coord+1;
                        y_coord <= 'b0;
                    end
                    else
                    begin
                        x_coord <= 'd0;
                        y_coord <= 'd1;
                    end
                end
            end
        end
        else if (o_valid & !i_ready)
        begin
            o_valid <= 1'b1;
        end
        else
        begin
            o_valid <= 1'b0;
        end
    end
    
    assign o_ready_pci = i_ready & (pck_in_NoC < max_pcks_in_NoC); // DODAO
    assign valid_flag  = my_mem[rd_addr][data_width];
    assign wr_addr     = i_data_pe[x_size+y_size+pck_num-1:y_size+x_size];
    
    always@(posedge clk)
    begin
        if(rstn)// nije reset
        begin
            if (wea)
            begin
               // $strobe("wr_addr = %d, pck in NoC = %d", wr_addr, pck_in_NoC);
                my_mem[wr_addr]             <= i_data_pe[total_width-1:y_size+x_size+pck_num];
                my_mem[wr_addr][data_width] <= 1'b1;
            end
            if (valid_flag & i_ready_pci)
            begin
                my_mem[rd_addr][data_width] <= 1'b0;
            end
        end
    end
    
    always@(posedge clk)
    begin
        if(rstn)// nije reset
        begin
            if (valid_flag & i_ready_pci)
            begin
                o_data_pci  <= my_mem[rd_addr];
                o_valid_pci <= 1'b1;
                rd_addr     <= rd_addr+1;
            end
            else
            begin
                o_valid_pci <= 1'b0;
            end
        end
    end
    
    
endmodule