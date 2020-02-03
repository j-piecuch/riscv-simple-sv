// RISC-V SiMPLE SV -- SystemVerilog testbench
// BSD 3-Clause License
// (c) 2020, Jakub Piecuch, University of Wrocław

module testbench();
    logic clk, rst;
    logic [31:0] bus_read_data;
    logic [31:0] bus_address;
    logic [31:0] bus_write_data;
    logic [3:0]  bus_byte_enable;
    logic        bus_read_enable;
    logic        bus_write_enable;
    logic        bus_wait_req;
    logic        bus_valid;

    logic        inst_read_enable;
    logic        inst_wait_req;
    logic        inst_valid;

    logic [31:0] inst;
    logic [31:0] pc;

    integer      ticks;
    integer      stdout;

    initial begin
        stdout = $fopen("/proc/self/fd/1", "w");
        if (stdout == 0) begin
            $display("cannot open stdout");
            $finish;
        end
    end

    initial begin
        ticks = 0;
        clk = 0;
        rst = 1;
    end

    always #1 begin
        clk = ~clk;
        if (clk) ticks = ticks + 1;
    end

    initial #9 rst = 0;

    toplevel top (
        .clock(clk),
        .reset(rst),
        .bus_read_data(bus_read_data),
        .bus_address(bus_address),
        .bus_write_data(bus_write_data),
        .bus_byte_enable(bus_byte_enable),
        .bus_read_enable(bus_read_enable),
        .bus_write_enable(bus_write_enable),
        .bus_wait_req(bus_wait_req),
        .bus_valid(bus_valid),
        .inst_read_enable(inst_read_enable),
        .inst_wait_req(inst_wait_req),
        .inst_valid(inst_valid),
        .inst(inst),
        .pc(pc)
    );

    always @(posedge clk) if (bus_write_enable && bus_address == 32'hfffffff0) begin
        if (bus_write_data)
            $fwrite(stdout, "PASS\n");
        else
            $fwrite(stdout, "FAIL\n");
        $finish;
    end

    always @(posedge clk) if (ticks > 100000) begin
        $fwrite(stdout, "TIMEOUT\n");
        $finish;
    end

endmodule
