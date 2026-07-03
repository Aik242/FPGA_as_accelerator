module matrix_mult(
    input clk, 
    input [3:0] row_id,
    input [3:0] col_id,
    input [31:0] value,
    input vector_id,
    input input_done,
    input [3:0] index,
    input start_arm,
    input stop_arm,
    output [31:0] result,
    output done,
    output [31:0] arm_cycles
);
    reg [31:0] M [0:15][0:15];
    reg [31:0] x [0:15];
    reg [31:0] y [0:15];
    reg [31:0] v [0:15];
    reg [31:0] w [0:15];

    reg [31:0] arm_cycles_reg = 0;
    reg [3:0] state = 4'b0000;
    reg [3:0] current_row;
    reg done_reg;

    assign arm_cycles = arm_cycles_reg;
    assign result = y[index];
    assign done = done_reg;

    always @(posedge clk) begin
        if(state==0) begin
            if(input_done==1'b1) begin
                arm_cycles_reg <= 0;
                current_row <= 4'd0;
                done_reg <= 0;
                state <= 4'b0001;
            end
            else begin
                if (vector_id == 1'b0) M[row_id][col_id] <= value;
                else x[row_id] <= value;
            end
        end

        else if(state>=4'b0001 && state<=4'b0101) state <= state+1;

        else if(state==4'b0110) state <= 4'b0111;

        else if(state==4'b0111) begin
            y[current_row] <= w[0];
            if (current_row < 4'b1111) begin
                current_row <= current_row + 1;
                state <= 4'b0001;
            end 
            else state <= 4'b1000;
        end

        else if(state==4'b1000) begin 
            done_reg <= 1'b1;
            if(start_arm && !stop_arm) begin
                arm_cycles_reg <= arm_cycles_reg+1;
            end
        end

    end

    genvar i;
    generate
        for(i=0; i<16; i=i+1) 
            begin: add
                always @(posedge clk) begin
                    if(state==4'b0001) v[i]<=M[current_row][i];
                    else if(state==4'b0010) w[i]<=v[i]*x[i];
                    else if(state==4'b0011 && i<8) w[i]<=w[i]+w[i+8];
                    else if(state==4'b0100 && i<4) w[i]<=w[i]+w[i+4];
                    else if(state==4'b0101 && i<2) w[i]<=w[i]+w[i+2];
                    else if(state==4'b0110 && i==0) w[0]<=w[0]+w[1];
                end
            end
    endgenerate
endmodule
