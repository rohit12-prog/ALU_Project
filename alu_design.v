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
                   output reg oflow,c_out,G,L,E,err, output reg [(2*N):0]res);
            
            reg [(2*N):0]ans,ans1,ans2;
            reg err1,oflow1,c_out1,G1,L1,E1;
            wire[2*N:0] add,sub;
            assign add = $signed(opa) + $signed(opb); 
            assign sub = $signed(opa) - $signed(opb);            
            always @(posedge clk or posedge rst) begin
                if(rst) begin
                    //res <= 0;
                    ans <= 0;
                    G1 <= 0;
                    L1 <= 0;
                    E1 <= 0;
                    err1 <= 0;
                    oflow1 <= 0;
                    c_out1 <= 0;  
                end
                
                else if(ce == 1)begin
                    //ans <= 0;
                    G1 <= 0;
                    L1 <= 0;
                    E1 <= 0;
                    err1 <= 0;
                    oflow1 <= 0;
                    c_out1 <= 0;
                    case({mode,cmd})
                        5'd16 : begin 
                                 if(in_val == 2'b11) 
                                 begin 
                                    ans <= opa + opb;  
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
                            oflow1 <= 1;
                        end
                        else oflow1 <= 0;
                       end
                       
                       
                       5'd28: begin
                        if((sub[N-1] == opa[N-1]) && (sub[N-1] != opb[N-1]))begin
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
    
                         err1 <= (opb[N-1 : $clog2(N)] != 0) ? 1 : 0;
        
                         ans  <= (opa << opb[$clog2(N)-1 : 0]) | (opa >> (N - opb[$clog2(N)-1 : 0]));
                       end
                       else begin
                         err1 <= 1;
                         ans  <= 0;
                       end
                       end
               
               
               5'd13: begin  
                      if(in_val == 2'b11) begin
                         err1 <= (opb[N-1 : $clog2(N)] != 0) ? 1 : 0;
                         ans  <= (opa >> opb[$clog2(N)-1 : 0]) | (opa << (N - opb[$clog2(N)-1 : 0]));
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
            if({mode,cmd} == 5'd25)
                ans1 <= ans;
            else
                ans1 <= 'bx;   

            if({mode,cmd} == 5'd26)
                ans2 <= ans;
            else
                ans2 <= 'bx;
             end
        end    
            
            
        always @(posedge clk or posedge rst)begin
            if(rst) begin
                    res <= 'b0;
                    //ans <= 0;
                    G <= 0;
                    L <= 0;
                    E <= 0;
                    err <= 0;
                    oflow <= 0;
                    c_out <= 0;  
                end
                
                
            else if(ce == 1)begin
                    if({mode,cmd} == 5'd25)res <= ans1;
                    else if ({mode,cmd} == 5'd26) res <= ans2;
                    else res <= ans;
                  
                    G <= G1;
                    L <= L1;
                    E <= E1;
                    err <= err1;
                    oflow <= oflow1;
              
                    end
            else res <= 'bx;        
                    
//                    
        end
            
endmodule

