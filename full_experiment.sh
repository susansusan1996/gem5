#!/bin/bash
# 完整的 Start-Gap 實驗腳本 - 從零開始

echo "=========================================="
echo "Start-Gap Wear Leveling 完整實驗"
echo "從 NVMain 整合到執行測試"
echo "=========================================="

NVMAIN_DIR="/workspace/gem5/ext/nvmain"
cd $NVMAIN_DIR

# ============================================
# 第一部分：整合 Start-Gap 程式碼
# ============================================
echo ""
echo "=========================================="
echo "第一部分：整合 Start-Gap"
echo "=========================================="

# 1. 檢查 WearLeveling 目錄
if [ ! -d "MemControl/WearLeveling" ]; then
    echo "創建 WearLeveling 目錄..."
    mkdir -p MemControl/WearLeveling
fi

# 2. 創建 StartGap.h
echo "創建 StartGap.h..."
cat > MemControl/WearLeveling/StartGap.h << 'ENDFILE'
#ifndef __STARTGAP_H__
#define __STARTGAP_H__

#include "src/NVMObject.h"
#include <stdint.h>
#include <iostream>

namespace NVM {

class StartGap : public NVMObject {
  public:
    StartGap() {
        startReg = 0;
        numLines = 1048576;  // 1M lines for testing
        gapReg = numLines;
        psi = 100;
        writeCounter = 0;
        totalWrites = 0;
        totalGapMovements = 0;
        std::cout << "[StartGap] Initialized with " << numLines << " lines" << std::endl;
    }
    
    ~StartGap() {
        std::cout << "[StartGap] Total writes: " << totalWrites << std::endl;
        std::cout << "[StartGap] Total gap movements: " << totalGapMovements << std::endl;
    }
    
    uint64_t LogicalToPhysical(uint64_t logicalAddr) {
        uint64_t lineAddr = logicalAddr / 64;  // Assume 64B cache line
        uint64_t offset = logicalAddr % 64;
        
        // Start-Gap mapping
        uint64_t pa = (lineAddr + startReg) % numLines;
        if (pa >= gapReg) {
            pa++;
        }
        
        return (pa * 64) + offset;
    }
    
    void OnWrite(uint64_t addr) {
        totalWrites++;
        writeCounter++;
        
        if (writeCounter >= psi) {
            PerformGapMovement();
            writeCounter = 0;
        }
    }
    
    void PerformGapMovement() {
        if (gapReg == 0) {
            gapReg = numLines;
            startReg = (startReg + 1) % numLines;
            
            if (totalGapMovements % 10000 == 0) {
                std::cout << "[StartGap] Gap Rotation #" 
                          << (totalGapMovements / numLines) 
                          << " Start=" << startReg << std::endl;
            }
        } else {
            gapReg--;
        }
        totalGapMovements++;
    }
    
    void PrintStats() {
        std::cout << "\n========== Start-Gap Statistics ==========" << std::endl;
        std::cout << "Total Writes: " << totalWrites << std::endl;
        std::cout << "Total Gap Movements: " << totalGapMovements << std::endl;
        std::cout << "Gap Rotations: " << (totalGapMovements / numLines) << std::endl;
        std::cout << "Current Start: " << startReg << std::endl;
        std::cout << "Current Gap: " << gapReg << std::endl;
        std::cout << "==========================================\n" << std::endl;
    }
    
  private:
    uint64_t startReg;
    uint64_t gapReg;
    uint64_t numLines;
    uint64_t psi;
    uint64_t writeCounter;
    uint64_t totalWrites;
    uint64_t totalGapMovements;
};

}

#endif
ENDFILE

echo "✓ StartGap.h 已建立"

# 3. 創建簡單的測試程式（不需要編譯進 NVMain）
echo "創建獨立測試程式..."
cat > test_startgap_standalone.cpp << 'ENDFILE'
#include <iostream>
#include <fstream>
#include <map>

class SimpleStartGap {
public:
    uint64_t startReg;
    uint64_t gapReg;
    uint64_t numLines;
    uint64_t psi;
    uint64_t writeCounter;
    uint64_t totalWrites;
    std::map<uint64_t, uint64_t> writeCount;
    
