#!/bin/bash
################################################################################
# Start-Gap 完整整合到 NVMain
# 步驟 1：修改記憶體控制器來使用 Start-Gap
################################################################################

set -e  # 遇到錯誤立即停止

NVMAIN_DIR="/workspace/gem5/ext/nvmain"
cd $NVMAIN_DIR

echo "=========================================="
echo "Step 1: 整合 Start-Gap 到 NVMain"
echo "=========================================="

# ============================================
# 1.1 確認 StartGap 類別存在
# ============================================
echo ""
echo "[1/6] 檢查 StartGap 類別..."

if [ ! -f "MemControl/WearLeveling/StartGap.h" ]; then
    echo "❌ StartGap.h 不存在，正在創建..."
    mkdir -p MemControl/WearLeveling
    
    cat > MemControl/WearLeveling/StartGap.h << 'ENDFILE'
#ifndef __STARTGAP_H__
#define __STARTGAP_H__

#include "src/NVMObject.h"
#include "src/Params.h"
#include <stdint.h>
#include <iostream>

namespace NVM {

class StartGap : public NVMObject {
  public:
    StartGap();
    ~StartGap();
    
    void SetConfig(Config *conf, bool createChildren = true);
    
    // 核心功能
    uint64_t LogicalToPhysical(uint64_t logicalAddr);
    void OnWrite(uint64_t addr);
    void PrintStats();
    
  private:
    uint64_t startReg;
    uint64_t gapReg;
    uint64_t numLines;
    uint64_t psi;              // Gap Write Interval
    uint64_t writeCounter;
    uint64_t totalWrites;
    uint64_t totalGapMovements;
    uint64_t totalGapRotations;
    
    bool enableWearLeveling;
    bool printDebug;
};

}

#endif
ENDFILE
    echo "✓ StartGap.h 已創建"
else
    echo "✓ StartGap.h 已存在"
fi

# ============================================
# 1.2 創建 StartGap 實作
# ============================================
echo ""
echo "[2/6] 創建 StartGap 實作..."

cat > MemControl/WearLeveling/StartGap.cpp << 'ENDFILE'
#include "MemControl/WearLeveling/StartGap.h"

using namespace NVM;

StartGap::StartGap() {
    startReg = 0;
    gapReg = 0;
    numLines = 67108864;  // 64M lines (16GB / 256B)
    psi = 100;
    writeCounter = 0;
    totalWrites = 0;
    totalGapMovements = 0;
    totalGapRotations = 0;
    enableWearLeveling = true;
    printDebug = false;
}

StartGap::~StartGap() {
    if (totalWrites > 0) {
        PrintStats();
    }
}

void StartGap::SetConfig(Config *conf, bool createChildren) {
    if (conf->KeyExists("MemoryLines")) {
        numLines = conf->GetValue("MemoryLines");
    }
    
    if (conf->KeyExists("GapWriteInterval")) {
        psi = conf->GetValue("GapWriteInterval");
    }
    
    if (conf->KeyExists("EnableWearLeveling")) {
        std::string val = conf->GetString("EnableWearLeveling");
        enableWearLeveling = (val == "true" || val == "True" || val == "1");
    }
    
    if (conf->KeyExists("WearLevelingDebug")) {
        std::string val = conf->GetString("WearLevelingDebug");
        printDebug = (val == "true" || val == "True" || val == "1");
    }
    
    // 初始化 Gap 指向最後一條線
    gapReg = numLines;
    
    std::cout << "[StartGap] Configuration:" << std::endl;
    std::cout << "  Memory Lines: " << numLines << std::endl;
    std::cout << "  Gap Write Interval (ψ): " << psi << std::endl;
    std::cout << "  Wear Leveling: " << (enableWearLeveling ? "Enabled" : "Disabled") << std::endl;
}

uint64_t StartGap::LogicalToPhysical(uint64_t logicalAddr) {
    if (!enableWearLeveling) {
        return logicalAddr;
    }
    
    // 假設 256B cache line
    uint64_t lineAddr = logicalAddr / 256;
    uint64_t offset = logicalAddr % 256;
    
    // Start-Gap 映射
    uint64_t physicalLine = (lineAddr + startReg) % numLines;
    
    if (physicalLine >= gapReg) {
        physicalLine++;
    }
    
    return (physicalLine * 256) + offset;
}

void StartGap::OnWrite(uint64_t addr) {
    if (!enableWearLeveling) {
        return;
    }
    
    totalWrites++;
    writeCounter++;
    
    // 每 psi 次寫入執行 Gap Movement
    if (writeCounter >= psi) {
        // Gap Movement
        if (gapReg == 0) {
            // Gap Rotation
            gapReg = numLines;
            startReg = (startReg + 1) % numLines;
            totalGapRotations++;
            
            if (printDebug && (totalGapRotations % 100 == 0)) {
                std::cout << "[StartGap] Gap Rotation #" << totalGapRotations 
                          << ", Start=" << startReg << std::endl;
            }
        } else {
            gapReg--;
        }
        
        totalGapMovements++;
        writeCounter = 0;
    }
}

