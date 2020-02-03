// RISC-V SiMPLE SV -- text memory interface for pipelined architecture
// BSD 3-Clause License
// (c) 2020, Jakub Piecuch, University of Wrocław

module pl_text_memory_interface (
    input         clock,
    input         reset,
    input [31:0]  request_pc,
    input         next_inst,
    input         inst_wait_req,
    input         inst_valid,
    output logic  inst_read_enable,
    output logic  inst_available,
    input [31:0]  inst_data,
    output logic [31:0] inst,
    output [31:0] inst_addr
);

    logic [31:0]  stored_inst;
    logic         has_stored_inst;
    logic [31:0]  last_pc;
    logic         last_pc_valid;
    logic [7:0]   reqs_sent;
    logic [7:0]   all_reqs;
    logic         request_ready;
    logic         response_ready;
    logic         new_request;
    logic [31:0]  current_pc;
    logic         current_pc_valid;
    logic [31:0]  next_pc;
    logic         next_pc_valid;

    assign all_reqs = reqs_sent + {7'b0, inst_read_enable};

    assign request_ready = inst_read_enable && !inst_wait_req;
    assign response_ready = inst_valid;
    assign new_request = next_inst && (last_pc_valid ? last_pc != request_pc : 1'b1);
    assign inst_read_enable = current_pc_valid;
    assign inst_addr = current_pc;

    always_ff @(posedge clock)
        if (reset) begin
            current_pc       <= 32'b0;
            current_pc_valid <= 1'b0;
            next_pc          <= 32'b0;
            next_pc_valid    <= 1'b0;
            last_pc          <= 32'b0;
            last_pc_valid    <= 1'b0;
        end else if (new_request) begin
            last_pc       <= request_pc;
            last_pc_valid <= 1'b1;
            if (!inst_wait_req || !current_pc_valid) begin
                current_pc       <= request_pc;
                current_pc_valid <= 1'b1;
                next_pc_valid    <= 1'b0;
            end else begin
                next_pc       <= request_pc;
                next_pc_valid <= 1'b1;
            end
        end else if (!inst_wait_req) begin
            current_pc       <= next_pc;
            current_pc_valid <= next_pc_valid;
            next_pc_valid    <= 1'b0;
        end

    always_comb
        if (inst_valid && all_reqs == 1) begin
            inst_available = 1'b1;
            inst = inst_data;
        end else if (has_stored_inst && all_reqs == 0) begin
            inst_available = 1'b1;
            inst = stored_inst;
        end else begin
            inst_available = 1'b0;
            inst = 32'bx;
        end

    always_ff @(posedge clock)
        if (reset) begin
            has_stored_inst <= 1'b0;
            stored_inst <= 32'b0;
        end else if (inst_valid) begin
            has_stored_inst <= 1'b1;
            stored_inst <= inst_data;
        end

    always_ff @(posedge clock)
        if (reset)
            reqs_sent <= 0;
        else if (request_ready && !response_ready)
            reqs_sent <= reqs_sent + 1;
        else if (!request_ready && response_ready)
            reqs_sent <= reqs_sent - 1;

endmodule // pl_text_memory_interface

module pl_text_memory_interface_control(
    input clock,
    input reset,
    input [31:0] pc,
    input [31:0] next_pc,
    input pc_write_enable,
    output next_inst,
    output [31:0] request_pc
);

    logic just_reset;

    always_ff @(posedge clock) just_reset <= reset;

    // request next instruction after reset and on pc change
    assign next_inst  = just_reset || pc_write_enable;
    assign request_pc = pc_write_enable ? next_pc : pc;

endmodule // pl_text_memory_interface_control
