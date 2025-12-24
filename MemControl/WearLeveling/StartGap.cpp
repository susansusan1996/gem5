#include "MemControl/WearLeveling/StartGap.h"
#include <iostream>

using namespace NVM;

StartGap::StartGap() {
    startReg = 0;
    numLines = 1048576;
    gapReg = numLines;
    psi = 100;
    writeCounter = 0;
    totalWrites = 0;
    totalGapMovements = 0;
}

StartGap::~StartGap() {
    PrintStats();
}

uint64_t StartGap::LogicalToPhysical(uint64_t logicalAddr) {
    uint64_t lineAddr = logicalAddr / 256;
    uint64_t offset = logicalAddr % 256;
    uint64_t physicalLine = (lineAddr + startReg) % numLines;
    if (physicalLine >= gapReg) {
        physicalLine++;
    }
    return (physicalLine * 256) + offset;
}

void StartGap::OnWrite(uint64_t addr) {
    totalWrites++;
    writeCounter++;
    
    // Debug output
    if (totalWrites <= 20 || totalWrites % 100 == 0) {
        std::cout << "[StartGap] Write #" << totalWrites 
                  << " addr=0x" << std::hex << addr << std::dec
                  << " writeCounter=" << writeCounter << std::endl;
    }
    
    if (writeCounter >= psi) {
        if (gapReg == 0) {
            gapReg = numLines;
            startReg = (startReg + 1) % numLines;
        } else {
            gapReg--;
        }
        totalGapMovements++;
        std::cout << "[StartGap] Gap moved! totalGapMovements=" << totalGapMovements 
                  << " gapReg=" << gapReg << " startReg=" << startReg << std::endl;
        writeCounter = 0;
    }
}

void StartGap::PrintStats() {
    std::cout << "\n========== Start-Gap Statistics ==========" << std::endl;
    std::cout << "Total Writes: " << totalWrites << std::endl;
    std::cout << "Total Gap Movements: " << totalGapMovements << std::endl;
    std::cout << "==========================================\n" << std::endl;
}

void StartGap::Cycle(ncycle_t steps) {
    // Start-Gap doesn't need to do anything per cycle
    // All logic is handled in OnWrite()
}
