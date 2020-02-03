// RISC-V SiMPLE SV -- Pipelined RISC-V core
// BSD 3-Clause License
// (c) 2017-2019, Arthur Matos, Marcus Vinicius Lamar, Universidade de Brasília,
//                Marek Materzok, University of Wrocław

`include "config.sv"
`include "constants.sv"

module riscv_core (
    input  clock,
    input  reset,

    output [31:0] bus_address,
    input  [31:0] bus_read_data,
    output [31:0] bus_write_data,
    output [3:0]  bus_byte_enable,
    output        bus_read_enable,
    output        bus_write_enable,
    input         bus_wait_req,
    input         bus_valid,

    input  [31:0] inst_data,
    output [31:0] pc,
    output        inst_read_enable,
    input         inst_wait_req,
    input         inst_valid
);

    logic pc_write_enable;
    logic regfile_write_enable;
    logic alu_operand_a_select;
    logic alu_operand_b_select;
    logic [2:0] reg_writeback_select;
    logic [6:0] inst_opcode;
    logic [2:0] inst_funct3;
    logic [2:0] data_format;
    logic [6:0] inst_funct7;
    logic [1:0] next_pc_select;
    logic [4:0] alu_function;
    logic alu_result_equal_zero;
    logic [31:0] read_data;
    logic [31:0] write_data;
    logic [31:0] address;
    logic read_enable_id;
    logic write_enable_id;
    logic read_enable;
    logic write_enable;
    logic branch_ex;
    logic jump_start;
    logic stall_id;
    logic stall_ex;
    logic stall_mem;
    logic inject_bubble_ex;
    logic inject_bubble_id;
    logic inject_bubble_wb;
    logic want_stall_id;
    logic want_stall_mem;
    logic inst_available;
    logic data_available;
    logic data_request_successful;
    logic [31:0] inst;
    logic [31:0] next_pc;
    logic next_inst;
    logic [31:0] request_pc;

    pipeline_datapath pipeline_datapath (
        .clock                  (clock),
        .reset                  (reset),
        ._inst                  (inst),
        ._data_mem_read_data    (read_data),
        ._data_mem_address      (address),
        ._data_mem_write_data   (write_data),
        ._data_mem_read_enable  (read_enable),
        ._data_mem_write_enable (write_enable),
        ._data_mem_format       (data_format),
        ._data_mem_request_successful (data_request_successful),
        ._data_mem_data_available (data_available),
        ._pc                    (pc),
        .inst_opcode            (inst_opcode),
        .inst_funct3            (inst_funct3),
        .inst_funct7            (inst_funct7),
        .pc_write_enable        (pc_write_enable),
        ._regfile_write_enable  (regfile_write_enable),
        ._alu_operand_a_select  (alu_operand_a_select),
        ._alu_operand_b_select  (alu_operand_b_select),
        ._reg_writeback_select  (reg_writeback_select),
        .next_pc_select         (next_pc_select),
        .alu_result_equal_zero  (alu_result_equal_zero),
        ._alu_function          (alu_function),
        ._read_enable           (read_enable_id),
        ._write_enable          (write_enable_id),
        .branch_ex              (branch_ex),
        .stall_id               (stall_id),
        .stall_ex               (stall_ex),
        .stall_mem              (stall_mem),
        .jump_start             (jump_start),
        .want_stall_id          (want_stall_id),
        .want_stall_mem         (want_stall_mem),
        .inject_bubble_ex       (inject_bubble_ex),
        .inject_bubble_id       (inject_bubble_id),
        .inject_bubble_wb       (inject_bubble_wb),
        .next_pc                (next_pc)
    );

    pipeline_ctlpath pipeline_ctlpath(
        .inst_opcode            (inst_opcode),
        .inst_funct3            (inst_funct3),
        .inst_funct7            (inst_funct7),
        .alu_result_equal_zero  (alu_result_equal_zero),
        .inst_available         (inst_available),
        .data_available         (data_available),
        .pc_write_enable        (pc_write_enable),
        .regfile_write_enable   (regfile_write_enable),
        .alu_operand_a_select   (alu_operand_a_select),
        .alu_operand_b_select   (alu_operand_b_select),
        .data_mem_read_enable   (read_enable_id),
        .data_mem_write_enable  (write_enable_id),
        .reg_writeback_select   (reg_writeback_select),
        .alu_function           (alu_function),
        .next_pc_select         (next_pc_select),
        .branch_ex              (branch_ex),
        .stall_id               (stall_id),
        .stall_ex               (stall_ex),
        .stall_mem              (stall_mem),
        .jump_start             (jump_start),
        .want_stall_id          (want_stall_id),
        .want_stall_mem         (want_stall_mem),
        .inject_bubble_ex       (inject_bubble_ex),
        .inject_bubble_id       (inject_bubble_id),
        .inject_bubble_wb       (inject_bubble_wb)
    );

    data_memory_interface data_memory_interface (
        .clock                  (clock),
        .reset                  (reset),
        .read_enable            (read_enable),
        .write_enable           (write_enable),
        .data_format            (data_format),
        .address                (address),
        .write_data             (write_data),
        .read_data              (read_data),
        .data_available         (data_available),
        .request_successful     (data_request_successful),
        .bus_address            (bus_address),
        .bus_read_data          (bus_read_data),
        .bus_write_data         (bus_write_data),
        .bus_wait_req           (bus_wait_req),
        .bus_valid              (bus_valid),
        .bus_read_enable        (bus_read_enable),
        .bus_write_enable       (bus_write_enable),
        .bus_byte_enable        (bus_byte_enable)
    );

    my_text_memory_interface text_memory_interface (
        .clock                  (clock),
        .reset                  (reset),
        .request_pc             (request_pc),
        .next_inst              (next_inst),
        .inst_read_enable       (inst_read_enable),
        .inst_wait_req          (inst_wait_req),
        .inst_valid             (inst_valid),
        .inst_available         (inst_available),
        .inst_data              (inst_data),
        .inst                   (inst)
    );

    my_text_memory_interface_control text_mem_ctl (
        .clock           (clock),
        .reset           (reset),
        .pc              (pc),
        .next_pc         (next_pc),
        .pc_write_enable (pc_write_enable),
        .next_inst       (next_inst),
        .request_pc      (request_pc)
    );

endmodule

