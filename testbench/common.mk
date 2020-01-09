
VERILATOR_INCLUDE=/usr/share/verilator/include
VERILATED_SRCS=Vtoplevel.cpp Vtoplevel__Syms.cpp Vtoplevel___024unit.cpp
OBJS=$(VERILATED_SRCS:.cpp=.o) main.o
CXXFLAGS=-I ${VERILATOR_INCLUDE} -I ${VERILATOR_INCLUDE}/vltstd
SV_SOURCES=$(wildcard ../../core/common/*.sv) $(wildcard ../../core/$(CORETYPE)/*.sv) config.sv
VFLAGS=-Wno-fatal -I. -I../../core/common/ -I../../core/$(CORETYPE)
VLOG_FLAGS=-suppress 7061 +incdir+../../core/common +incdir+../../core/$(CORETYPE)
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

testbench: ${OBJS}
	${CXX} ${CXXFLAGS} ${OBJS} ${VERILATOR_INCLUDE}/verilated.cpp -o testbench

%.o: %.cpp
	${CXX} ${CXXFLAGS} -c -o $@ $<

main.cpp: ../main.cpp
	cp ../main.cpp .

${VERILATED_SRCS}: ${SV_SOURCES}
	verilator ${VFLAGS} --cc ../../core/${CORETYPE}/toplevel.sv --Mdir .

${VLOG_LIB}: ${SV_SOURCES} ../testbench.sv
	vlib $@
	vlog -work $@ ${VLOG_FLAGS} $?

%.sim_batch: ${VLOG_LIB}
	mkdir -p ${TRANSCRIPTS_DIR}
	../run_sim batch ${TOPLEVEL_MODULE} $(TRANSCRIPTS_DIR)/$*_transcript ${FILE_OPTS}

%.sim: ${VLOG_LIB}
	../run_sim interactive ${TOPLEVEL_MODULE} ${FILE_OPTS}

clean:
	rm -rf testbench main.cpp ${OBJS} ${wildcard V*} ${VLOG_LIB} ${TRANSCRIPTS_DIR}