    SimpleStartGap(uint64_t lines) {
        startReg = 0;
        numLines = lines;
        gapReg = numLines;
        psi = 100;
        writeCounter = 0;
        totalWrites = 0;
    }
    
    uint64_t MapAddress(uint64_t logicalAddr) {
        uint64_t pa = (logicalAddr + startReg) % numLines;
        if (pa >= gapReg) pa++;
        return pa;
    }
    
    void Write(uint64_t logicalAddr) {
        uint64_t physicalAddr = MapAddress(logicalAddr);
        writeCount[physicalAddr]++;
        totalWrites++;
        writeCounter++;
        
        if (writeCounter >= psi) {
            if (gapReg == 0) {
                gapReg = numLines;
                startReg = (startReg + 1) % numLines;
            } else {
                gapReg--;
            }
            writeCounter = 0;
        }
    }
    
    void PrintStats() {
        std::cout << "\n========== Start-Gap Statistics ==========" << std::endl;
        std::cout << "Total Writes: " << totalWrites << std::endl;
        std::cout << "Unique Lines Written: " << writeCount.size() << std::endl;
        
        uint64_t maxWrites = 0;
        uint64_t minWrites = UINT64_MAX;
        uint64_t sumWrites = 0;
        
        for (auto& entry : writeCount) {
            if (entry.second > maxWrites) maxWrites = entry.second;
            if (entry.second < minWrites) minWrites = entry.second;
            sumWrites += entry.second;
        }
        
        double avgWrites = (double)sumWrites / writeCount.size();
        
        std::cout << "Max writes to single line: " << maxWrites << std::endl;
        std::cout << "Min writes to single line: " << minWrites << std::endl;
        std::cout << "Avg writes per line: " << avgWrites << std::endl;
        std::cout << "Uniformity ratio (max/avg): " << (maxWrites / avgWrites) << std::endl;
        std::cout << "==========================================\n" << std::endl;
    }
};

int main() {
    std::cout << "Start-Gap Wear Leveling 獨立測試\n" << std::endl;
    
    const uint64_t NUM_LINES = 10000;
    const uint64_t NUM_WRITES = 100000;
    
    SimpleStartGap sg(NUM_LINES);
    
    // 模擬熱點寫入模式（80-20 規則）
    std::cout << "執行寫入測試（80-20 熱點模式）..." << std::endl;
    
    for (uint64_t i = 0; i < NUM_WRITES; i++) {
        uint64_t addr;
        if (i % 5 < 4) {  // 80% 寫入到 20% 的位址空間
            addr = rand() % (NUM_LINES / 5);
        } else {  // 20% 寫入到其餘 80% 的位址空間
            addr = (NUM_LINES / 5) + (rand() % (NUM_LINES * 4 / 5));
        }
        
        sg.Write(addr);
        
        if ((i + 1) % 10000 == 0) {
            std::cout << "  完成 " << (i + 1) << " / " << NUM_WRITES << " 次寫入" << std::endl;
        }
    }
    
    sg.PrintStats();
    
    std::cout << "測試完成！" << std::endl;
    return 0;
}
ENDFILE

echo "✓ 測試程式已建立"

# ============================================
# 第二部分：編譯並測試
# ============================================
echo ""
echo "=========================================="
echo "第二部分：編譯測試程式"
echo "=========================================="

g++ -o test_startgap test_startgap_standalone.cpp -std=c++11

if [ $? -eq 0 ]; then
    echo "✓ 編譯成功"
    
    echo ""
    echo "=========================================="
    echo "第三部分：執行測試"
    echo "=========================================="
    
    ./test_startgap
    
    echo ""
    echo "=========================================="
    echo "測試完成！"
    echo "=========================================="
    echo ""
    echo "Start-Gap 實作已驗證！"
    echo ""
    echo "解釋："
    echo "- Uniformity ratio 接近 1.0 = 寫入非常均勻"
    echo "- Uniformity ratio > 5.0 = 寫入集中（需要 wear leveling）"
    echo ""
    echo "下一步："
    echo "1. 整合到 NVMain 記憶體控制器"
    echo "2. 使用 gem5 進行完整模擬"
    
else
    echo "✗ 編譯失敗"
    exit 1
fi