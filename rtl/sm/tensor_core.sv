`ifndef TENSOR_CORE
`define TENSOR_CORE

module tensor_core #(
    parameter DATA_WIDTH = 16,        // Support for FP16/BF16/TF32/INT8
    parameter ACC_WIDTH  = 32,        // Accumulator width
    parameter SIZE       = 4          // 4x4 matrix
) (
    input  logic                         clk,
    input  logic                         rst,           // Synchronous active-high reset
    input  logic                         valid_in,      // Input valid strobe
    input  logic [7:0]                   opcode,        // Future extensibility

    // Matrix inputs (flattened for tool compatibility)
    input  logic [DATA_WIDTH-1:0]        matrix_a [SIZE][SIZE],
    input  logic [DATA_WIDTH-1:0]        matrix_b [SIZE][SIZE],
    input  logic [ACC_WIDTH-1:0]         matrix_c [SIZE][SIZE],

    output logic                         valid_out,     // Output valid strobe
    output logic [ACC_WIDTH-1:0]         matrix_d [SIZE][SIZE]
);

    // Pipeline registers
    typedef struct packed {
        logic [DATA_WIDTH-1:0] a_row [SIZE];
        logic [DATA_WIDTH-1:0] b_col [SIZE];
        logic [ACC_WIDTH-1:0]  c_val;
    } stage1_reg_t;

    typedef struct packed {
        logic [ACC_WIDTH-1:0] partial_sum;
    } stage2_reg_t;

    stage1_reg_t stage1 [SIZE][SIZE];
    stage2_reg_t stage2 [SIZE][SIZE];

    // Valid pipeline
    logic [2:0] valid_pipe;

    // Pipeline: Stage 1 (Register inputs)
    always_ff @(posedge clk) begin
        if (rst) begin
            foreach (stage1[i, j]) begin
                stage1[i][j].a_row = '{default: '0};
                stage1[i][j].b_col = '{default: '0};
                stage1[i][j].c_val = '0;
            end
        end else if (valid_in) begin
            foreach (stage1[i, j]) begin
                for (int k = 0; k < SIZE; k++) begin
                    stage1[i][j].a_row[k] = matrix_a[i][k];
                    stage1[i][j].b_col[k] = matrix_b[k][j];
                end
                stage1[i][j].c_val = matrix_c[i][j];
            end
        end
    end

    // Pipeline: Stage 2 (Multiply-Accumulate)
    always_ff @(posedge clk) begin
        if (rst) begin
            foreach (stage2[i, j]) begin
                stage2[i][j].partial_sum = '0;
            end
        end else begin
            foreach (stage2[i, j]) begin
                logic [ACC_WIDTH-1:0] sum = stage1[i][j].c_val;
                for (int k = 0; k < SIZE; k++) begin
                    sum += $signed(stage1[i][j].a_row[k]) * $signed(stage1[i][j].b_col[k]);
                end
                stage2[i][j].partial_sum = sum;
            end
        end
    end

    // Pipeline: Stage 3 (Output register)
    always_ff @(posedge clk) begin
        if (rst) begin
            foreach (matrix_d[i, j]) begin
                matrix_d[i][j] <= '0;
            end
        end else begin
            foreach (matrix_d[i, j]) begin
                matrix_d[i][j] <= stage2[i][j].partial_sum;
            end
        end
    end

    // Valid pipeline logic
    always_ff @(posedge clk) begin
        if (rst) begin
            valid_pipe <= '0;
        end else begin
            valid_pipe <= {valid_pipe[1:0], valid_in};
        end
    end
    assign valid_out = valid_pipe[2];

endmodule

`endif
