`timescale 1ns/1ps

module alu_testbench;

    parameter N = 8;

    reg [N-1:0]  OPA, OPB;
    reg          CLK, RST, CE, MODE, CIN;
    reg [1:0]    IN_VAL;
    reg [3:0]    CMD;
    

    
    wire [(2*N)-1:0] RES_dut;
    wire             COUT_dut, OFLOW_dut, G_dut, E_dut, L_dut, ERR_dut;

   
    wire [(2*N)-1:0] RES_ref;
    wire             COUT_ref, OFLOW_ref, G_ref, E_ref, L_ref, ERR_ref;

    
    integer pass_count = 0;
    integer fail_count = 0;
    integer test_count = 0;

    
    alu_design #(.N(N)) dut (
        .clk  (CLK),   .rst  (RST),    .c_in (CIN),
        .ce   (CE),    .mode (MODE),   .in_val(IN_VAL),
        .opa  (OPA),   .opb  (OPB),    .cmd  (CMD),
        .c_out(COUT_dut), .oflow(OFLOW_dut), .res(RES_dut),
        .G(G_dut), .E(E_dut), .L(L_dut), .err(ERR_dut)
    );

    
    alu_ref_mod #(.N(N)) ref_mod (
        .clk  (CLK),   .rst  (~RST),   .c_in (CIN),
        .ce   (CE),    .mode (MODE),   .in_val(IN_VAL),
        .opa  (OPA),   .opb  (OPB),    .cmd  (CMD),
        .c_out(COUT_ref), .oflow(OFLOW_ref), .res(RES_ref),
        .G(G_ref), .E(E_ref), .L(L_ref), .err(ERR_ref)
    );

    
    initial CLK = 0;
    always #5 CLK = ~CLK;

    
    initial begin
        $dumpfile("alu_test.vcd");
        $dumpvars(0, alu_testbench);
    end

    
    initial begin
        RST    = 1;
        CE     = 0;
        CIN    = 0;
        OPA    = 0;
        OPB    = 0;
        MODE   = 0;
        CMD    = 0;
        IN_VAL = 2'b11;

        repeat(3) @(posedge CLK);
        RST = 0;
        CE  = 1;
        repeat(2) @(posedge CLK);

       
        $display("\n=== DIRECT CASES ===");

        

        $display("\n--- RST: Async Assert/Deassert (ID2) ---");
        test_rst_async;

        $display("\n--- RST during ALU operation (ID3) ---");
        test_rst_during_op;

        $display("\n--- CE enable / disable (ID4, ID5) ---");
        test_ce;

        $display("\n--- Arithmetic Operations MODE=1 (ID6-21) ---");
        MODE = 1;
        test_arithmetic_direct;

        $display("\n--- Logical Operations MODE=0 (ID22-35) ---");
        MODE = 0;
        test_logical_direct;

        $display("\n--- IN_VAL tests (ID36-40) ---");
        test_in_val;

        
        $display("\n=== CORNER CASES ===");
        MODE = 1;
        test_corner_cases;

        
        $display("\n=== ERROR CASES ===");
        test_error_cases;

        
        $display("\n=============================");
        $display("  TOTAL : %0d", test_count);
        $display("  PASS  : %0d", pass_count);
        $display("  FAIL  : %0d", fail_count);
        $display("=============================");

        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***\n");
        else
            $display("*** SOME TESTS FAILED ***\n");

        #50;
        $finish;
    end

    
    task test_rst_async;
        begin
            
            MODE = 1; OPA = 8'hAA; OPB = 8'hBB;
            CMD = 4'b0000; IN_VAL = 2'b11;
            #3; 
            RST = 1;
            #2;  
            test_count = test_count + 1;
            if (RES_dut === 0 && ERR_dut === 0 && OFLOW_dut === 0 &&
                G_dut === 0 && L_dut === 0 && E_dut === 0) begin
                $display("[PASS] RST async assert all outputs zero immediately");
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] RST async assert  outputs not zeroed");
                display_mismatch;
                fail_count = fail_count + 1;
            end
            @(posedge CLK);
            RST = 0;
            repeat(2) @(posedge CLK);

            
            apply_test(8'h0F, 8'h01, 4'b0000, 2'b11, 0, "RST deassert then ADD");
        end
    endtask

    
    task test_rst_during_op;
        begin
            MODE = 1;
            apply_test(8'hAA, 8'hBB, 4'b0000, 2'b11, 0, "pre-rst ADD");
            
            @(posedge CLK);
            OPA = 8'hDE; OPB = 8'hAD; CMD = 4'b0000; IN_VAL = 2'b11;
            @(posedge CLK); 
            RST = 1;        
            repeat(2) @(posedge CLK);
            test_count = test_count + 1;
            if (RES_dut === 0 && ERR_dut === 0) begin
                $display("[PASS] RST during op  operation aborted, outputs reset");
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] RST during op  DUT res=%h err=%b (expected 0,0)",
                          RES_dut, ERR_dut);
                fail_count = fail_count + 1;
            end
            RST = 0;
            repeat(2) @(posedge CLK);
            apply_test(8'h0F, 8'h01, 4'b0000, 2'b11, 0, "post-rst op");
        end
    endtask

    
    task test_ce;
        reg [(2*N)-1:0] held_res;
        reg             held_err, held_oflow, held_G, held_L, held_E;
        begin
            MODE = 1;
       
            CE = 1;
            apply_test(8'h0F, 8'h01, 4'b0000, 2'b11, 0, "CE=1 ADD executes");

            
            held_res   = RES_dut;
            held_err   = ERR_dut;
            held_oflow = OFLOW_dut;
            held_G     = G_dut;
            held_L     = L_dut;
            held_E     = E_dut;

            CE = 0;
            
            @(negedge CLK);
            OPA = 8'hAA; OPB = 8'hBB; CMD = 4'b0000; IN_VAL = 2'b11;
            @(posedge CLK);
            @(posedge CLK);
            #1;

            test_count = test_count + 1;
            if (RES_dut === held_res && ERR_dut === held_err &&
                OFLOW_dut === held_oflow && G_dut === held_G &&
                L_dut === held_L && E_dut === held_E) begin
                $display("[PASS] %-35s OPA=aa OPB=bb CMD=0000 MODE=1 IN_VAL=11",
                         "CE=0 output holds");
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %-35s OPA=aa OPB=bb CMD=0000 MODE=1 IN_VAL=11",
                         "CE=0 output holds");
                $display("  DUT changed: res=%h err=%b (held: res=%h err=%b)",
                         RES_dut, ERR_dut, held_res, held_err);
                fail_count = fail_count + 1;
            end
            CE = 1;
            repeat(2) @(posedge CLK); 
        end
    endtask

    
    task test_arithmetic_direct;
        begin
            // ID6: ADD cmd0  OPA+OPB, check Cout
            apply_test(8'h0F, 8'h01, 4'b0000, 2'b11, 0, "ADD normal");
            apply_test(8'hFF, 8'h01, 4'b0000, 2'b11, 0, "ADD carry out");
            apply_test(8'h00, 8'h00, 4'b0000, 2'b11, 0, "ADD zero");

            // ID7: SUB cmd1  OPA-OPB, check Oflow when OPA<OPB
            apply_test(8'h20, 8'h10, 4'b0001, 2'b11, 0, "SUB normal");
            apply_test(8'h10, 8'h20, 4'b0001, 2'b11, 0, "SUB underflow->oflow");
            apply_test(8'h00, 8'h00, 4'b0001, 2'b11, 0, "SUB zero");

            // ID8: ADD_CIN cmd2, Cin=0
            apply_test(8'hFF, 8'h00, 4'b0010, 2'b11, 0, "ADD_CIN Cin=0");
            // ID8: ADD_CIN cmd2, Cin=1
            apply_test(8'hFF, 8'h00, 4'b0010, 2'b11, 1, "ADD_CIN Cin=1 carry");
            apply_test(8'h10, 8'h20, 4'b0010, 2'b11, 1, "ADD_CIN c=1 normal");
            apply_test(8'h00, 8'h00, 4'b0010, 2'b11, 0, "ADD_CIN zero");

            // ID9: SUB_CIN cmd3, Cin=0 and Cin=1
            apply_test(8'h20, 8'h10, 4'b0011, 2'b11, 0, "SUB_BOR Cin=0");
            apply_test(8'h0F, 8'h01, 4'b0011, 2'b11, 1, "SUB_BOR Cin=1");
            apply_test(8'h01, 8'h0F, 4'b0011, 2'b11, 1, "SUB_BOR underflow");

            // ID11: INC A cmd4
            apply_test(8'h0A, 8'h00, 4'b0100, 2'b11, 0, "INC_OPA normal");
            apply_test(8'h0A, 8'h00, 4'b0100, 2'b01, 0, "INC_OPA iv=01");

            // ID12: DEC A cmd5
            apply_test(8'h0A, 8'h00, 4'b0101, 2'b11, 0, "DEC_OPA normal");
            apply_test(8'h0A, 8'h00, 4'b0101, 2'b01, 0, "DEC_OPA iv=01");

            // ID13: INC B cmd6
            apply_test(8'h00, 8'h0A, 4'b0110, 2'b11, 0, "INC_OPB normal");
            apply_test(8'h00, 8'h0A, 4'b0110, 2'b10, 0, "INC_OPB iv=10");

            // ID14: DEC B cmd7
            apply_test(8'h00, 8'h0A, 4'b0111, 2'b11, 0, "DEC_OPB normal");
            apply_test(8'h00, 8'h0A, 4'b0111, 2'b10, 0, "DEC_OPB iv=10");

            // ID15/16/17: COMPARE cmd8  G, L, E
            apply_test(8'hFF, 8'h01, 4'b1000, 2'b11, 0, "CMP OPA>OPB -> G");
            apply_test(8'h01, 8'hFF, 4'b1000, 2'b11, 0, "CMP OPA<OPB -> L");
            apply_test(8'hAA, 8'hAA, 4'b1000, 2'b11, 0, "CMP OPA==OPB -> E");
            apply_test(8'h00, 8'h00, 4'b1000, 2'b11, 0, "CMP zero equal -> E");

            // ID18: MUL cmd9  2-cycle (REF has 2 internal @posedge)
            apply_test_2cycle(8'h02, 8'h03, 4'b1001, 2'b11, 0, "MUL (3)*(4)=12");
            apply_test_2cycle(8'h00, 8'h00, 4'b1001, 2'b11, 0, "MUL 1*1=1");
            apply_test_2cycle(8'hFF, 8'hFF, 4'b1001, 2'b11, 0, "MUL max");

            // ID19: MUL_SHL cmd10  2-cycle
            apply_test_2cycle(8'h02, 8'h03, 4'b1010, 2'b11, 0, "MUL_SHL normal");
            apply_test_2cycle(8'hFF, 8'hFF, 4'b1010, 2'b11, 0, "MUL_SHL max");

            // Flush: run a clean ADD so stale MUL ans doesn't bleed into SADD/SSUB
            apply_test(8'h00, 8'h00, 4'b0000, 2'b11, 0, "FLUSH after MUL");

            // ID20: SIGNED ADD cmd11  check Oflow
            apply_test(8'h3F, 8'h3F, 4'b1011, 2'b11, 0, "SADD +ve overflow");
            apply_test(8'hC0, 8'hC0, 4'b1011, 2'b11, 0, "SADD -ve overflow");
            apply_test(8'h01, 8'hFF, 4'b1011, 2'b11, 0, "SADD +1+(-1)=0");
            apply_test(8'h00, 8'h00, 4'b1011, 2'b11, 0, "SADD zero");

            // ID21: SIGNED SUB cmd12  check Oflow
            apply_test(8'h7F, 8'hFF, 4'b1100, 2'b11, 0, "SSUB max-(-1)");
            apply_test(8'h00, 8'h01, 4'b1100, 2'b11, 0, "SSUB 0-1");
            apply_test(8'h80, 8'h01, 4'b1100, 2'b11, 0, "SSUB min overflow");
        end
    endtask

    
    task test_logical_direct;
        begin
            // ID22: AND cmd0
            apply_test(8'hFF, 8'h0F, 4'b0000, 2'b11, 0, "AND normal");
            apply_test(8'h00, 8'hFF, 4'b0000, 2'b11, 0, "AND zero");

            // ID23: NAND cmd1
            apply_test(8'hFF, 8'hFF, 4'b0001, 2'b11, 0, "NAND all ones");
            apply_test(8'h00, 8'h00, 4'b0001, 2'b11, 0, "NAND zero");

            // ID24: OR cmd2
            apply_test(8'hF0, 8'h0F, 4'b0010, 2'b11, 0, "OR normal");
            apply_test(8'h00, 8'h00, 4'b0010, 2'b11, 0, "OR zero");

            // ID25: NOR cmd3
            apply_test(8'h00, 8'h00, 4'b0011, 2'b11, 0, "NOR zero");
            apply_test(8'hFF, 8'hFF, 4'b0011, 2'b11, 0, "NOR all ones");

            // ID26: XOR cmd4
            apply_test(8'hFF, 8'hFF, 4'b0100, 2'b11, 0, "XOR same->0");
            apply_test(8'hAA, 8'h55, 4'b0100, 2'b11, 0, "XOR->FF");

            // ID27: XNOR cmd5
            apply_test(8'hFF, 8'hFF, 4'b0101, 2'b11, 0, "XNOR same->FF");
            apply_test(8'hAA, 8'h55, 4'b0101, 2'b11, 0, "XNOR->00");

            // ID28: NOT OPA cmd6  valid in_val=01 or 11
            apply_test(8'hAA, 8'h00, 4'b0110, 2'b01, 0, "NOT_OPA iv=01");
            apply_test(8'h00, 8'h00, 4'b0110, 2'b11, 0, "NOT_OPA iv=11");

            // ID29: NOT OPB cmd7  valid in_val=10 or 11
            apply_test(8'h00, 8'hAA, 4'b0111, 2'b10, 0, "NOT_OPB iv=10");
            apply_test(8'h00, 8'hFF, 4'b0111, 2'b11, 0, "NOT_OPB iv=11");

            // ID30: SHR OPA cmd8
            apply_test(8'hAA, 8'h00, 4'b1000, 2'b11, 0, "SHR_OPA normal");
            apply_test(8'h01, 8'h00, 4'b1000, 2'b01, 0, "SHR_OPA LSB drop");

            // ID31: SHL OPA cmd9
            apply_test(8'hAA, 8'h00, 4'b1001, 2'b11, 0, "SHL_OPA normal");
            apply_test(8'h80, 8'h00, 4'b1001, 2'b01, 0, "SHL_OPA MSB drop");

            // ID32: SHR OPB cmd10
            apply_test(8'h00, 8'hAA, 4'b1010, 2'b11, 0, "SHR_OPB normal");
            apply_test(8'h00, 8'h01, 4'b1010, 2'b10, 0, "SHR_OPB LSB drop");

            // ID33: SHL OPB cmd11
            apply_test(8'h00, 8'hAA, 4'b1011, 2'b11, 0, "SHL_OPB normal");
            apply_test(8'h00, 8'h80, 4'b1011, 2'b10, 0, "SHL_OPB MSB drop");

            // ID34: ROL cmd12  OPB[N-1:clog2(N)-1]==0, use OPB[clog2(N)-1:0]
            apply_test(8'hAA, 8'h01, 4'b1100, 2'b11, 0, "ROL by 1");
            apply_test(8'hAA, 8'h04, 4'b1100, 2'b11, 0, "ROL by 4");
            apply_test(8'hAA, 8'h00, 4'b1100, 2'b11, 0, "ROL by 0->same");
            apply_test(8'h01, 8'h01, 4'b1100, 2'b11, 0, "ROL 0x01 by 1->0x02");

            // ID35: ROR cmd13
            apply_test(8'hAA, 8'h01, 4'b1101, 2'b11, 0, "ROR by 1");
            apply_test(8'hAA, 8'h04, 4'b1101, 2'b11, 0, "ROR by 4");
            apply_test(8'hAA, 8'h00, 4'b1101, 2'b11, 0, "ROR by 0->same");
            apply_test(8'h80, 8'h01, 4'b1101, 2'b11, 0, "ROR 0x80 by 1->0x40");
        end
    endtask

    
    task test_in_val;
        begin
            // ID36: IN_VAL=1 (2'b01)  MODE_high, cmd4 and cmd5 (INC/DEC A, valid)
            MODE = 1;
            apply_test(8'h0A, 8'h00, 4'b0100, 2'b01, 0, "IV=1 MODE1 cmd4 INC_A ok");
            apply_test(8'h0A, 8'h00, 4'b0101, 2'b01, 0, "IV=1 MODE1 cmd5 DEC_A ok");

            // ID37: IN_VAL=2 (2'b10)  MODE_high, cmd6 and cmd7 (INC/DEC B, valid)
            apply_test(8'h00, 8'h0A, 4'b0110, 2'b10, 0, "IV=2 MODE1 cmd6 INC_B ok");
            apply_test(8'h00, 8'h0A, 4'b0111, 2'b10, 0, "IV=2 MODE1 cmd7 DEC_B ok");

            // ID38: IN_VAL=1  MODE_low, cmd6/8/9 (NOT_OPA, SHR_OPA, SHL_OPA)
            MODE = 0;
            apply_test(8'hAA, 8'h00, 4'b0110, 2'b01, 0, "IV=1 MODE0 cmd6 NOT_A ok");
            apply_test(8'hAA, 8'h00, 4'b1000, 2'b01, 0, "IV=1 MODE0 cmd8 SHR_A ok");
            apply_test(8'hAA, 8'h00, 4'b1001, 2'b01, 0, "IV=1 MODE0 cmd9 SHL_A ok");

            // ID39: IN_VAL=2  MODE_low, cmd7/10/11 (NOT_OPB, SHR_OPB, SHL_OPB)
            apply_test(8'h00, 8'hAA, 4'b0111, 2'b10, 0, "IV=2 MODE0 cmd7 NOT_B ok");
            apply_test(8'h00, 8'hAA, 4'b1010, 2'b10, 0, "IV=2 MODE0 cmd10 SHR_B ok");
            apply_test(8'h00, 8'hAA, 4'b1011, 2'b10, 0, "IV=2 MODE0 cmd11 SHL_B ok");

            // ID40: IN_VAL=3 (2'b11)  all operations (double operand)
            MODE = 1;
            apply_test(8'h0F, 8'h01, 4'b0000, 2'b11, 0, "IV=3 MODE1 ADD ok");
            MODE = 0;
            apply_test(8'hFF, 8'h0F, 4'b0000, 2'b11, 0, "IV=3 MODE0 AND ok");
        end
    endtask

    
    task test_corner_cases;
        begin
            MODE = 1;
            // CC1: ADD 255+1 ? res=0, Cout set
            apply_test(8'hFF, 8'h01, 4'b0000, 2'b11, 0, "CC ADD 255+1=0 Cout=1");
            // CC2: ADD 0+0 ? res=0, Cout=0
            apply_test(8'h00, 8'h00, 4'b0000, 2'b11, 0, "CC ADD 0+0=0 Cout=0");
            // CC3: ADD 255+255 ? res=254, Cout=1
            apply_test(8'hFF, 8'hFF, 4'b0000, 2'b11, 0, "CC ADD 255+255 Cout=1");

            // CC4: SUB 0-255 ? oflow=1
            apply_test(8'h00, 8'hFF, 4'b0001, 2'b11, 0, "CC SUB 0-255 oflow=1");
            // CC5: SUB 0-0 ? res=0, oflow=0
            apply_test(8'h00, 8'h00, 4'b0001, 2'b11, 0, "CC SUB 0-0=0 oflow=0");
            // CC6: SUB 255-255 ? res=0, oflow=0
            apply_test(8'hFF, 8'hFF, 4'b0001, 2'b11, 0, "CC SUB 255-255=0 oflow=0");

            // CC7: ADD_CIN 255+0+1 ? res=0, Cout=1
            apply_test(8'hFF, 8'h00, 4'b0010, 2'b11, 1, "CC ADD_CIN 255+0+1=0 Cout=1");
            // CC8: ADD_CIN 255+255+1 ? res=255, Cout=1
            apply_test(8'hFF, 8'hFF, 4'b0010, 2'b11, 1, "CC ADD_CIN 255+255+1=255");

            // CC9: SUB_CIN 0-255-1 ? oflow=1
            apply_test(8'h00, 8'hFF, 4'b0011, 2'b11, 1, "CC SUB_CIN 0-255-1 oflow=1");
            // CC10: SUB_CIN 255-255-1 ? oflow=1, res=255
            apply_test(8'hFF, 8'hFF, 4'b0011, 2'b11, 1, "CC SUB_CIN 255-255-1 oflow=1");

            // CC11: INC_OPA 255 ? wraps to 0
            apply_test(8'hFF, 8'h00, 4'b0100, 2'b11, 0, "CC INC_OPA 255 wrap->0");
            apply_test(8'hFF, 8'h00, 4'b0100, 2'b01, 0, "CC INC_OPA iv=01 wrap->0");

            // CC12: DEC_OPA 0 ? wraps to 255
            apply_test(8'h00, 8'h00, 4'b0101, 2'b11, 0, "CC DEC_OPA 0 wrap->255");
            apply_test(8'h00, 8'h00, 4'b0101, 2'b01, 0, "CC DEC_OPA iv=01 wrap->255");

            // CC13: INC_OPB 255 ? wraps to 0
            apply_test(8'h00, 8'hFF, 4'b0110, 2'b11, 0, "CC INC_OPB 255 wrap->0");
            apply_test(8'h00, 8'hFF, 4'b0110, 2'b10, 0, "CC INC_OPB iv=10 wrap->0");

            // CC14: DEC_OPB 0 ? wraps to 255
            apply_test(8'h00, 8'h00, 4'b0111, 2'b11, 0, "CC DEC_OPB 0 wrap->255");
            apply_test(8'h00, 8'h00, 4'b0111, 2'b10, 0, "CC DEC_OPB iv=10 wrap->255");

            // CC15-17: MUL cmd9  2-cycle each
            apply_test_2cycle(8'h01, 8'h02, 4'b1001, 2'b11, 0, "CC MUL pipeline input1");
            apply_test_2cycle(8'h03, 8'h04, 4'b1001, 2'b11, 0, "CC MUL pipeline input2");
            apply_test_2cycle(8'h05, 8'h06, 4'b1001, 2'b11, 0, "CC MUL pipeline input3");

            // CC18-20: MUL_SHL cmd10  2-cycle each
            apply_test_2cycle(8'h01, 8'h02, 4'b1010, 2'b11, 0, "CC MUL_SHL pipeline input1");
            apply_test_2cycle(8'h03, 8'h04, 4'b1010, 2'b11, 0, "CC MUL_SHL pipeline input2");
            apply_test_2cycle(8'h01, 8'h01, 4'b1010, 2'b11, 0, "CC MUL_SHL 1 input");

            // Flush: clean ADD so stale MUL ans doesn't bleed into SADD/SSUB
            apply_test(8'h00, 8'h00, 4'b0000, 2'b11, 0, "CC FLUSH after MUL");

            // CC21: SADD 127+1 ? oflow=1 (positive overflow)
            apply_test(8'h7F, 8'h01, 4'b1011, 2'b11, 0, "CC SADD 127+1 oflow=1");
            // CC22: SSUB -128-1 ? oflow=1
            apply_test(8'h80, 8'h01, 4'b1100, 2'b11, 0, "CC SSUB -128-1 oflow=1");

            // CC23: Mode change mid-stream  priority to new cmd
            MODE = 0;
            apply_test(8'hFF, 8'h0F, 4'b0000, 2'b11, 0, "CC mode->0 AND");
            MODE = 1;
            apply_test(8'hFF, 8'h0F, 4'b0000, 2'b11, 0, "CC mode->1 ADD same inputs");

            // CC24: Mode1 change cmd_same  output based on updated mode cmd
            MODE = 1;
            apply_test(8'h0F, 8'h01, 4'b0000, 2'b11, 0, "CC MODE1 cmd0 ADD");
            apply_test(8'h0F, 8'h01, 4'b0001, 2'b11, 0, "CC MODE1 cmd1 SUB same operands");

            // CC25: Mode0 cmd change
            MODE = 0;
            apply_test(8'hF0, 8'h0F, 4'b0010, 2'b11, 0, "CC MODE0 cmd2 OR");
            apply_test(8'hF0, 8'h0F, 4'b0100, 2'b11, 0, "CC MODE0 cmd4 XOR same operands");
        end
    endtask

    
    task test_error_cases;
        begin
            // EC1: IN_VAL=0  no operation, both OPA & OPB invalid ? err=1, res=0
            MODE = 1;
            apply_test(8'hAA, 8'hBB, 4'b0000, 2'b00, 0, "EC IN_VAL=0 MODE1 ADD->err");
            MODE = 0;
            apply_test(8'hAA, 8'hBB, 4'b0000, 2'b00, 0, "EC IN_VAL=0 MODE0 AND->err");

            // EC2: IN_VAL=1, MODE_high, cmd other than 4 & 5 ? err=1
            MODE = 1;
            apply_test(8'hAA, 8'hBB, 4'b0000, 2'b01, 0, "EC IV=1 MODE1 cmd0 ADD->err");
            apply_test(8'hAA, 8'hBB, 4'b0001, 2'b01, 0, "EC IV=1 MODE1 cmd1 SUB->err");
            apply_test(8'hAA, 8'hBB, 4'b0010, 2'b01, 0, "EC IV=1 MODE1 cmd2->err");
            apply_test(8'hAA, 8'hBB, 4'b0011, 2'b01, 0, "EC IV=1 MODE1 cmd3->err");
            apply_test(8'hAA, 8'hBB, 4'b0110, 2'b01, 0, "EC IV=1 MODE1 cmd6->err");
            apply_test(8'hAA, 8'hBB, 4'b1000, 2'b01, 0, "EC IV=1 MODE1 cmd8 CMP->err");
            apply_test(8'hAA, 8'hBB, 4'b1001, 2'b01, 0, "EC IV=1 MODE1 cmd9 MUL->err");

            // EC3: IN_VAL=2, MODE_high, cmd other than 6 & 7 ? err=1
            apply_test(8'hAA, 8'hBB, 4'b0000, 2'b10, 0, "EC IV=2 MODE1 cmd0 ADD->err");
            apply_test(8'hAA, 8'hBB, 4'b0001, 2'b10, 0, "EC IV=2 MODE1 cmd1 SUB->err");
            apply_test(8'hAA, 8'hBB, 4'b0100, 2'b10, 0, "EC IV=2 MODE1 cmd4->err");
            apply_test(8'hAA, 8'hBB, 4'b0101, 2'b10, 0, "EC IV=2 MODE1 cmd5->err");
            apply_test(8'hAA, 8'hBB, 4'b1000, 2'b10, 0, "EC IV=2 MODE1 cmd8 CMP->err");

            // EC4: IN_VAL=1, MODE_low, cmd other than 6, 8, 9 ? err=1
            MODE = 0;
            apply_test(8'hAA, 8'hBB, 4'b0000, 2'b01, 0, "EC IV=1 MODE0 cmd0 AND->err");
            apply_test(8'hAA, 8'hBB, 4'b0001, 2'b01, 0, "EC IV=1 MODE0 cmd1 NAND->err");
            apply_test(8'hAA, 8'hBB, 4'b0111, 2'b01, 0, "EC IV=1 MODE0 cmd7 NOT_B->err");
            apply_test(8'hAA, 8'hBB, 4'b1010, 2'b01, 0, "EC IV=1 MODE0 cmd10 SHR_B->err");
            apply_test(8'hAA, 8'hBB, 4'b1011, 2'b01, 0, "EC IV=1 MODE0 cmd11 SHL_B->err");
            apply_test(8'hAA, 8'h01, 4'b1101, 2'b01, 0, "EC IV=1 MODE0 cmd13 ROR->err");

            // EC5: IN_VAL=2, MODE_low, cmd other than 7, 10, 11 ? err=1
            apply_test(8'hAA, 8'hBB, 4'b0000, 2'b10, 0, "EC IV=2 MODE0 cmd0 AND->err");
            apply_test(8'hAA, 8'hBB, 4'b0001, 2'b10, 0, "EC IV=2 MODE0 cmd1 NAND->err");
            apply_test(8'hAA, 8'hBB, 4'b0110, 2'b10, 0, "EC IV=2 MODE0 cmd6 NOT_A->err");
            apply_test(8'hAA, 8'hBB, 4'b1000, 2'b10, 0, "EC IV=2 MODE0 cmd8 SHR_A->err");
            apply_test(8'hAA, 8'hBB, 4'b1001, 2'b10, 0, "EC IV=2 MODE0 cmd9 SHL_A->err");
            apply_test(8'hAA, 8'h01, 4'b1100, 2'b10, 0, "EC IV=2 MODE0 cmd12 ROL->err");

            // EC6: ROL  OPB[N-1:clog2(N)-1] != 0 ? err=1, res=0
            MODE = 0;
            apply_test(8'hAA, 8'hFF, 4'b1100, 2'b11, 0, "EC ROL OPB=FF out-of-range->err");
            apply_test(8'hAA, 8'h08, 4'b1100, 2'b11, 0, "EC ROL OPB=8 out-of-range->err");

            // EC7: ROR  OPB[N-1:clog2(N)-1] != 0 ? err=1, res=0
            apply_test(8'hAA, 8'hFF, 4'b1101, 2'b11, 0, "EC ROR OPB=FF out-of-range->err");
            apply_test(8'hAA, 8'h08, 4'b1101, 2'b11, 0, "EC ROR OPB=8 out-of-range->err");

            // EC8: MODE_low cmd14, cmd15, cmd16  out of range (no case) ? err/res=0
            apply_test(8'hAA, 8'hBB, 4'b1110, 2'b11, 0, "EC MODE0 cmd14 out-of-range");
            apply_test(8'hAA, 8'hBB, 4'b1111, 2'b11, 0, "EC MODE0 cmd15 out-of-range");

            // EC9: MODE_high cmd13, cmd14, cmd15, cmd16  out of range
            MODE = 1;
            apply_test(8'hAA, 8'hBB, 4'b1101, 2'b11, 0, "EC MODE1 cmd13 out-of-range");
            apply_test(8'hAA, 8'hBB, 4'b1110, 2'b11, 0, "EC MODE1 cmd14 out-of-range");
            apply_test(8'hAA, 8'hBB, 4'b1111, 2'b11, 0, "EC MODE1 cmd15 out-of-range");

            // EC10: MODE changes to 1 for cmd13 ? {1,1101}=29, no case in either model
            // Both DUT and REF hold previous res  only check err=0 (no err flagged)
            MODE = 0;
            apply_test(8'hAA, 8'h01, 4'b1101, 2'b11, 0, "EC MODE0->1 cmd13 baseline");
            MODE = 1;
            // Don't use apply_test here  res is undefined in both; just check no crash
            @(negedge CLK);
            OPA = 8'hAA; OPB = 8'h01; CMD = 4'b1101; IN_VAL = 2'b11; CIN = 0;
            @(posedge CLK); @(posedge CLK); #1;
            test_count = test_count + 1;
            // Both models have no case for {MODE=1,CMD=1101}  res is don't-care
            // Only verify ERR matches between DUT and REF
            if (ERR_dut === ERR_ref) begin
                $display("[PASS] %-35s OPA=aa OPB=01 CMD=1101 MODE=1 IN_VAL=11",
                         "EC MODE1 cmd13 -> err/default");
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %-35s OPA=aa OPB=01 CMD=1101 MODE=1 IN_VAL=11",
                         "EC MODE1 cmd13 -> err/default");
                $display("  DUT err=%b  REF err=%b", ERR_dut, ERR_ref);
                fail_count = fail_count + 1;
            end
        end
    endtask

    
    task apply_test(
        input [N-1:0]  a, b,
        input [3:0]    c,
        input [1:0]    iv,
        input          ci,
        input [80*8:1] test_name
    );
        begin
            @(negedge CLK);   // apply inputs at negedge  stable before next posedge
            OPA    = a;
            OPB    = b;
            CMD    = c;
            IN_VAL = iv;
            CIN    = ci;

            @(posedge CLK);   // posedge #1  REF wakes, suspends on internal @posedge
            @(posedge CLK);   // posedge #2  REF computes result, DUT output ready
            #1;               // settle after clock edge

            test_count = test_count + 1;

            if (compare_outputs(1'b0)) begin
                $display("[PASS] %-35s OPA=%h OPB=%h CMD=%b MODE=%b IN_VAL=%b",
                          test_name, a, b, c, MODE, iv);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %-35s OPA=%h OPB=%h CMD=%b MODE=%b IN_VAL=%b",
                          test_name, a, b, c, MODE, iv);
                display_mismatch;
                fail_count = fail_count + 1;
            end
        end
    endtask


    
    task apply_test_2cycle(
        input [N-1:0]  a, b,
        input [3:0]    c,
        input [1:0]    iv,
        input          ci,
        input [80*8:1] test_name
    );
        begin
            @(negedge CLK);   // apply at negedge  stable before next posedge
            OPA    = a;
            OPB    = b;
            CMD    = c;
            IN_VAL = iv;
            CIN    = ci;

            @(posedge CLK);   // posedge #1  REF wakes, hits first internal @posedge
            @(posedge CLK);   // posedge #2  REF sets res='bx
            @(posedge CLK);   // posedge #3  REF sets final result, DUT output ready
            #1;

            test_count = test_count + 1;
            if (compare_outputs(1'b0)) begin
                $display("[PASS] %-35s OPA=%h OPB=%h CMD=%b MODE=%b IN_VAL=%b",
                          test_name, a, b, c, MODE, iv);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %-35s OPA=%h OPB=%h CMD=%b MODE=%b IN_VAL=%b",
                          test_name, a, b, c, MODE, iv);
                display_mismatch;
                fail_count = fail_count + 1;
            end
        end
    endtask

    
    function compare_outputs;
        input dummy;
        begin
            compare_outputs = 1;
            if (RES_dut[2*N-1:0] !== RES_ref)  compare_outputs = 0;
            if (ERR_dut   !== ERR_ref)           compare_outputs = 0;
            if (OFLOW_dut !== OFLOW_ref)         compare_outputs = 0;
            if(COUT_dut !== COUT_dut)            compare_outputs = 0;
            if (G_dut     !== G_ref)             compare_outputs = 0;
            if (L_dut     !== L_ref)             compare_outputs = 0;
            if (E_dut     !== E_ref)             compare_outputs = 0;
        end
    endfunction

   
    task display_mismatch;
        begin
            $display("  DUT: res=%h oflow=%b cout=%b G=%b L=%b E=%b err=%b",
                     RES_dut[2*N-1:0], OFLOW_dut, COUT_dut,
                     G_dut, L_dut, E_dut, ERR_dut);
            $display("  REF: res=%h oflow=%b cout=%b G=%b L=%b E=%b err=%b",
                     RES_ref, OFLOW_ref, COUT_ref,
                     G_ref, L_ref, E_ref, ERR_ref);
        end
    endtask

endmodule



























`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04.05.2026 16:05:04
// Design Name: 
// Module Name: alu_design
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`default_nettype wire
module alu_design#(parameter N = 8)(input clk,rst,c_in,ce,mode, input[1:0]in_val,input [N-1:0]opa,opb, input [3:0]cmd, 
                   output reg oflow,c_out,G,L,E,err, output reg [(2*N)-1:0]res);
            
            reg [(2*N)-1:0]ans,ans1,ans2;
            reg err1,oflow1,c_out1,G1,L1,E1;
            wire[2*N:0] add,sub;
            
            reg [1:0]flag,flag1;
            assign add = $signed(opa) + $signed(opb); 
            assign sub = $signed(opa) - $signed(opb);            
            always @(posedge clk or posedge rst) begin
                if(rst) begin
                    
                    ans <= 0;
                    G1 <= 0;
                    L1 <= 0;
                    E1 <= 0;
                    err1 <= 0;
                    oflow1 <= 0;
                    c_out1 <= 0; 
                    if({mode,cmd} != 5'd25) flag  <= 2'd0;
                    if({mode,cmd} != 5'd26) flag1 <= 2'd0;
                end
                
                else if(ce == 1)begin
                    G1 <= 0;
                    L1 <= 0;
                    E1 <= 0;
                    err1 <= 0;
                    oflow1 <= 0;
                    c_out1 <= 0;
                    if({mode,cmd} != 5'd25) flag  <= 2'd0;
                    if({mode,cmd} != 5'd26) flag1 <= 2'd0;
                    case({mode,cmd})
                        5'd16 : begin 
                                 if(in_val == 2'b11) 
                                 begin 
                                    ans <= opa + opb;
                                    c_out1 <= ans[N];  
                                 end 
                                 else if (in_val != 2'b11) 
                                 begin 
                                 err1 <= 1'b1; ans <= 0;
                                 end 
//                                 else  begin
//                                 res <= res;
//                                 end
                               end
                               
                        5'd17 : begin 
                                 if(in_val == 2'b11) 
                                 begin 
                                    ans <= opa - opb;
                                    if(opa < opb) oflow1 <= 1;
                                    else oflow1 <= 0; 
                                 end 
                                 else if (in_val != 2'b11) 
                                 begin 
                                 err1 <= 1'b1; ans <= 0; 
                                 end 
//                                 else  begin
//                                 res <= res;
//                                 end
                               end

                        5'd18 : begin 
                                 if(in_val == 2'b11) 
                                 begin 
                                    ans <= opa + opb + c_in; 
                                    c_out1 <= ans[N];  
                                 end 
                                 else if (in_val != 2'b11) 
                                 begin 
                                 err1 <= 1'b1; ans <= 0;
                                 end 
//                                 else  begin
//                                 res <= res;
//                                 end
                               end

                       5'd19 : begin 
                                 if(in_val == 2'b11) 
                                 begin 
                                    ans <= (opa - opb) - c_in;
                                    if(opa < (opb+c_in)) oflow1 <= 1;
                                    else oflow1 <= 0;  
                                 end 
                                 else if (in_val != 2'b11) 
                                 begin 
                                 err1 <= 1'b1; ans <= 0; 
                                 end 
//                                 else  begin
//                                 res <= res;
//                                 end 
                               end

                      5'd20 : begin 
                        if(in_val == 2'b11 || in_val == 2'b01) 
                            begin
                                ans <= opa + 1'b1;
                            end
                         else if(in_val == 2'b00 || in_val == 2'b10)
                            begin
                                err1 <= 1'b1; ans <= 0; 
                            end       
//                         else  begin
//                                 res <= res;
//                                 end
                       end
                       
                       
                        5'd21 : begin 
                        if(in_val == 2'b11 || in_val == 2'b01) 
                            begin
                                ans <= opa - 1'b1;
//                                if(opa == 0) oflow1 <= 1;
//                                else oflow1 <= 0;
                            end
                         else if(in_val == 2'b00 || in_val == 2'b10)
                            begin
                                err1 <= 1'b1; ans <= 0;
                            end       
//                         else  begin
//                                 res <= res;
//                                 end
                       end
                       
                       
                       5'd22 : begin 
                        if(in_val == 2'b11 || in_val == 2'b10) 
                            begin
                                ans <= opb + 1'b1; 
                            end
                         else if(in_val == 2'b00 || in_val == 2'b01)
                            begin
                                err1 <= 1'b1; ans <= 0;
                            end       
//                         else  begin
//                                 res <= res;
//                                 end
                       end
                       
                       
                        5'd23 : begin 
                        if(in_val == 2'b11 || in_val == 2'b10) 
                            begin
                                ans <= opb - 1'b1;
//                                if(opb == 0) oflow1 <= 1;
//                                else oflow1 <= 0;
                            end
                         else if(in_val == 2'b00 || in_val == 2'b01)
                            begin
                                err1 <= 1'b1; ans <= 0; 
                            end       
//                         else  begin
//                                 res <= res;
//                                 end
                       end
                       
                       
                       
                       5'd24 : begin 
                        if(in_val == 2'b11) 
                            begin
                                if(opa > opb) G1 <= 1'b1;
                                else if(opb > opa) L1 <=1'b1;
                                else E1 <= 1'b1;
                                ans <= ans;
                            end
                         else if(in_val != 2'b11)
                            begin
                                err1 <= 1'b1; ans <= 0; 
                            end       
//                         else  begin
//                                 res <= res;
//                                 end
                       end
                       
                       
                       5'd25: begin
                        if(in_val == 2'b11)begin
                            ans <= (opa + 1) * (opb + 1);
                            end
                        else if(in_val != 2'b11)begin
                            err1 <= 1'b1; ans <= 0;
                        end
                       end
//                       
                       5'd26: begin
                       
                       if(in_val == 2'b11)begin
                        ans <= (opa << 1) * opb;
                       end
                       
                       else if(in_val != 2'b11)begin
                        err1 <= 1'b1; ans <= 0;
                       end
                        
                       end
                       
                       5'd27: begin
                        if((add[N-1] != opa[N-1]) && (add[N-1] != opb[N-1]))begin
                            ans1 <= add;
                            oflow1 <= 1;
                        end
                        else oflow1 <= 0;
                       end
                       
                       
                       5'd28: begin
                        if((sub[N-1] == opa[N-1]) && (sub[N-1] != opb[N-1]))begin
                            ans1 <= sub;
                            oflow1 <= 1;
                        end
                        else oflow1 <= 0;
                       end
                      
                      //   LOGICAL OPERATIONS 
                       
                       
                       5'd0:begin
                            if(in_val == 2'b11) begin
                                ans <= opa & opb;
                          
                            end
                            else if(in_val != 2'b11)begin
                                err1 <= 1'b1;ans <= 0; 
                            end
//                            else begin
//                                res <= res;
//                            end
                       end
                       
                       
                       
                     5'd1:begin
                            if(in_val == 2'b11) begin
                                ans <= ~(opa & opb);
                            end
                            else if(in_val != 2'b11)begin
                                err1 <= 1'b1;ans <= 0;
                            end
//                            else begin
//                                res <= res;
//                            end
                       end 
                       
                       
                       
                   5'd2:begin
                            if(in_val == 2'b11) begin
                                ans <= (opa | opb);
                              
                            end
                            else if(in_val != 2'b11)begin
                                err1 <= 1'b1;ans <= 0; 
                            end
//                            else begin
//                                res <= res;
//                            end
                       end  
                       
                       
                       
                 5'd3:begin
                            if(in_val == 2'b11) begin
                                ans <= ~(opa | opb);
                                
                            end
                            else if(in_val != 2'b11)begin
                                err1 <= 1'b1;ans <= 0;
                            end
//                            else begin
//                                res <= res;
//                            end
                       end  
                       
                       
                       
                       
                5'd4:begin
                            if(in_val == 2'b11) begin
                                ans <= (opa ^ opb);
                                
                            end
                            else if(in_val != 2'b11)begin
                                err1 <= 1'b1;ans <= 0;
                            end
//                            else begin
//                                res <= res;
//                            end
                       end   
                       
                       
                       
                 5'd5:begin
                            if(in_val == 2'b11) begin
                                ans <= (opa ~^ opb);
                                
                            end
                            else if(in_val != 2'b11)begin
                                err1 <= 1'b1;ans <= 0; 
                            end
//                            else begin
//                                res <= res;
//                            end
                       end  
                       
                       
                       
                       
                5'd6:begin
                            if(in_val == 2'b01 || in_val == 2'b11) begin
                                ans <= ~(opa);
                                
                            end
                            else if(in_val == 2'b10 || in_val == 2'b00)begin
                                err1 <= 1'b1;ans <= 0; 
                            end
//                            else begin
//                                res <= res;
//                            end
                       end 
                       
                       
                       
               5'd7:begin
                            if(in_val == 2'b11 || in_val == 2'b10) begin
                                ans <= ~(opb);
                               
                            end
                            else if(in_val == 2'b00 || in_val == 2'b01)begin
                                err1 <= 1'b1;ans <= 0; 
                            end
//                            else begin
//                                res <= res;
//                            end
                       end  
                       
                       
               5'd8:begin
                            if(in_val == 2'b11 || in_val == 2'b01) begin
                                ans <= opa >> 1;
                                
                            end
                            else if(in_val == 2'b00 || in_val == 2'b10)begin
                                err1 <= 1'b1;ans <= 0; 
                            end
//                            else begin
//                                res <= res;
//                            end
                       end  
                       
                       
              5'd9:begin
                            if(in_val == 2'b11 || in_val == 2'b01) begin
                                ans <= opa << 1;
                                
                            end
                            else if(in_val == 2'b00 || in_val == 2'b10)begin
                                err1 <= 1'b1;ans <= 0; 
                            end
//                            else begin
//                                res <= res;
//                            end
                       end
                       
                       
               5'd10:begin
                            if(in_val == 2'b11 || in_val == 2'b10) begin
                                ans <= opb >> 1;
                                
                            end
                            else if(in_val == 2'b00 || in_val == 2'b01)begin
                                err1 <= 1'b1;ans <= 0; 
                            end
//                            else begin
//                                res <= res;
//                            end
                       end    
                       
                       
                       
                       
               5'd11:begin
                            if(in_val == 2'b11 || in_val == 2'b10) begin
                                ans <= opb << 1;
                                
                            end
                            else if(in_val == 2'b00 || in_val == 2'b01)begin
                                err1 <= 1'b1;ans <= 0; 
                            end
//                            else begin
//                                res <= res;
//                            end
                       end 
                       
                       
                       
               5'd12: begin  
                      if(in_val == 2'b11) begin
    
                         err1 <= (opb[N-1 : $clog2(N)-1] != 0) ? 1 : 0;
                         if(opb > 0 && opb < N-1) 
                         ans  <= (opa << opb[$clog2(N)-1 : 0]) | (opa >> (N - opb[$clog2(N)-1 : 0]));
                         else if(opb == 0) ans <= opa;
                         else ans <= 0;
                       end
                       else begin
                         err1 <= 1;
                         ans  <= 0;
                       end
                       end
               
               
               5'd13: begin  
                      if(in_val == 2'b11) begin
                         err1 <= (opb[N-1 : $clog2(N)-1] != 0) ? 1 : 0;
                         if(opb > 0 && opb < N-1)
                         ans  <= (opa >> opb[$clog2(N)-1 : 0]) | (opa << (N - opb[$clog2(N)-1 : 0]));
                         else if(opb == 0) ans <= opa;
                         else ans <= 0;
                      end
                      else begin
                         err1 <= 1;
                         ans  <= 0;
                      end
                    end
               
               default: ans <= 0;                                                                                  
                    endcase
                end
                
                
                else ans <= ans;
            end
         

         
         
        always @(posedge clk or posedge rst)begin
        if(rst) begin ans1 <= 'b0; ans2 <= 'b0; end
        else begin                
                ans1 <= ans;
//                
                ans2 <= ans; end
//            else
//                ans2 <= 'bx;
//             end
        end    
            
            
        always @(posedge clk or posedge rst)begin
            if(rst) begin
                    res <= 'b0;
                    c_out <= 0;
                    G <= 0;
                    L <= 0;
                    E <= 0;
                    err <= 0;
                    oflow <= 0;
                    c_out <= 0;  
                end
                
                
            else if(ce == 1)begin
            res <= ans;
                    G <= G1;
                    c_out <= c_out1;
                    L <= L1;
                    E <= E1;
                    err <= err1;
                    oflow <= oflow1;
            
if({mode,cmd} == 5'd25) begin
    case(flag)
        2'd0: begin
            res  <= res;          
            flag <= 2'd1;
        end
        2'd1: begin
            res  <= {2*N{1'bx}}; 
            flag <= 2'd2;
        end
        2'd2: begin
            res  <= ans1;         
            flag <= 2'd0;
        end
        default: flag <= 2'd0;
    endcase
end

else if({mode,cmd} == 5'd26) begin
    case(flag1)
        2'd0: begin
            res   <= res;          
            flag1 <= 2'd1;
        end
        2'd1: begin
            res   <= {2*N{1'bx}}; 
            flag1 <= 2'd2;
        end
        2'd2: begin
            res   <= ans2;        
            flag1 <= 2'd0;
        end
        default: flag1 <= 2'd0;
    endcase
end
//                    else flag<=0;
//                    end
//end
//                    if ({mode,cmd} == 5'd26) res <= ans1;
//                    else res <= ans;
                  
//                    G <= G1;
//                    L <= L1;
//                    E <= E1;
//                    err <= err1;
//                    oflow <= oflow1;
              
//                    end
//            else res <= 'bx;        
                    
                    
        end
    end        
endmodule



















module alu_ref_mod #(parameter N = 8)(input clk,rst,c_in,ce,mode, input[1:0]in_val,input [N-1:0]opa,opb, input [3:0]cmd, 
                   output reg oflow,c_out,G,L,E,err, output reg [(2*N)-1:0]res);
always @(posedge clk or posedge rst)begin
if(!rst) begin
   res = 'b0;
        c_out = 1'b0;
        oflow = 1'b0;
        G = 1'b0;
        E = 1'b0;
        L = 1'b0;
        err = 1'b0;

end

else if(ce == 1) begin 
    
    c_out = 1'b0;
        oflow = 1'b0;
        G = 1'b0;
        E = 1'b0;
        L = 1'b0;
        err = 1'b0;
    if(mode == 1)begin
        case(cmd)
        4'b0000: begin if(in_val == 2'b11) begin
            @(posedge clk);
            res = opa + opb;
            c_out = res[N]; end
            else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
                end

        4'b0001: begin if(in_val == 2'b11) begin
            @(posedge clk);
            res = opa - opb;
            oflow = (opa<opb);end
            else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
                end

        4'b0010: begin if(in_val == 2'b11) begin
            @(posedge clk);
            res = opa + opb + c_in;
            c_out = res[N];end
            else begin  @(posedge clk); 
                err = 1'b1;
                res = 0; end
                end

        4'b0011: begin if(in_val == 2'b11) begin
            @(posedge clk);
            res = opa - opb - c_in;
            oflow = (opa<(opb + c_in));end
            else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
                end

        4'b0100: begin if(in_val == 2'b11 || in_val == 2'b01) begin
            @(posedge clk);
            res = opa + 1'b1;
            end
            else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
                 end

        4'b0101: begin if(in_val == 2'b11 || in_val == 2'b01) begin
            @(posedge clk);
            res = opa - 1'b1;
            end
            else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
                 end

        4'b0110: begin if(in_val == 2'b11 || in_val == 2'b10) begin
            @(posedge clk);
            res = opb + 1'b1;
            end
            else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
                 end

        4'b0111: begin if(in_val == 2'b11 || in_val == 2'b10) begin
            @(posedge clk);
            res = opb - 1'b1;
            end
            else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
                end

        4'b1000: begin if(in_val == 2'b11) begin
            @(posedge clk);
            if(opa > opb) begin G = 1'b1; L = 1'b0; E = 1'b0;end
            else if(opa < opb) begin G = 1'b0; L = 1'b1; E = 1'b0;end
            else begin G = 1'b0; L = 1'b0; E = 1'b1;end
            res = res;
            end
            else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
                end

        4'b1001: begin if(in_val == 2'b11) begin
            @(posedge clk);
            res = 'bx;
            @(posedge clk);
            res = (opa + 1)*(opb + 1);
            end
            else begin @(posedge clk);
                err = 1'b1;
                res = 0; end
                end

        4'b1010: begin if(in_val == 2'b11) begin
            @(posedge clk);
            res = 'bx;
            @(posedge clk);
            res = (opa << 1)*opb;
            end
            else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
                 end

        4'b1011: begin if(in_val == 2'b11) begin
            @(posedge clk);
            res = $signed(opa) + $signed(opb);
            oflow = (res[N-1] != opa[N-1]  && res[N-1] != opb[N-1]) ? 1 : 0; end
            else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
                end

         4'b1100: begin if(in_val == 2'b11) begin
            @(posedge clk);
            res = $signed(opa) - $signed(opb);
            oflow = ($signed(opa)<$signed(opb)) ? 1 : 0 ;end
            else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
                  end                                  
        
        endcase

    end
        else begin 
            case(cmd)
            4'b0000:begin
                if(in_val == 2'b11)begin 
                @(posedge clk);
                res = opa & opb;
                end
                else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
            end

            4'b0001:begin
                if(in_val == 2'b11)begin 
                @(posedge clk);
                res = ~(opa & opb);
                end
                else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
            end



            4'b0010:begin
                if(in_val == 2'b11)begin 
                @(posedge clk);
                res = opa | opb;
                end
                else begin @(posedge clk);
                err = 1'b1;
                res = 0; end
            end




            4'b0011:begin
                if(in_val == 2'b11)begin 
                @(posedge clk);
                res = ~(opa | opb);
                end
                else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
            end





            4'b0100:begin
                if(in_val == 2'b11)begin 
                @(posedge clk);
                res = opa ^ opb;
                end
                else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
            end



            4'b0101:begin
                if(in_val == 2'b11)begin 
                @(posedge clk);
                res = opa ~^ opb;
                end
                else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
            end


            4'b0110:begin
                if(in_val == 2'b11 || in_val == 2'b01)begin 
                @(posedge clk);
                res = ~opa;
                end
                else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
            end


            4'b0111:begin
                if(in_val == 2'b11 || in_val == 2'b10)begin 
                @(posedge clk);
                res = ~opb;
                end
                else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
            end

            4'b1000:begin
                if(in_val == 2'b11 || in_val == 2'b01)begin 
                @(posedge clk);
                res = opa>>1;
                end
                else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
            end

            4'b1001:begin
                if(in_val == 2'b11 || in_val == 2'b01)begin 
                @(posedge clk);
                res = opa<<1;
                end
                else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
            end

            4'b1010:begin
                if(in_val == 2'b11 || in_val == 2'b10)begin 
                @(posedge clk);
                res = opb>>1;
                end
                else begin @(posedge clk);
                err = 1'b1;
                res = 0; end
            end

            4'b1011:begin
                if(in_val == 2'b11 || in_val == 2'b10)begin 
                @(posedge clk);
                res = opb<<1;
                end
                else begin @(posedge clk);
                err = 1'b1;
                res = 0; end
            end

            4'b1100:begin
                if(in_val == 2'b11)begin 
                @(posedge clk);
                err = (opb[N-1 : $clog2(N)-1] != 0) ? 1 : 0;
                if(opb > 0 && opb < N) res = (opa << opb) | (opa >> (N-opb));
                else if (opb == 0) res = opa;
                else res = 0;
                end
                else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
            end


            4'b1101:begin
                if(in_val == 2'b11)begin 
                @(posedge clk);
                err = (opb[N-1 : $clog2(N)-1] != 0) ? 1 : 0;
                if(opb > 0 && opb < N) res = (opa >> opb) | (opa << (N - opb));
                else if (opb == 0) res = opa;
                else res = 0;
                end
                else begin @(posedge clk); 
                err = 1'b1;
                res = 0; end
            end
            endcase
        end
end
else res = res;
end
endmodule                   
