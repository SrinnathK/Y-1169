`timescale 1ns/1ps

module tensor_core_tb;

    localparam DATA_WIDTH = 16;
    localparam ACC_WIDTH  = 32;
    localparam SIZE       = 4;
    localparam CLOG2_SIZE_VAL = (SIZE > 1) ? $clog2(SIZE) : 0;

    logic clk, rst, valid_in, valid_out;
    logic [7:0] opcode;

    logic signed [DATA_WIDTH-1:0] matrix_a [SIZE][SIZE];
    logic signed [DATA_WIDTH-1:0] matrix_b [SIZE][SIZE];
    logic signed [ACC_WIDTH-1:0]  matrix_c [SIZE][SIZE];
    logic signed [ACC_WIDTH-1:0]  matrix_d [SIZE][SIZE];

    // Expected output matrix
    logic signed [ACC_WIDTH-1:0] golden_matrix_d [SIZE][SIZE];

    // Instantiate DUT
    tensor_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .SIZE(SIZE),
        .CLOG2_SIZE_VAL(CLOG2_SIZE_VAL)
    ) dut (
        .clk(clk),
        .rst(rst),
        .valid_in(valid_in),
        .opcode(opcode),
        .matrix_a(matrix_a),
        .matrix_b(matrix_b),
        .matrix_c(matrix_c),
        .valid_out(valid_out),
        .matrix_d(matrix_d)
    );

    // Clock generation
    always #5 clk = ~clk;

    task compute_expected_result();
        for (int i = 0; i < SIZE; i++) begin
            for (int j = 0; j < SIZE; j++) begin
                golden_matrix_d[i][j] = matrix_c[i][j];
                for (int k = 0; k < SIZE; k++) begin
                    golden_matrix_d[i][j] += matrix_a[i][k] * matrix_b[k][j];
                end
            end
        end
    endtask

    task print_matrix(string title, logic signed [ACC_WIDTH-1:0] mat[SIZE][SIZE]);
        $display("-------- %s --------", title);
        for (int i = 0; i < SIZE; i++) begin
            $write("| ");
            for (int j = 0; j < SIZE; j++) begin
                $write("%0d\t", mat[i][j]);
            end
            $write("|\n");
        end
        $display("------------------------\n");
    endtask

    task automatic run_test_case(string name);
        int errors = 0;
        $display("\n====== Running %s ======\n", name);

        // Compute expected result
        compute_expected_result();

        // Apply input
        @(posedge clk);
        valid_in <= 1;
        @(posedge clk);
        valid_in <= 0;

        // Wait for output
        wait (valid_out);

        print_matrix("MATRIX D (DUT Output)", matrix_d);
        print_matrix("MATRIX D (Expected)", golden_matrix_d);

        // Compare
        for (int i = 0; i < SIZE; i++) begin
            for (int j = 0; j < SIZE; j++) begin
                if (matrix_d[i][j] !== golden_matrix_d[i][j]) begin
                    $display("❌ Mismatch at [%0d][%0d]: DUT = %0d, Expected = %0d", i, j, matrix_d[i][j], golden_matrix_d[i][j]);
                    errors++;
                end
            end
        end

        if (errors == 0)
            $display("✅ %s PASSED\n", name);
        else
            $display("❌ %s FAILED: %0d mismatches\n", name, errors);
    endtask

    initial begin
        clk = 0;
        rst = 1;
        valid_in = 0;
        opcode = 8'h00;

        repeat (2) @(posedge clk);
        rst = 0;

        // ---------------------
        // Direct Test Case
        // ---------------------
        matrix_a = '{ '{1, 2, 3, 4},
                      '{5, 6, 7, 8},
                      '{9, 1, 2, 3},
                      '{4, 5, 6, 7} };

        matrix_b = '{ '{1, 0, 0, 0},
                      '{0, 1, 0, 0},
                      '{0, 0, 1, 0},
                      '{0, 0, 0, 1} };

        matrix_c = '{ '{0, 0, 0, 0},
                      '{0, 0, 0, 0},
                      '{0, 0, 0, 0},
                      '{0, 0, 0, 0} };

        run_test_case("Direct Test (matrix_d = matrix_a)");

        // ---------------------
        // Random Test Case
        // ---------------------
        foreach (matrix_a[i,j]) matrix_a[i][j] = $urandom_range(-4, 4);
        foreach (matrix_b[i,j]) matrix_b[i][j] = $urandom_range(-3, 3);
        foreach (matrix_c[i,j]) matrix_c[i][j] = $urandom_range(-5, 5);

        run_test_case("Random Test");

        $finish;
    end

endmodule
