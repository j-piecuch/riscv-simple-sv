
module inst_cache #(
    parameter OFFSET_BITS = 6,
    parameter INDEX_BITS  = 6,
    parameter SET_SIZE    = 4,
`ifdef ICACHE_BURST
    parameter WORDS_IN_BURST = LINE_BYTES / RAM_WORD_BYTES,
`endif
    parameter RAM_WORD_BYTES = 4
) (
		input  clock,
		input  reset,

    // Interface to main memory
		output [31:0] ram_address,
		output        ram_read_enable,
		input  [RAM_WORD_BYTES*8-1:0] ram_read_data,
		input         ram_waitrequest,
`ifdef ICACHE_BURST
		output [$clog2(WORDS_IN_BURST+1)-1:0]  ram_burstcount,
`endif
		input         ram_read_data_valid,

    // Interface to user
		input [31:0]       cache_address,
		output [31:0] cache_inst,
		output cache_waitrequest,
		input  cache_read_enable,
		output cache_inst_valid
);

    localparam TAG_BITS = 32 - OFFSET_BITS - INDEX_BITS;
    localparam RAM_WORD_BITS = RAM_WORD_BYTES * 8;
    localparam NUM_SETS = 2 ** INDEX_BITS;
    localparam LINE_BYTES = 2 ** OFFSET_BITS;
    localparam LINE_BITS = LINE_BYTES * 8;
    localparam INSTS_IN_LINE = LINE_BYTES / 4;
    localparam INSTS_IN_LINE_BITS = $clog2(INSTS_IN_LINE);
    localparam WORDS_IN_LINE = LINE_BYTES / RAM_WORD_BYTES;
    localparam WORDS_IN_LINE_BITS = $clog2(WORDS_IN_LINE);
`ifndef ICACHE_BURST
    localparam WORDS_IN_BURST = 1;
`endif

    localparam STATE_BITS  = 2;
    localparam STATE_INIT = 2'b00;
    localparam STATE_FETCH = 2'b01;
    localparam STATE_WB = 2'b10;

    logic [OFFSET_BITS-1:0] offset;
    logic [STATE_BITS-1:0] state;
    logic [NUM_SETS-1:0]   set_select;
    logic [NUM_SETS-1:0]   set_read_enable;
    logic [NUM_SETS-1:0]   set_write_enable;
    logic [INDEX_BITS-1:0] index;
    logic [TAG_BITS-1:0]   tag;

    // temporary line to store line fetched from memory
    logic [LINE_BITS-1:0]  temp_line;
    // word-by-word view into the temporary line
    logic [WORDS_IN_LINE-1:0][RAM_WORD_BITS-1:0] temp_line_words;

    // line read from the selected set
    wire [LINE_BITS-1:0] set_read_line;
    // instruction-by-instruction view into the read line
    logic [INSTS_IN_LINE-1:0][31:0] set_read_line_insts;
    logic [NUM_SETS-1:0] set_read_data_valid;

    logic cache_miss;
    logic [WORDS_IN_LINE_BITS-1:0] temp_word_index;
    logic [WORDS_IN_LINE_BITS:0] end_index;
    logic [INSTS_IN_LINE_BITS-1:0] inst_index;
    logic [INSTS_IN_LINE-1:0] inst_select;


    assign {tag, index, offset} = cache_address;
    assign set_select = 1 << index;

    assign inst_index = cache_address[OFFSET_BITS-1:2];
    assign inst_select = 1 << inst_index;

    assign cache_inst_valid = |set_read_data_valid;
    assign cache_miss = cache_read_enable && !(|set_read_data_valid);

    assign cache_waitrequest = cache_miss;

