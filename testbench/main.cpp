// RISC-V SiMPLE SV -- testbench
// BSD 3-Clause License
// (c) 2019, Marek Materzok, University of Wrocław

#include "Vriscv_core.h"
#include "verilated.h"
#include <iostream>
#include <iomanip>
#include <memory>
#include <string>

std::string text_file, data_file;

extern "C" const char* text_mem_file()
{
    return text_file.c_str();
}

extern "C" const char* data_mem_file()
{
    return data_file.c_str();
}

int main(int argc, const char **argv, const char **env)
{
    Verilated::commandArgs(argc, argv);

    const char *str;
    str = Verilated::commandArgsPlusMatch("text_file=");
    if (str) text_file = str + 11;
    str = Verilated::commandArgsPlusMatch("data_file=");
    if (str) data_file = str + 11;

    std::unique_ptr<Vriscv_core> top(new Vriscv_core);

    top->reset = 0;

    for (int time = 0; time < 100000; time++) {
        if (time > 10)
            top->reset = 0;
        else if (time > 4)
            top->reset = 1;
        top->clock = time & 1;
        top->eval();
        if (top->clock) {
            std::cout << std::hex << std::setfill('0')
                      << "pc=" << std::setw(8) << top->pc << " "
                      << "inst=" << std::setw(8) << top->inst << " "
                      << "addr=" << std::setw(8) << top->bus_address << " "
                      << "in=" << std::setw(8) << top->bus_data_fetched << " "
                      << (top->bus_read_enable ? "1" : "0") << " "
                      << "out=" << std::setw(8) << top->bus_write_data << " "
                      << (top->bus_write_enable ? "1" : "0") << " " << std::endl;
        }
        if (top->bus_write_enable && top->bus_address == 0xfffffff0) {
            if (top->bus_write_data) {
                std::cout << "PASS" << std::endl;
                return 0;
            } else {
                std::cout << "FAIL" << std::endl;
                return -1;
            }
        }
    }

    std::cout << "TIMEOUT" << std::endl;

    return -1;
}
