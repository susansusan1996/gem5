#include "MemControl/WearLeveling/StartGap.h"
#include <iostream>
#include <algorithm>
#include <cmath>

using namespace NVM;

StartGap::StartGap() {
    // 初始化 Start-Gap 暫存器
    numLines = 1000;  // 1萬 cache lines
    psi = 2;           // 每 2 次寫入移動 Gap
    startReg = 0;
    gapReg = numLines;   // Gap 初始在範圍外
    
    // 統計初始化
    writeCounter = 0;
    totalWrites = 0;
    totalGapMovements = 0;
    
    std::cout << "[StartGap] Initialized: " 
              << "numLines=" << numLines 
              << ", psi=" << psi << std::endl;
}

StartGap::~StartGap() {
    PrintStats();
}

uint64_t StartGap::LogicalToPhysical(uint64_t logicalAddr) {
    // 轉換為 cache line 號碼
    uint64_t lineNum = logicalAddr / 64;  // 假設 64B cache line
    lineNum = lineNum % numLines;
    
    // Start-Gap 映射: PA = (LA + Start) mod N
    uint64_t physicalLine = (lineNum + startReg) % numLines;
    
    // 如果 PA >= Gap, 則 PA++
    if (physicalLine >= gapReg) {
        physicalLine++;
        if (physicalLine >= numLines) {
            physicalLine = 0;
        }
    }
    
    // 轉回字節地址
    return physicalLine * 64;
}

void StartGap::OnWrite(uint64_t addr) {
    totalWrites++;
    writeCounter++;
    
    // ========== 新增：磨損追蹤 ==========
    // 計算物理地址
    uint64_t physicalAddr = LogicalToPhysical(addr);
    uint64_t physicalLine = physicalAddr / 64;
    
    // 記錄這個物理位置被寫入了一次
    wearMap[physicalLine]++;
    // ===================================
    
    // 每 ψ 次寫入，移動 Gap
    if (writeCounter >= psi) {
        moveGap();
        writeCounter = 0;
    }
    
    // 定期輸出統計 (每 10000 次寫入)
    if (totalWrites % 10000 == 0) {
        std::cout << "[StartGap] Processed " << totalWrites 
                  << " writes, Gap movements: " << totalGapMovements 
                  << ", Uniformity ratio: " << getUniformityRatio() 
                  << std::endl;
    }
}

void StartGap::moveGap() {
    // Gap Movement: Gap--
    if (gapReg == 0) {
        gapReg = numLines;
        startReg = (startReg + 1) % numLines;
    } else {
        gapReg--;
    }
    
    totalGapMovements++;
}

// ========== 新增：磨損分析函數 ==========

uint64_t StartGap::getMaxWear() {
    if (wearMap.empty()) return 0;
    
    uint64_t maxWear = 0;
    for (auto& pair : wearMap) {
        if (pair.second > maxWear) {
            maxWear = pair.second;
        }
    }
    return maxWear;
}

uint64_t StartGap::getMinWear() {
    if (wearMap.empty()) return 0;
    
    uint64_t minWear = UINT64_MAX;
    for (auto& pair : wearMap) {
        if (pair.second < minWear) {
            minWear = pair.second;
        }
    }
    return minWear;
}

double StartGap::getAverageWear() {
    if (wearMap.empty()) return 0.0;
    
    uint64_t totalWear = 0;
    for (auto& pair : wearMap) {
        totalWear += pair.second;
    }
    return static_cast<double>(totalWear) / wearMap.size();
}

double StartGap::getUniformityRatio() {
    uint64_t maxWear = getMaxWear();
    uint64_t minWear = getMinWear();
    
    if (minWear == 0) return 0.0;
    return static_cast<double>(maxWear) / minWear;
}

// ========================================

void StartGap::PrintStats() {
    std::cout << "\n=========================================="  << std::endl;
    std::cout << "========== Start-Gap Statistics ==========" << std::endl;
    std::cout << "==========================================" << std::endl;
    std::cout << "Total Writes:         " << totalWrites << std::endl;
    std::cout << "Gap Movements:        " << totalGapMovements << std::endl;
    std::cout << "Unique Lines Written: " << wearMap.size() << std::endl;
    std::cout << "Max Wear:             " << getMaxWear() << std::endl;
    std::cout << "Min Wear:             " << getMinWear() << std::endl;
    std::cout << "Average Wear:         " << getAverageWear() << std::endl;
    std::cout << "Uniformity Ratio:     " << getUniformityRatio() << std::endl;
    std::cout << "==========================================" << std::endl;
    
    // 計算壽命 (假設 PCM endurance = 10^8 writes)
    uint64_t pcmEndurance = 100000000;  // 10^8
    uint64_t maxWear = getMaxWear();
    if (maxWear > 0) {
        uint64_t estimatedLifetime = pcmEndurance / maxWear;
        std::cout << "Estimated Lifetime:   " << estimatedLifetime 
                  << " * total_writes" << std::endl;
        std::cout << "  (可承受 " << estimatedLifetime << " 倍的當前寫入量)" << std::endl;
    }
    std::cout << "==========================================" << std::endl << std::endl;
}

void StartGap::Cycle(ncycle_t steps) {
    // Start-Gap 不需要每週期處理
}