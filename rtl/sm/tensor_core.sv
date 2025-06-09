`ifndef TENSOR_CORE
`define TENSOR_CORE

module tensor_core #(
    parameter DATA_WIDTH = 16, // Width of elements in matrix A and B
    parameter ACC_WIDTH  = 32, // Width of elements in matrix C and D (accumulator width)
    parameter SIZE       = 4,  // Dimension of square matrices (e.g., 4x4)
    parameter CLOG2_SIZE_VAL = (SIZE > 1) ? $clog2(SIZE) : 0
)(
    input  logic clk,
    input  logic rst,
    input  logic valid_in,
    input  logic [7:0] opcode, // Unused for now

    input  logic signed [DATA_WIDTH-1:0] matrix_a [SIZE][SIZE],
    input  logic signed [DATA_WIDTH-1:0] matrix_b [SIZE][SIZE],
    input  logic signed [ACC_WIDTH-1:0]  matrix_c [SIZE][SIZE],

    output logic valid_out,
    output logic signed [ACC_WIDTH-1:0] matrix_d [SIZE][SIZE]
);

    // Pipeline Registers
    logic signed [DATA_WIDTH-1:0] s1_matrix_a [SIZE][SIZE];
    logic signed [DATA_WIDTH-1:0] s1_matrix_b [SIZE][SIZE];
    logic signed [ACC_WIDTH-1:0]  s1_matrix_c [SIZE][SIZE];
    logic                         s1_valid_reg;

    logic signed [ACC_WIDTH-1:0]  s2_matrix_d_pre_out [SIZE][SIZE];
    logic                         s2_valid_reg;

    // Valid Signal Pipeline
    logic [2:0] valid_pipe_reg;

    // --- Stage 1: Input Latch ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            foreach (s1_matrix_a[i,j]) s1_matrix_a[i][j] <= '0;
            foreach (s1_matrix_b[i,j]) s1_matrix_b[i][j] <= '0;
            foreach (s1_matrix_c[i,j]) s1_matrix_c[i][j] <= '0;
            s1_valid_reg <= 0;
        end else begin
            if (valid_in) begin
                foreach (s1_matrix_a[i,j]) s1_matrix_a[i][j] <= matrix_a[i][j];
                foreach (s1_matrix_b[i,j]) s1_matrix_b[i][j] <= matrix_b[i][j];
                foreach (s1_matrix_c[i,j]) s1_matrix_c[i][j] <= matrix_c[i][j];
            end
            s1_valid_reg <= valid_in;
        end
    end

    // --- Stage 2: MAC Operation ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            foreach (s2_matrix_d_pre_out[i,j]) s2_matrix_d_pre_out[i][j] <= '0;
            s2_valid_reg <= 0;
        end else begin
            if (s1_valid_reg) begin
                foreach (s2_matrix_d_pre_out[i,j]) begin
                    logic signed [ACC_WIDTH-1:0] current_sum;
                    current_sum = s1_matrix_c[i][j];
                    for (int k = 0; k < SIZE; k++) begin
                        current_sum += s1_matrix_a[i][k] * s1_matrix_b[k][j];
                    end
                    s2_matrix_d_pre_out[i][j] <= current_sum;
                end
            end
            s2_valid_reg <= s1_valid_reg;
        end
    end

    // --- Stage 3: Output Latch ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            foreach (matrix_d[i,j]) matrix_d[i][j] <= '0;
        end else begin
            if (s2_valid_reg) begin
                foreach (matrix_d[i,j]) matrix_d[i][j] <= s2_matrix_d_pre_out[i][j];
            end
        end
    end

    // --- Valid Pipeline Tracking ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            valid_pipe_reg <= 3'b0;
        else
            valid_pipe_reg <= {valid_pipe_reg[1:0], valid_in};
    end

    assign valid_out = valid_pipe_reg[2];

endmodule

`endif
