
VERILATOR_INCLUDE=/usr/share/verilator/include
VERILATED_DIR=verilated
OBJS=$(VERILATED_SRCS:.cpp=.o) main.o
CXXFLAGS=-I ${VERILATOR_INCLUDE} -I ${VERILATOR_INCLUDE}/vltstd -I ${VERILATED_DIR}
SV_SOURCES=$(wildcard ../../core/common/*.sv) $(wildcard ../../core/$(CORETYPE)/*.sv) config.sv ../common_config.sv
VFLAGS=-Wno-fatal -I. -I../../core/common/ -I../../core/$(CORETYPE)
VLOG_FLAGS=-suppress 7061,7033 +incdir+../../core/common +incdir+../../core/$(CORETYPE)
VSIM_FLAGS=${FILE_OPTS} -suppress 7033
VLOG_LIB=sim_comp
FILE_OPTS=+text_file=$(TESTDIR)/$*.text.vh +data_file=$(TESTDIR)/$*.data.vh
TOPLEVEL_MODULE=$(VLOG_LIB).testbench
TRANSCRIPTS_DIR=sim_transcripts
TESTDIR=../../tests
TESTS=$(notdir $(patsubst %.S,%,$(wildcard $(TESTDIR)/*.S)))

run: $(addsuffix .run,$(TESTS))

sim: $(addsuffix .sim_batch,$(TESTS))

%.run: testbench
	./testbench ${FILE_OPTS}

testbench: ${VERILATED_DIR} main.cpp
	${CXX} ${CXXFLAGS} ${VERILATED_DIR}/*.cpp main.cpp ${VERILATOR_INCLUDE}/verilated.cpp -o testbench

main.cpp: ../main.cpp
	cp ../main.cpp .

${VERILATED_DIR}: ${SV_SOURCES}
	verilator ${VFLAGS} --cc ../../core/${CORETYPE}/toplevel.sv --Mdir ${VERILATED_DIR}

${VLOG_LIB}: ${SV_SOURCES} ../testbench.sv
	vlib $@
	vlog -work $@ ${VLOG_FLAGS} $?

%.sim_batch: ${VLOG_LIB}
	mkdir -p ${TRANSCRIPTS_DIR}
	../run_sim batch ${TOPLEVEL_MODULE} $(TRANSCRIPTS_DIR)/$*_transcript ${VSIM_FLAGS}

%.sim: ${VLOG_LIB}
	../run_sim interactive ${TOPLEVEL_MODULE} ${VSIM_FLAGS}

clean:
	rm -rf testbench main.cpp ${OBJS} ${VERILATED_DIR} ${VLOG_LIB} ${TRANSCRIPTS_DIR}