void StartGap::PrintStats() {
    std::cout << "\n========== Start-Gap Statistics ==========" << std::endl;
    std::cout << "Total Writes: " << totalWrites << std::endl;
    std::cout << "Total Gap Movements: " << totalGapMovements << std::endl;
    std::cout << "Total Gap Rotations: " << totalGapRotations << std::endl;
    std::cout << "Current Start Register: " << startReg << std::endl;
    std::cout << "Current Gap Register: " << gapReg << std::endl;
    std::cout << "Gap Write Interval (ψ): " << psi << std::endl;
    
    if (totalGapMovements > 0) {
        double rotationProgress = (double)totalGapMovements / numLines;
        std::cout << "Rotation Progress: " << rotationProgress << " times" << std::endl;
    }
    
    std::cout << "==========================================\n" << std::endl;
}
ENDFILE

echo "✓ StartGap.cpp 已創建"

# ============================================
# 1.3 創建 SConscript
# ============================================
echo ""
echo "[3/6] 創建 WearLeveling SConscript..."

cat > MemControl/WearLeveling/SConscript << 'ENDFILE'
Import('*')

sources = [
    'StartGap.cpp',
]

env.NVMainSource(sources)
ENDFILE

echo "✓ WearLeveling/SConscript 已創建"

# ============================================
# 1.4 修改 NVMain 主檔案
# ============================================
echo ""
echo "[4/6] 修改 NVMain 主類別..."

# 備份原始檔案
cp NVM/nvmain.h NVM/nvmain.h.backup
cp NVM/nvmain.cpp NVM/nvmain.cpp.backup

# 檢查是否已經包含 StartGap
if grep -q "StartGap" NVM/nvmain.h; then
    echo "✓ nvmain.h 已經包含 StartGap"
else
    echo "正在修改 nvmain.h..."
    
    # 在 nvmain.h 中加入 StartGap 的 include 和成員變數
    sed -i '/#include "src\/EventQueue.h"/a #include "MemControl/WearLeveling/StartGap.h"' NVM/nvmain.h
    
    # 在 private 區域加入 StartGap 指標
    sed -i '/MemoryController \*memoryControllers;/a \    StartGap *startGap;' NVM/nvmain.h
    
    echo "✓ nvmain.h 已修改"
fi

# 修改 nvmain.cpp
if grep -q "startGap = new StartGap" NVM/nvmain.cpp; then
    echo "✓ nvmain.cpp 已經初始化 StartGap"
else
    echo "正在修改 nvmain.cpp..."
    
    # 在建構子中初始化
    sed -i '/memoryControllers = NULL;/a \    startGap = NULL;' NVM/nvmain.cpp
    
    # 在 SetConfig 中創建和配置 StartGap
    cat >> NVM/nvmain.cpp << 'ENDCODE'

// Start-Gap Wear Leveling Integration
void NVMain::InitStartGap(Config *config) {
    if (startGap == NULL) {
        startGap = new StartGap();
        startGap->SetConfig(config, false);
    }
}
ENDCODE
    
    echo "✓ nvmain.cpp 已修改"
fi

echo "⚠️  注意：需要手動在 NVMain::SetConfig() 中呼叫 InitStartGap(config)"

# ============================================
# 1.5 創建測試配置檔
# ============================================
echo ""
echo "[5/6] 創建測試配置檔..."

cat > Config/StartGap_PCM.config << 'ENDFILE'
;================================================================================
; Start-Gap Wear Leveling Configuration for PCM
; 基於論文 MICRO'09
;================================================================================

; Memory Organization
Channels 1
Ranks 1
Banks 4
Rows 8192
Cols 8192

; Device Parameters  
BusWidth 64
DeviceWidth 8
BurstLength 8
CacheLineSize 256

; Timing Parameters (簡化測試)
CPUFreq 2000
CLK 800

tCL 50
tRCD 50
tRP 50  
tCWL 40
tWR 40
tRAS 80
tRTP 20
tCCD 8
tRFC 200
tWL 40

; Memory Controller
MEM_CTL FCFS
INTERCONNECT OffChipBus

; Start-Gap Parameters
EnableWearLeveling true
MemoryLines 262144
GapWriteInterval 100
WearLevelingDebug false

; Statistics
PrintStats true
PrintConfig true
ENDFILE

echo "✓ 測試配置檔已創建"

# ============================================
# 1.6 創建測試 trace
# ============================================
echo ""
echo "[6/6] 創建測試 trace..."

cat > test_wear.trace << 'ENDFILE'
# Simple wear test trace
# Format: cycle address operation
# 熱點寫入模式
1 0x0000 W
2 0x0000 W
3 0x0000 W
4 0x0100 W
5 0x0200 W
10 0x0000 W
11 0x0000 W
12 0x0000 W
15 0x0300 W
16 0x0400 W
20 0x0000 W
21 0x0000 W
22 0x0000 W
25 0x0500 W
26 0x0600 W
ENDFILE

echo "✓ 測試 trace 已創建"

# ============================================
# 完成
# ============================================
echo ""
echo "=========================================="
echo "✓ Step 1 完成！"
echo "=========================================="
echo ""
echo "已完成："
echo "  ✓ StartGap 類別實作"
echo "  ✓ 修改 NVMain 主檔案"
echo "  ✓ 創建測試配置和 trace"
echo ""
echo "下一步："
echo "  1. 重新編譯 NVMain"
echo "  2. 執行測試"
echo ""
echo "執行以下命令進行編譯："
echo "  cd /workspace/gem5/ext/nvmain"
echo "  scons --clean"
echo "  scons --build-type=fast -j4"
echo ""