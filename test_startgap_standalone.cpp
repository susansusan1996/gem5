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
