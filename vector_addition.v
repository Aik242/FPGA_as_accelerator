module vector_addition(
    input clk, 
    input [8:0] index,
    input [31:0] value,
    input vector_id,
    input input_done,
    input start_arm,
    input stop_arm,
    output [31:0] result,
    output done,
    output [31:0] arm_cycles
);
    reg [31:0] v0 [0:511];
    reg [31:0] v1 [0:511];
    reg [31:0] v2 [0:511];
    reg [31:0] arm_cycles_reg;
    reg [3:0] state = 4'b0000;
    reg done_reg;

    assign arm_cycles = arm_cycles_reg;
    assign result = v2[0];
    assign done = done_reg;

    always @(posedge clk) begin
        if(state==0) begin
            if(input_done==1'b1) begin
                arm_cycles_reg <= 0;
                done_reg <= 0;
                state <= 4'b0001;
            end
            else begin
                if(vector_id==1'b0) v0[index] <= value;
                else if(vector_id==1'b1) v1[index] <= value;
            end
        end

        else if(state>=4'b0001 && state<=4'b1010) state <= state+1;

        else if(state==4'b1011) begin 
            done_reg <= 1'b1;
            if(start_arm && !stop_arm) begin
                arm_cycles_reg <= arm_cycles_reg+1;
            end
        end

    end

    genvar i;
    generate
        for(i=0; i<512; i=i+1) 
            begin: add
                always @(posedge clk) begin
                    if(state==4'b0001) v2[i]<=v1[i]+v0[i];
                    else if(state==4'b0010 && i<256) v2[i]<=v2[i]+v2[i+256];
                    else if(state==4'b0011 && i<128) v2[i]<=v2[i]+v2[i+128];
                    else if(state==4'b0100 && i<64) v2[i]<=v2[i]+v2[i+64];
                    else if(state==4'b0101 && i<32) v2[i]<=v2[i]+v2[i+32];
                    else if(state==4'b0110 && i<16) v2[i]<=v2[i]+v2[i+16];
                    else if(state==4'b0111 && i<8) v2[i]<=v2[i]+v2[i+8];
                    else if(state==4'b1000 && i<4) v2[i]<=v2[i]+v2[i+4];
                    else if(state==4'b1001 && i<2) v2[i]<=v2[i]+v2[i+2];
                    else if(state==4'b1010 && i==0) v2[0]<=v2[0]+v2[1];
                end
            end
    endgenerate
endmodule