`ifdef ICACHE_BURST
    assign ram_burstcount = WORDS_IN_BURST;
`endif

    assign temp_line = temp_line_words;
    assign set_read_line_insts = set_read_line;

    genvar i;
    generate

        for (i = 0; i < NUM_SETS; i = i + 1) begin : set_read_enable_loop
            assign set_read_enable[i] = set_select[i] && cache_read_enable && state == STATE_INIT;
        end

        for (i = 0; i < NUM_SETS; i = i + 1) begin : set_write_enable_loop
            assign set_write_enable[i] = set_select[i] && state == STATE_WB;
        end

        for (i = 0; i < INSTS_IN_LINE; i = i + 1) begin : cache_inst_loop
            assign cache_inst = inst_select[i] ? set_read_line_insts[i] : 32'bz;
        end

        for (i = 0; i < WORDS_IN_LINE; i = i + 1) begin : temp_line_words_loop
            always @(posedge clock)
                if (ram_read_data_valid && temp_word_index == i)
                    temp_line_words[i] <= ram_read_data;
        end

        for (i = 0; i < NUM_SETS; i = i + 1) begin : set_loop
            inst_cache_set #(
                .SET_SIZE(SET_SIZE),
                .TAG_BITS(TAG_BITS),
                .LINE_BITS(LINE_BITS)
            ) set (
                .clock(clock),
                .reset(reset),
                .tag(tag),
                .write_data(temp_line),
                .write_enable(set_write_enable[i]),
                .read_data(set_read_line),
                .read_data_valid(set_read_data_valid[i]),
                .read_enable(set_read_enable[i])
            );
        end // block: set_loop

    endgenerate

    assign ram_address = {cache_address[31:OFFSET_BITS], end_index[0 +: WORDS_IN_LINE_BITS], {($clog2(RAM_WORD_BYTES)){1'b0}}};
    assign ram_read_enable = state == STATE_FETCH && end_index < WORDS_IN_LINE;

    always @(posedge clock) begin
        if (reset) begin
            state           <= STATE_INIT;
            temp_word_index <= 0;
            end_index       <= 0;
        end else begin
            case (state)
              STATE_INIT:
                  if (cache_miss) begin
                      state           <= STATE_FETCH;
                      temp_word_index <= 0;
                      end_index       <= 0;
                  end
              STATE_FETCH: begin
                  if (ram_read_enable && !ram_waitrequest) begin
                      end_index <= end_index + WORDS_IN_BURST;
                  end
                  if (ram_read_data_valid) begin
                      temp_word_index <= temp_word_index + 1;
                      if (temp_word_index == WORDS_IN_LINE - 1) begin
                          // we have fetched the full line from RAM
                          state <= STATE_WB;
                      end
                  end
              end // case: STATE_FETCH
              STATE_WB:
                  state <= STATE_INIT;
              default: ;
            endcase // case (state)
        end
    end // always @ (posedge clock)

endmodule // inst_cache


module inst_cache_set #(
    parameter SET_SIZE    = 4,
    parameter TAG_BITS,
    parameter LINE_BITS
) (
    input clock,
    input reset,

    input [TAG_BITS-1:0] tag,
    input [LINE_BITS-1:0] write_data,
    input write_enable,

    inout [LINE_BITS-1:0] read_data,
    output read_data_valid,
    input read_enable
);

    typedef struct packed {
        logic [TAG_BITS-1:0] tag;
        logic [LINE_BITS-1:0] data;
    } line_t;

    logic [SET_SIZE-1:0] valid;
    logic [SET_SIZE-1:0] match;
    logic [SET_SIZE-1:0] valid_match;
    logic [SET_SIZE-1:0] evict;
    logic [LINE_BITS-1:0] internal_read_data;

    line_t lines[0:SET_SIZE-1];

    evict_line_select #(
        .SET_SIZE(SET_SIZE)
    ) evict_sel (
        .clock(clock),
        .reset(reset),
        .read_data_valid(read_data_valid),
        .valid_match(valid_match),
        .evict(evict)
   );

    genvar i;
    generate
        for (i = 0; i < SET_SIZE; i = i + 1) begin : match_loop
            assign match[i] = tag == lines[i].tag;
        end

        for (i = 0; i < SET_SIZE; i = i + 1) begin : valid_match_loop
            assign valid_match[i] = match[i] && valid[i];
        end

        for (i = 0; i < SET_SIZE; i = i + 1) begin : data_loop
            always_comb internal_read_data = valid_match[i] ? lines[i].data : {(LINE_BITS){1'bz}};
        end

        for (i = 0; i < SET_SIZE; i = i + 1) begin : write_loop
            always @(posedge clock)
                if (reset) valid[i] <= 1'b0;
                else if (write_enable && evict[i]) begin
                    lines[i].tag  <= tag;
                    lines[i].data <= write_data;
                    valid[i]      <= 1'b1;
                end
        end
    endgenerate

    assign read_data_valid = |valid_match && read_enable;
    assign read_data = read_enable ? internal_read_data : {(LINE_BITS){1'bz}};

endmodule // inst_cache_set


module evict_line_select #(
    parameter SET_SIZE = 4
) (
    input clock,
    input reset,
    input read_data_valid,
    input [SET_SIZE-1:0] valid_match,
    output [SET_SIZE-1:0] evict
);

    localparam SIZE_BITS = $clog2(SET_SIZE);

    logic [SIZE_BITS-1:0] pos[SET_SIZE];
    logic [SIZE_BITS-1:0] selected_pos;

    genvar i;
    generate
        for (i = 0; i < SET_SIZE; i = i + 1) begin : selected_pos_loop
            always_comb selected_pos = valid_match[i] ? pos[i] : {(SIZE_BITS){1'bz}};
        end

        for (i = 0; i < SET_SIZE; i = i + 1) begin : evict_loop
            assign evict[i] = pos[i] == SET_SIZE - 1;
        end

        for (i = 0; i < SET_SIZE; i = i + 1) begin : pos_loop
            always @(posedge clock)
                if (reset)
                    pos[i] <= i;
                else if (read_data_valid)
                    pos[i] <= pos[i] < selected_pos ? pos[i] + 1 :
                              pos[i] == selected_pos ? 0 : pos[i];
        end
    endgenerate

endmodule // evict_line_select
