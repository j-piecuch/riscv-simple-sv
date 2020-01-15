module testbench();
    logic clk, rst;
    logic [31:0] bus_read_data;
    logic [31:0] bus_address;
    logic [31:0] bus_write_data;
    logic [3:0]  bus_byte_enable;
    logic        bus_read_enable;
    logic        bus_write_enable;

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