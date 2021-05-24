// `timescale 1ns / 1ps

module dct #(parameter data_width = 0) // (parameter total_width = 0, x_size = 0, y_size = 0, pck_num = 0)
            (input wire clk,
             input wire rstn,
             input wire [data_width-1:0] i_data,
             input wire i_valid,
             output wire [data_width-1:0] o_data,
             //output wire o_valid,
             output reg o_valid,
             input wire i_ready,
             output reg o_ready = 'b1);
    
    localparam SqrtHalfSqrt =  32'h3fa73d75; //1.306562965; //    sqrt((2 + sqrt(2)) / 2) = cos(pi * 1 / 8) * sqrt(2)
    localparam InvSqrt      =  32'h3f3504f3; // 0.707106781; // 1 / sqrt(2)      = cos(pi * 2 / 8)
    localparam HalfSqrtSqrt =  32'h3ec3ef15; // 0.382683432; //     sqrt(2 - sqrt(2)) / 2 = cos(pi * 3 / 8)
    localparam InvSqrtSqrt  =  32'h3f0a8bd4; // 0.541196100; // 1 / sqrt(2 - sqrt(2))  = cos(pi * 3 / 8) * sqrt(2)
    
    integer instrNum = 0;
    integer clkCNT = 0;
    reg fifoWrEn = 0;
    reg [data_width-1:0] inv_data = 0;
    assign o_data = inv_data; // kad nema fifo onda ovako...
    
    reg reseting = 'b0;
    
    
    ///////////////////// ADD_SUB WIRES /////////////
    reg s_axis_a_tvalid_addSub = 0;
    wire s_axis_a_tready_addSub;
    reg [31 : 0] s_axis_a_tdata_addSub = 0;
    
    reg s_axis_b_tvalid_addSub = 0;
    wire s_axis_b_tready_addSub;
    reg [31 : 0] s_axis_b_tdata_addSub = 0;
    
    reg s_axis_operation_tvalid_addSub = 0;
    wire s_axis_operation_tready_addSub;
    reg [7 : 0] s_axis_operation_tdata_addSub = 0;
    
    wire m_axis_result_tvalid_addSub;
    reg m_axis_result_tready_addSub = 0;
    wire [31 : 0] m_axis_result_tdata_addSub;
    //////////////////////////////////////////////////
    
    ///////////////////// MUL WIRES /////////////
    reg s_axis_a_tvalid_mul = 0;
    wire s_axis_a_tready_mul;
    reg [31 : 0] s_axis_a_tdata_mul = 0;
    
    reg s_axis_b_tvalid_mul = 0;
    wire s_axis_b_tready_mul;
    reg [31 : 0] s_axis_b_tdata_mul = 0;
    
    wire m_axis_result_tvalid_mul;
    reg m_axis_result_tready_mul = 0;
    wire [31 : 0] m_axis_result_tdata_mul;
    //////////////////////////////////////////////////
    
    reg [31:0] register0 = 0;
    reg [31:0] register1 = 0;
    reg [31:0] register2 = 0;
    reg [31:0] register3 = 0;
    reg [31:0] register4 = 0;
    
    task setForAdd;
        begin
            s_axis_a_tvalid_addSub         <= 1'b1;
            s_axis_b_tvalid_addSub         <= 1'b1;
            s_axis_operation_tvalid_addSub <= 1'b1;
            
            s_axis_operation_tdata_addSub <= 'd0; // addition = 0
        end
    endtask
    
    task setForSub;
        begin
            s_axis_a_tvalid_addSub         <= 1'b1;
            s_axis_b_tvalid_addSub         <= 1'b1;
            s_axis_operation_tvalid_addSub <= 1'b1;
            
            s_axis_operation_tdata_addSub <= 'd1; // subtraction = 1
        end
    endtask
    
    task setForMul;
        begin
            s_axis_a_tvalid_mul <= 1'b1;
            s_axis_b_tvalid_mul <= 1'b1;
        end
    endtask
    
    task disableMulIn;
        begin
            s_axis_a_tvalid_mul <= 1'b0;
            s_axis_b_tvalid_mul <= 1'b0;
        end
    endtask
    
    task enableMulOut;
        begin
            m_axis_result_tready_mul <= 1'b1;
        end
    endtask
    
    task disableMulOut;
        begin
            m_axis_result_tready_mul <= 1'b0;
        end
    endtask
    
    task disableAddSubIn;
        begin
            s_axis_a_tvalid_addSub         <= 1'b0;
            s_axis_b_tvalid_addSub         <= 1'b0;
            s_axis_operation_tvalid_addSub <= 1'b0;
        end
    endtask
    
    task enableAddSubOut;
        begin
            m_axis_result_tready_addSub <= 1'b1;
        end
    endtask
    
    task disableAddSubOut;
        begin
            m_axis_result_tready_addSub <= 1'b0;
        end
    endtask
    
    task reset;
        begin
            o_ready <= 'b0;
            instrNum <= 0;
            fifoWrEn <= 0;
            inv_data <= 0;
            reseting <= 'b1;
            
            ///////////////////// ADD_SUB WIRES /////////////
            s_axis_a_tvalid_addSub <= 0;
            s_axis_a_tdata_addSub <= 0;
            
            s_axis_b_tvalid_addSub <= 0;
            s_axis_b_tdata_addSub <= 0;
            
            s_axis_operation_tvalid_addSub <= 0;
            s_axis_operation_tdata_addSub <= 0;
            
            m_axis_result_tready_addSub <= 0;
            //////////////////////////////////////////////////
            
            ///////////////////// MUL WIRES /////////////
            s_axis_a_tvalid_mul <= 0;
            s_axis_a_tdata_mul <= 0;
            
            s_axis_b_tvalid_mul <= 0;
            s_axis_b_tdata_mul <= 0;
            
            m_axis_result_tready_mul <= 0;
            //////////////////////////////////////////////////
            
            register0 <= 0;
            register1 <= 0;
            register2 <= 0;
            register3 <= 0;
            register4 <= 0;
        end
    endtask
    
    task disableAll;
        begin
            disableMulIn();
            disableMulOut();
            disableAddSubIn();
            disableAddSubOut();
        end
    endtask
    
    
    always @(posedge clk)
    begin
        clkCNT <= clkCNT + 1;
        
        if(~rstn)
        begin
            reset();
        end
        else if(reseting)
        begin
            o_ready <= 'b1;
            reseting <= 'b0;
        end    
        else if ((i_valid && o_ready))
        begin
            o_ready <= 1'b0; // nisam spreman primiti
                    
            inv_data <= i_data; // primi podatke
            instrNum <= instrNum +1;
            
            disableAll();
        end
        else if(~o_ready && ~fifoWrEn) 
        begin
            case(instrNum)
                'd1 : begin // 0 + 7
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForAdd();
                        
                        // s_axis_a_tdata_addSub[31:0] <= inv_data[total_width -1 - x_size - y_size - pck_num - 0*32 -:32];
                        // s_axis_b_tdata_addSub[31:0] <= inv_data[total_width -1 - x_size - y_size - pck_num - 7*32 -:32];
                        s_axis_a_tdata_addSub[31:0] <= inv_data[data_width -1 - 0*32 -:32];
                        s_axis_b_tdata_addSub[31:0] <= inv_data[data_width -1 - 7*32 -:32];
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd2 : begin // 3 + 4
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForAdd();
                        
                        s_axis_a_tdata_addSub[31:0] <= inv_data[data_width -1 - 3*32 -:32];
                        s_axis_b_tdata_addSub[31:0] <= inv_data[data_width -1 - 4*32 -:32];
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd3 : begin // 1 + 6
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForAdd();
                        
                        s_axis_a_tdata_addSub[31:0] <= inv_data[data_width -1 - 1*32 -:32];
                        s_axis_b_tdata_addSub[31:0] <= inv_data[data_width -1 - 6*32 -:32];
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd4 : begin // 2 + 5
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForAdd();
                        
                        s_axis_a_tdata_addSub[31:0] <= inv_data[data_width -1 - 2*32 -:32];
                        s_axis_b_tdata_addSub[31:0] <= inv_data[data_width -1 - 5*32 -:32];
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd5 : begin // 3 - 4
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForSub();
                        
                        s_axis_a_tdata_addSub[31:0] <= inv_data[data_width -1 - 3*32 -:32];
                        s_axis_b_tdata_addSub[31:0] <= inv_data[data_width -1 - 4*32 -:32];
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd6 : begin // 2 - 5
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForSub();
                        
                        s_axis_a_tdata_addSub[31:0] <= inv_data[data_width -1 - 2*32 -:32];
                        s_axis_b_tdata_addSub[31:0] <= inv_data[data_width -1 - 5*32 -:32];
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                
                'd7 : begin // 1 - 6
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForSub();
                        
                        s_axis_a_tdata_addSub[31:0] <= inv_data[data_width -1 - 1*32 -:32];
                        s_axis_b_tdata_addSub[31:0] <= inv_data[data_width -1 - 6*32 -:32];
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd8 : begin // 0 - 7
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForSub();
                        
                        s_axis_a_tdata_addSub[31:0] <= inv_data[data_width -1 - 0*32 -:32];
                        s_axis_b_tdata_addSub[31:0] <= inv_data[data_width -1 - 7*32 -:32];
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                // latency 13
                'd9 : begin // spremi 0+7 (izlaz iz addSub) u REG0
                    disableAddSubIn();
                    
                    if (m_axis_result_tvalid_addSub)
                    begin
                        enableAddSubOut();
                        
                        register0[31:0] <= m_axis_result_tdata_addSub[31:0];
                        
                        // $strobe("The value of 0+7 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd10 : begin // zbroji 0+7 (reg0) i 3+4 (izlaz iz addSub) i spremi 3+4 u reg1 = > add0347
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        ///////// zbroji 0+7 (reg0) i 3+4 (izlaz iz addSub)
                        setForAdd();
                        enableAddSubOut();
                        
                        s_axis_a_tdata_addSub[31:0] <= register0[31:0];
                        s_axis_b_tdata_addSub[31:0] <= m_axis_result_tdata_addSub[31:0];
                        ///////// END zbroji 0+7 (reg0) i 3+4 (izlaz iz addSub)
                        
                        register1[31:0] <= m_axis_result_tdata_addSub[31:0]; // spremi 3+4 u reg1
                        
                        // $strobe("The value of 3+4 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else // da se ne bi slucajno ponavljala operacija na addSub ili citalo iz njega
                    begin
                        disableAll();
                    end
                end
                'd11 : begin // oduzmi 0+7 (reg0) i 3+4 (reg1) = > sub07_34         takoder spremi iz addSub 1+6 u reg0
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        // oduzmi 0+7 (reg0) i 3+4 (reg1) = > sub07_34
                        setForSub();
                        enableAddSubOut();
                        
                        s_axis_a_tdata_addSub[31:0] <= register0[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register1[31:0];
                        ///////// END oduzmi 0+7 (reg0) i 3+4 (reg1) = > sub07_34
                       
                        register0[31:0] <= m_axis_result_tdata_addSub[31:0]; // 1+6 u reg0
                        
                        // $strobe("The value of 1+6 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else // da se ne bi slucajno ponavljala operacija na addSub ili citalo iz njega
                    begin
                        disableAll();
                    end
                end
                'd12 : begin // zbroji 1+6 (reg0) i 2+5 (izlaz iz addSub) = > add1256         takoder spremi iz addSub 2+5 u reg1
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        // zbroji 1+6 (reg0) i 2+5 (izlaz iz addSub) = > add1256
                        setForAdd();
                        enableAddSubOut();
                        
                        s_axis_a_tdata_addSub[31:0] <= register0[31:0];
                        s_axis_b_tdata_addSub[31:0] <= m_axis_result_tdata_addSub[31:0];
                        ///////// END
                        
                        register1[31:0] <= m_axis_result_tdata_addSub[31:0]; // 2+5 u reg1
                        
                        // $strobe("The value of 2+5 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else // da se ne bi slucajno ponavljala operacija na addSub zbog uvjeta m_axis_result_tvalid_addSub
                    begin
                        disableAll();
                    end
                end
                'd13 : begin // oduzmi 1+6 (reg0) i 2+5 (reg1) = > sub16_25         takoder spremi iz addSub 3-4 u reg0
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        // oduzmi 1+6 (reg0) i 2+5 (reg1) = > sub16_25
                        setForSub();
                        enableAddSubOut();
                        
                        s_axis_a_tdata_addSub[31:0] <= register0[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register1[31:0];
                        ///////// END
                       
                        register0[31:0] <= m_axis_result_tdata_addSub[31:0]; // 3-4 u reg0
                        
                        // $strobe("The value of 3-4 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else // da se ne bi slucajno ponavljala operacija na addSub zbog uvjeta m_axis_result_tvalid_addSub
                    begin
                        disableAll();
                    end
                end
                'd14 : begin // zbroji 3-4 (reg0) i 2-5 (izlaz iz addSub) = > sub23_45         takoder spremi iz addSub 2-5 u reg0
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        // zbroji 3-4 (reg0) i 2-5 (izlaz iz addSub) = > sub23_45
                        setForAdd();
                        enableAddSubOut();
                        
                        s_axis_a_tdata_addSub[31:0] <= register0[31:0];
                        s_axis_b_tdata_addSub[31:0] <= m_axis_result_tdata_addSub[31:0];
                        ///////// END
                        
                        register0[31:0] <= m_axis_result_tdata_addSub[31:0]; // 2-5 u reg0
                        
                        // $strobe("The value of 2-5 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else // da se ne bi slucajno ponavljala operacija na addSub zbog uvjeta m_axis_result_tvalid_addSub
                    begin
                        disableAll();
                    end
                end
                'd15 : begin // zbroji 2-5 (reg0) i 1-6 (izlaz iz addSub) = > sub12_56         takoder spremi iz addSub 1-6 u reg0
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        // zbroji 2-5 (reg0) i 1-6 (izlaz iz addSub) = > sub12_56
                        setForAdd();
                        enableAddSubOut();
                        
                        s_axis_a_tdata_addSub[31:0] <= register0[31:0];
                        s_axis_b_tdata_addSub[31:0] <= m_axis_result_tdata_addSub[31:0];
                        ///////// END
                        
                        register0[31:0] <= m_axis_result_tdata_addSub[31:0]; // 1-6 u reg0
                        
                        // $strobe("The value of 1-6 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else // da se ne bi slucajno ponavljala operacija na addSub zbog uvjeta m_axis_result_tvalid_addSub
                    begin
                        disableAll();
                    end
                end
                'd16 : begin // zbroji 1-6 (reg0) i 0-7 (izlaz iz addSub) = > sub01_67         takoder spremi iz addSub 0-7 u reg0
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        // zbroji 1-6 (reg0) i 0-7 (izlaz iz addSub) = > sub01_67
                        setForAdd();
                        
                        s_axis_a_tdata_addSub[31:0] <= register0[31:0];
                        s_axis_b_tdata_addSub[31:0] <= m_axis_result_tdata_addSub[31:0];
                        ///////// END
                        
                        enableAddSubOut();
                        register0[31:0] <= m_axis_result_tdata_addSub[31:0]; // 0-7 u reg0
                        
                        // $strobe("The value of 0-7 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else // da se ne bi slucajno ponavljala operacija na addSub zbog uvjeta m_axis_result_tvalid_addSub
                    begin
                        disableAll();
                    end
                end
                // latency moras cekat rezultate... u REG0 se nalazi 0-7
                'd17 : begin // add0347 u reg1
                    disableAddSubIn();
                    
                    if (m_axis_result_tvalid_addSub)
                    begin
                        enableAddSubOut();
                        register1[31:0] <= m_axis_result_tdata_addSub[31:0]; // add0347 u reg1
                        
                        // $strobe("The value of add0347 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd18 : begin // sub07_34 u reg2
                    
                    if (m_axis_result_tvalid_addSub)
                    begin
                        enableAddSubOut();
                        register2[31:0] <= m_axis_result_tdata_addSub[31:0]; // sub07_34 u reg2
                        
                        // $strobe("The value of sub07_34 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd19 : begin // zbroji add0347 (reg1) i add1256 (izlaz iz addSub) = > block0         takoder spremi iz addSub add1256 u reg3
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        // zbroji add0347 (reg1) i add1256 (izlaz iz addSub) = > block0
                        setForAdd();
                        
                        s_axis_a_tdata_addSub[31:0] <= register1[31:0];
                        s_axis_b_tdata_addSub[31:0] <= m_axis_result_tdata_addSub[31:0];
                        ///////// END
                        
                        enableAddSubOut();
                        register3[31:0] <= m_axis_result_tdata_addSub[31:0]; // add1256 u reg3
                        
                        // $strobe("The value of add1256 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd20 : begin // reg1 (add0347) - reg3 (add1256) = > block4         takoder spremi iz addSub sub16_25 u reg1
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        // reg1 (add0347) - reg3 (add1256) = > block4
                        setForSub();
                        
                        s_axis_a_tdata_addSub[31:0] <= register1[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register3[31:0];
                        ///////// END
                        
                        enableAddSubOut();
                        register1[31:0] <= m_axis_result_tdata_addSub[31:0]; // sub16_25 u reg1
                        
                        // $strobe("The value of sub16_25 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd21 : begin // reg2 (sub07_34) + reg1 (sub16_25) || izlaz iz addSub (sub23_45) * InvSqrtSqrt         takoder spremi iz addSub sub23_45 u reg1
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub && s_axis_a_tready_mul && s_axis_b_tready_mul)
                    begin
                        // reg1 (add0347) - reg3 (add1256) = > block4
                        setForAdd();
                        setForMul();
                        
                        s_axis_a_tdata_addSub[31:0] <= register2[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register1[31:0];
                        ///////// END
                        
                        //  izlaz iz addSub (sub23_45) * InvSqrtSqrt
                        s_axis_a_tdata_mul[31:0] <= m_axis_result_tdata_addSub[31:0];
                        s_axis_b_tdata_mul[31:0] <= InvSqrtSqrt;
                        // END
                        
                        enableAddSubOut();
                        register1[31:0] <= m_axis_result_tdata_addSub[31:0]; //  sub23_45 u reg1
                        
                        // $strobe("The value of sub23_45 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd22 : begin // izlaz iz addSub (sub12_56) * InvSqrt
                    
                    disableAddSubIn();
                    
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_mul && s_axis_b_tready_mul)
                    begin
                        setForMul();
                        enableAddSubOut();
                        
                        //  izlaz iz addSub (sub12_56) * InvSqrt
                        s_axis_a_tdata_mul[31:0] <= m_axis_result_tdata_addSub[31:0];
                        s_axis_b_tdata_mul[31:0] <= InvSqrt;
                        // END
                        
                        // $strobe("The value of sub12_56 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd23 : begin // izlaz iz addSub (sub01_67) * SqrtHalfSqrt || reg1 (sub23_45) - izlaz iz addSub (sub01_67)
                    
                    // izlaz iz addSub && ulazi u addSub && ulazi u mul
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub && s_axis_a_tready_mul && s_axis_b_tready_mul)
                    begin
                        setForMul();
                        setForSub();
                        enableAddSubOut();
                        
                        // reg1 (sub23_45) - izlaz iz addSub (sub01_67)
                        s_axis_a_tdata_addSub[31:0] <= register1[31:0];
                        s_axis_b_tdata_addSub[31:0] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        
                        //  izlaz iz addSub (sub01_67) * SqrtHalfSqrt
                        s_axis_a_tdata_mul[31:0] <= m_axis_result_tdata_addSub[31:0];
                        s_axis_b_tdata_mul[31:0] <= SqrtHalfSqrt;
                        // END
                        
                        // $strobe("The value of sub01_67 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd24 : begin // izlaz iz addSub (block0) || izlaz iz mul ((sub23_45) * InvSqrtSqrt) u reg1
                    
                    disableMulIn();
                    disableAddSubIn();
                    
                    // izlaz iz addSub && izlaz iz mul
                    if (m_axis_result_tvalid_addSub && m_axis_result_tvalid_mul)
                    begin
                        enableAddSubOut();
                        enableMulOut();
                        
                        // izlaz iz addSub (block0)
                        inv_data[data_width -1 - 0*32 -:32] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        // $strobe("The value of block0 is %H", m_axis_result_tdata_addSub);
                        // $strobe("The value of (sub23_45) * InvSqrtSqrt) is %H", m_axis_result_tdata_mul);
                        
                        //  izlaz iz mul ((sub23_45) * InvSqrtSqrt) u reg1
                        register1[31:0] <= m_axis_result_tdata_mul[31:0];
                        // END
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd25 : begin // izlaz iz addSub (block4) || izlaz iz mul (z3) + reg0 (0-7) || izlaz iz mul (z3) u reg3
                    
                    // izlaz iz addSub && izlaz iz mul && ulazi u addSub
                    if (m_axis_result_tvalid_addSub && m_axis_result_tvalid_mul && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        enableAddSubOut();
                        enableMulOut();
                        setForAdd();
                        
                        // izlaz iz addSub (block4)
                        inv_data[data_width -1 - 4*32 -:32] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        
                        //  izlaz iz mul (z3) + reg0 (0-7)
                        s_axis_a_tdata_addSub[31:0] <= m_axis_result_tdata_mul[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register0[31:0];
                        // END
                        
                        //  izlaz iz mul (z3) u reg3
                        register3[31:0] <= m_axis_result_tdata_mul[31:0];
                        // END
                        
                        // $strobe("The value of block4 is %H", m_axis_result_tdata_addSub);
                        // $strobe("The value of z3 is %H", m_axis_result_tdata_mul);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd26 : begin // reg0(0-7) - reg3(z3) || izlaz iz addSub (sub07_34 + sub16_25) * InvSqrt || izlaz iz mul (sub01_67 * SqrtHalfSqrt) u reg3
                    
                    // izlaz iz addSub && izlaz iz mul && ulazi u addSub && ulazi u mul
                    if (m_axis_result_tvalid_addSub && m_axis_result_tvalid_mul && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub && s_axis_a_tready_mul && s_axis_b_tready_mul)
                    begin
                        enableAddSubOut();
                        enableMulOut();
                        setForSub();
                        setForMul();
                        
                        //  reg0(0-7) - reg3(z3)
                        s_axis_a_tdata_addSub[31:0] <= register0[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register3[31:0];
                        // END
                        
                        //  izlaz iz addSub (sub07_34 + sub16_25) * InvSqrt
                        s_axis_a_tdata_mul[31:0] <= m_axis_result_tdata_addSub[31:0];
                        s_axis_b_tdata_mul[31:0] <= InvSqrt;
                        // END
                        
                        //   izlaz iz mul (sub01_67 * SqrtHalfSqrt) u reg3
                        register3[31:0] <= m_axis_result_tdata_mul[31:0];
                        // END
                        
                        // $strobe("The value of (sub07_34 + sub16_25) is %H", m_axis_result_tdata_addSub);
                        // $strobe("The value of sub01_67 * SqrtHalfSqrt is %H", m_axis_result_tdata_mul);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd27 : begin // izlaz iz addSub (sub23_45 - sub01_67) * HalfSqrtSqrt
                    disableMulOut();
                    disableAddSubIn();
                    
                    // izlaz iz addSub && ulazi u mul
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_mul && s_axis_b_tready_mul)
                    begin
                        enableAddSubOut();
                        setForMul();
                        
                        //  izlaz iz addSub (sub23_45 - sub01_67) * HalfSqrtSqrt
                        s_axis_a_tdata_mul[31:0] <= m_axis_result_tdata_addSub[31:0];
                        s_axis_b_tdata_mul[31:0] <= HalfSqrtSqrt;
                        // END
                         // $strobe("The value of sub23_45 - sub01_67 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd28 : begin // izlaz iz addSub(z6) u reg0 || izlaz iz mul(z1) + reg2(sub07_34) || izlaz iz mul(z1) u reg4;
                    disableMulIn();
                    
                    // izlaz iz addSub && izlaz iz mul && ulazi u addSub
                    if (m_axis_result_tvalid_addSub && m_axis_result_tvalid_mul && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        enableAddSubOut();
                        enableMulOut();
                        setForAdd();
                        
                        // izlaz iz addSub(z6) u reg0
                        register0[31:0] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        
                        // izlaz iz mul(z1) + reg2(sub07_34)
                        s_axis_a_tdata_addSub[31:0] <= m_axis_result_tdata_mul[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register2[31:0];
                        // END
                        
                        //  izlaz iz mul(z1) u reg4;
                        register4[31:0] <= m_axis_result_tdata_mul[31:0];
                        // END
                        
                        // $strobe("The value of z6 is %H", m_axis_result_tdata_addSub);
                        // $strobe("The value of z1 is %H", m_axis_result_tdata_mul);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd29 : begin // izlaz iz addSub(z7) u reg2 || reg2(sub07_34) - reg4(z1) || izlaz iz mul(z5) u reg4;
                    
                    // izlaz iz addSub && izlaz iz mul && ulazi u addSub
                    if (m_axis_result_tvalid_addSub && m_axis_result_tvalid_mul && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        enableAddSubOut();
                        enableMulOut();
                        setForSub();
                        
                        // izlaz iz addSub(z7) u reg2
                        register2[31:0] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        
                        // reg2(sub07_34) - reg4(z1)
                        s_axis_a_tdata_addSub[31:0] <= register2[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register4[31:0];
                        // END
                        
                        //  izlaz iz mul(z5) u reg4;
                        register4[31:0] <= m_axis_result_tdata_mul[31:0];
                        // END
                        
                        // $strobe("The value of z7 is %H", m_axis_result_tdata_addSub);
                        // $strobe("The value of z5 is %H", m_axis_result_tdata_mul);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd30 : begin // reg4(z5) + reg3(sub01_67*SqrtHalfSqrt)
                    disableAddSubOut();
                    disableMulOut();
                    
                    // ulazi u addSub
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForAdd();
                        
                        // reg4(z5) + reg3(sub01_67*SqrtHalfSqrt)
                        s_axis_a_tdata_addSub[31:0] <= register4[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register3[31:0];
                        // END
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd31 : begin // reg4(z5) + reg1(sub23_45*InvSqrtSqrt)
                    
                    // ulazi u addSub
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForAdd();
                        
                        // reg4(z5) + reg1(sub23_45*InvSqrtSqrt)
                        s_axis_a_tdata_addSub[31:0] <= register4[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register1[31:0];
                        // END
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd32 : begin // na izlazu addSub block2
                    disableAddSubIn();
                    
                    // izlaz iz addSub
                    if (m_axis_result_tvalid_addSub)
                    begin
                        enableAddSubOut();
                        
                        // na izlazu addSub block2
                        inv_data[data_width -1 - 2*32 -:32] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        
                        // $strobe("The value of block2 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd33 : begin // na izlazu addSub block6
                    
                    // izlaz iz addSub
                    if (m_axis_result_tvalid_addSub)
                    begin
                        enableAddSubOut();
                        
                        // na izlazu addSub block6
                        inv_data[data_width -1 - 6*32 -:32] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        
                        // $strobe("The value of block6 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd34 : begin // reg0(z6) + izlaz iz addSub(z4) || izlaz iz addSub(z4) u reg1
                    
                    // izlaz iz addSub && ulazi u addSub
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        enableAddSubOut();
                        setForAdd();
                        
                        // reg0(z6) + izlaz iz addSub(z4)
                        s_axis_a_tdata_addSub[31:0] <= register0[31:0];
                        s_axis_b_tdata_addSub[31:0] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        
                        // izlaz iz addSub(z4) u reg1
                        register1[31:0] <= m_axis_result_tdata_addSub[31:0];
                        
                         // $strobe("The value of z4 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd35 : begin // reg0(z6) - reg1(z4) || izlaz iz addSub(z2) u reg0
                    
                    // izlaz iz addSub && ulazi u addSub
                    if (m_axis_result_tvalid_addSub && s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        enableAddSubOut();
                        setForSub();
                        
                        //  reg0(z6) - reg1(z4)
                        s_axis_a_tdata_addSub[31:0] <= register0[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register1[31:0];
                        // END
                        
                        //  izlaz iz addSub(z2) u reg0
                        register0[31:0] <= m_axis_result_tdata_addSub[31:0];
                        
                         // $strobe("The value of z2 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd36 : begin // reg2(z7) + reg0(z2)
                    disableAddSubOut();
                    
                    // ulazi u addSub
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForAdd();
                        
                        //  reg2(z7) + reg0(z2)
                        s_axis_a_tdata_addSub[31:0] <= register2[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register0[31:0];
                        // END
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd37 : begin // reg2(z7) - reg0(z2)
                    
                    // ulazi u addSub
                    if (s_axis_a_tready_addSub && s_axis_b_tready_addSub && s_axis_operation_tready_addSub)
                    begin
                        setForSub();
                        
                        //  reg2(z7) + reg0(z2)
                        s_axis_a_tdata_addSub[31:0] <= register2[31:0];
                        s_axis_b_tdata_addSub[31:0] <= register0[31:0];
                        // END
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd38 : begin // block1
                    disableAddSubIn();
                    
                    // izlaz iz addSub
                    if (m_axis_result_tvalid_addSub)
                    begin
                        enableAddSubOut();
                        
                        // na izlazu addSub block1
                        inv_data[data_width -1 - 1*32 -:32] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        
                        // $strobe("The value of block1 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd39 : begin // block7
                    
                    // izlaz iz addSub
                    if (m_axis_result_tvalid_addSub)
                    begin
                        enableAddSubOut();
                        
                        // na izlazu addSub block7
                        inv_data[data_width -1 - 7*32 -:32] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        
                         // $strobe("The value of block7 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd40 : begin // block5
                    
                    // izlaz iz addSub
                    if (m_axis_result_tvalid_addSub)
                    begin
                        enableAddSubOut();
                        
                        // na izlazu addSub block5
                        inv_data[data_width -1 - 5*32 -:32] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        
                        // $strobe("The value of block5 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                'd41 : begin // block3
                    
                    // izlaz iz addSub
                    if (m_axis_result_tvalid_addSub)
                    begin
                        enableAddSubOut();
                        
                        // na izlazu addSub block3
                        inv_data[data_width -1 - 3*32 -:32] <= m_axis_result_tdata_addSub[31:0];
                        // END
                        
                        // $strobe("The value of block3 is %H", m_axis_result_tdata_addSub);
                        
                        instrNum <= instrNum +1;
                        // $strobe("clkCNT: %d", clkCNT);
                    end
                    else
                    begin
                        disableAll();
                    end
                end
                
                default: begin // tu si gotov... upisi rez u fifo
                    clkCNT <= 0;
                    instrNum <= 'd0;
                    fifoWrEn <= 1'b1;
                end
            endcase
        end
        else if (fifoWrEn && ~o_ready) // to znaci da si prethodno zapisao u fifo i trebas prestati pisati i reci da si spreman
        begin
            fifoWrEn <= 1'b0;
            o_ready  <= 1'b1;
        end
    end
     
    always @(posedge clk) // NE koristi se fifo nego ovo... pocetna verzija je bila s fifom
    begin
        if(fifoWrEn)
            o_valid <= 'b1;
        else
            o_valid <= 'b0;
    end
            //axis_data_fifo_0 myFifo (
           // .s_axis_aresetn(rstn),          // input wire s_axis_aresetn
           // .s_axis_aclk(clk),                // input wire s_axis_aclk
            // .s_axis_tvalid(fifoWrEn),            // input wire s_axis_tvalid
           // .s_axis_tready(),            // output wire s_axis_tready
           // .s_axis_tdata(inv_data),              // input wire [279 : 0] s_axis_tdata
           // .m_axis_tvalid(o_valid),            // output wire m_axis_tvalid
           // .m_axis_tready(i_ready),            // input wire m_axis_tready
           // .m_axis_tdata(o_data),              // output wire [279 : 0] m_axis_tdata
           // .axis_wr_data_count(),  // output wire [31 : 0] axis_wr_data_count
           // .axis_rd_data_count()  // output wire [31 : 0] axis_rd_data_count
           // );
            
            fpAddSub addSub (
            .aclk(~clk),                                        // input wire aclk
            .aresetn(rstn),                            // input wire aresetn
            .s_axis_a_tvalid(s_axis_a_tvalid_addSub),                  // input wire s_axis_a_tvalid
            .s_axis_a_tready(s_axis_a_tready_addSub),                  // output wire s_axis_a_tready
            .s_axis_a_tdata(s_axis_a_tdata_addSub),                    // input wire [31 : 0] s_axis_a_tdata
            .s_axis_b_tvalid(s_axis_b_tvalid_addSub),                  // input wire s_axis_b_tvalid
            .s_axis_b_tready(s_axis_b_tready_addSub),                  // output wire s_axis_b_tready
            .s_axis_b_tdata(s_axis_b_tdata_addSub),                    // input wire [31 : 0] s_axis_b_tdata
            .s_axis_operation_tvalid(s_axis_operation_tvalid_addSub),  // input wire s_axis_operation_tvalid
            .s_axis_operation_tready(s_axis_operation_tready_addSub),  // output wire s_axis_operation_tready
            .s_axis_operation_tdata(s_axis_operation_tdata_addSub),    // input wire [7 : 0] s_axis_operation_tdata
            .m_axis_result_tvalid(m_axis_result_tvalid_addSub),        // output wire m_axis_result_tvalid
            .m_axis_result_tready(m_axis_result_tready_addSub),        // input wire m_axis_result_tready
            .m_axis_result_tdata(m_axis_result_tdata_addSub)          // output wire [31 : 0] m_axis_result_tdata
            );
            
            fpMul fpMul (
            .aclk(~clk),                                  // input wire aclk
            .aresetn(rstn),                            // input wire aresetn
            .s_axis_a_tvalid(s_axis_a_tvalid_mul),            // input wire s_axis_a_tvalid
            .s_axis_a_tready(s_axis_a_tready_mul),            // output wire s_axis_a_tready
            .s_axis_a_tdata(s_axis_a_tdata_mul),              // input wire [31 : 0] s_axis_a_tdata
            .s_axis_b_tvalid(s_axis_b_tvalid_mul),            // input wire s_axis_b_tvalid
            .s_axis_b_tready(s_axis_b_tready_mul),            // output wire s_axis_b_tready
            .s_axis_b_tdata(s_axis_b_tdata_mul),              // input wire [31 : 0] s_axis_b_tdata
            .m_axis_result_tvalid(m_axis_result_tvalid_mul),  // output wire m_axis_result_tvalid
            .m_axis_result_tready(m_axis_result_tready_mul),  // input wire m_axis_result_tready
            .m_axis_result_tdata(m_axis_result_tdata_mul)    // output wire [31 : 0] m_axis_result_tdata
            );
            
endmodule