#ifndef __STARTGAP_H__
#define __STARTGAP_H__

#include "src/NVMObject.h"
#include <stdint.h>
#include <map>

namespace NVM {

class StartGap : public NVMObject {
  public:
    StartGap();
    ~StartGap();
    
    uint64_t LogicalToPhysical(uint64_t logicalAddr);
    void OnWrite(uint64_t addr);
    void PrintStats();
    void Cycle(ncycle_t steps);
    
  private:
    // Start-Gap 暫存器
    uint64_t startReg;
    uint64_t gapReg;
    uint64_t numLines;
    uint64_t psi;  // Gap 移動間隔
    
    // 統計
    uint64_t writeCounter;
    uint64_t totalWrites;
    uint64_t totalGapMovements;
    
    // ========== 新增：磨損追蹤 ==========
    // 記錄每個物理地址被寫入的次數
    std::map<uint64_t, uint64_t> wearMap;
    
    // 輔助函數
    void moveGap();
    uint64_t getMaxWear();        // 最大磨損次數
    uint64_t getMinWear();        // 最小磨損次數
    double getAverageWear();      // 平均磨損次數
    double getUniformityRatio();  // 均勻度比率 (Max/Min)
};

}

#endif
