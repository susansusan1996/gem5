#include "MemControl/WearLeveling/StartGap.h"
#include <iostream>

// 全域 StartGap 實例
static NVM::StartGap* globalStartGap = NULL;

extern "C" {
    void InitStartGap() {
        if (globalStartGap == NULL) {
            globalStartGap = new NVM::StartGap();
            std::cout << "[StartGapHook] Initialized" << std::endl;
        }
    }
    
    unsigned long long ProcessAddress(unsigned long long addr, int isWrite) {
        if (globalStartGap == NULL) {
            InitStartGap();
        }
        
        if (isWrite) {
            globalStartGap->OnWrite(addr);
            return globalStartGap->LogicalToPhysical(addr);
        }
        
        return addr;
    }
    
    void PrintStartGapStats() {
        if (globalStartGap != NULL) {
            globalStartGap->PrintStats();
        }
    }
}
