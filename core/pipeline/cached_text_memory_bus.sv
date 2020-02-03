
module cached_text_memory_bus (
    input  clock,
    input  reset,
    input  read_enable,
    input  [31:0] address,
    output [31:0] read_data,
    output        wait_req,
    output        valid
);

    logic [31:0] ram_address;
    logic ram_read_enable;
    logic [31:0] ram_read_data;
    logic ram_waitrequest;
    logic ram_read_data_valid;

    inst_cache icache (
        .clock            (clock),
        .reset            (reset),
        .ram_address      (ram_address),
        .ram_read_enable  (ram_read_enable),
        .ram_read_data    (ram_read_data),
        .ram_waitrequest  (ram_waitrequest),
        .ram_read_data_valid (ram_read_data_valid),
        .cache_address (address),
        .cache_inst (read_data),
        .cache_waitrequest (wait_req),
        .cache_read_enable (read_enable),
        .cache_inst_valid (valid)
    );

    example_text_memory_bus text_memory_bus (
        .clock                  (clock),
        .reset                  (reset),
        .read_enable            (ram_read_enable),
        .wait_req               (ram_waitrequest),
        .valid                  (ram_read_data_valid),
        .address                (ram_address),
        .read_data              (ram_read_data)
    );

endmodule
