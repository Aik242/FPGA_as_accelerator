module matrix_mult(
    input clk,
    input [4:0] row_id, 
    input [4:0] col_id,
    input value,
    input [4:0] k,
    input input_done,
    input [4:0] u,
    input [4:0] v,
    input start_arm,
    input stop_arm,
    output result,
    output done,
    output [31:0] arm_cycles
);
    reg [31:0] A [0:31];
    reg [31:0] A_transpose [0:31];
    reg [31:0] B [0:31];
    reg [31:0] C [0:31];

    reg [31:0] arm_cycles_reg = 0;
    reg [3:0] state = 4'b0000;
    reg [4:0] current_k = 5'b00000;
    reg done_reg;

    assign arm_cycles = arm_cycles_reg;
    assign result = B[u][v];
    assign done = done_reg;

    always @(posedge clk) begin
        if(state == 4'b0000) begin
            if(input_done == 1'b1) begin
                arm_cycles_reg <= 0;
                current_k <= 5'd1;
                done_reg <= 0;
                state <= 4'b0001;
            end
            else begin
                A[row_id][col_id] <= value;
                A_transpose[col_id][row_id] <= value;
            end
        end

        else if(state == 4'b0001) begin 
            if(k <= 1) state <= 4'b1000;
            else state <= 4'b0010;
        end

        else if(state >= 4'b0010 && state <= 4'b0100) state <= state + 1;

        else if(state == 4'b0101) state <= 4'b0110;

        else if(state == 4'b0110) begin
            if(current_k+1<k) begin
                current_k <= current_k + 1;
                state <= 4'b0010;
            end
            else begin
                state <= 4'b1000;
            end
        end

        else if(state == 4'b1000) begin
            done_reg <= 1'b1;
            if(start_arm && !stop_arm) begin
                arm_cycles_reg <= arm_cycles_reg + 1;
            end
        end
    end

    genvar i; integer j;
    generate
        for(i = 0; i < 32; i = i + 1) begin: row
            always @(posedge clk) begin
                if (state == 4'b0001) B[i] <= A[i];
                else if (state >= 4'b0010 && state <= 4'b0101) begin
                    if ((state == 4'b0010 && i < 8) ||
                        (state == 4'b0011 && i >= 8 && i < 16) ||
                        (state == 4'b0100 && i >= 16 && i < 24) ||
                        (state == 4'b0101 && i >= 24)) begin
                        for(j = 0; j < 32; j = j + 1) begin
                            C[i][j] <= |(B[i] & A_transpose[j]);
                        end
                    end
                end
                else if (state == 4'b0110) B[i] <= C[i];
            end
        end
    endgenerate

endmodule

// Test Bench to check if a path of length "k" exists between "u" and "v" in a graph

module graph_paths_top;
    reg clk;
    reg [4:0] edge_source;
    reg [4:0] edge_dest;
    reg adjacency_val;
    reg [4:0] path_length;
    reg input_done;
    reg [4:0] start_vertex;
    reg [4:0] end_vertex;
    reg start_arm;
    reg stop_arm;
    wire is_there_path;
    wire done;
    wire [31:0] arm_cycles;

    integer i, j, k, step, error_count, pair_count;

    reg A_tb [0:31][0:31];
    reg expected [0:31][0:31];
    reg temp_matrix [0:31][0:31];
    reg current_sum;

    matrix_mult uut(clk, edge_source, edge_dest, adjacency_val, path_length, input_done, start_vertex, end_vertex, start_arm, stop_arm, is_there_path, done, arm_cycles);

    always begin
        clk = ~clk;
        #5;
    end

    parameter UNDIRECTED_GRAPH = 1;

    initial begin
        clk = 0; edge_source = 0; edge_dest = 0; adjacency_val = 0;
        input_done = 0; start_vertex = 0; end_vertex = 0;
        start_arm = 0; stop_arm = 0; error_count = 0; pair_count = 0;

        path_length = 5'd31;

        #2;
        for(i=0; i<32; i=i+1) begin
            for(j=0; j<32; j=j+1) begin
                if (UNDIRECTED_GRAPH) begin
                    if ((j==((i+1)%32))||(j==((i+31)%32))) begin
                        A_tb[i][j] = 1;
                    end else begin
                        A_tb[i][j] = 0;
                    end
                end else begin
                    if (j==((i+1)%32)) begin
                        A_tb[i][j] = 1;
                    end else begin
                        A_tb[i][j] = 0;
                    end
                end

                expected[i][j] = A_tb[i][j];
            end
        end

        for(i = 0; i < 32; i = i + 1) begin
            for(j = 0; j < 32; j = j + 1) begin
                edge_source = i;
                edge_dest = j;
                adjacency_val = A_tb[i][j];
                @(negedge clk);
            end
        end

        input_done = 1;
        @(negedge clk);
        input_done = 0;
        $display("Input done");

        if (path_length>1) begin
            for (step=2; step<=path_length; step=step+1) begin
                for (i=0; i<32; i=i+1) begin
                    for (j=0; j<32; j=j+1) begin
                        current_sum = 0;
                        for (k=0; k<32; k=k+1) begin
                            current_sum = current_sum | (expected[i][k] & A_tb[k][j]);
                        end
                        temp_matrix[i][j] = current_sum;
                    end
                end
                for (i=0; i<32;i=i+1) begin
                    for (j=0; j<32; j=j+1) begin
                        expected[i][j] = temp_matrix[i][j];
                    end
                end
            end
        end

        $display("Waiting for FPGA Hardware to finish");
        wait(done);
        #20;

        $display("Verifying 1024 vertex pairs...");
        for(i=0; i<32; i=i+1) begin
            for(j=0; j<32; j=j+1) begin
                start_vertex = i;
                end_vertex = j;
                @(negedge clk);

                if (is_there_path !== expected[i][j]) begin
                    error_count = error_count + 1;
                end

                if (is_there_path) begin
                    $write("(%0d, %0d) ", i, j);
                    pair_count = pair_count + 1;
                end
            end
        end

        $display("\nFPGA pair count: %0d", pair_count);

        $display("Start ARM");
        start_arm = 1;
        repeat(151) @(posedge clk);
        stop_arm = 1;
        $display("Stop ARM");

        $display("ARM Cycles = %d", arm_cycles);
        $finish;
    end
endmodule

