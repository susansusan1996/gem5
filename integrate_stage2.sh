#!/bin/bash
################################################################################
# Start-Gap 完整整合到 NVMain - 第二階段
# 目標：讓 Start-Gap 真正接入寫入流程
################################################################################

set -e

NVMAIN_DIR="/workspace/gem5/ext/nvmain"
cd $NVMAIN_DIR

echo "=========================================="
echo "Start-Gap 完整整合 - 第二階段"
echo "=========================================="

# ============================================
# 步驟 1：修改 nvmain.h - 加入 StartGap 成員
# ============================================
echo ""
echo "[1/5] 修改 NVMain.h..."

# 備份
cp NVM/nvmain.h NVM/nvmain.h.bak2

# 在 #include 區域加入 StartGap
if ! grep -q "StartGap.h" NVM/nvmain.h; then
    sed -i '/#include "src\/EventQueue.h"/a #include "MemControl/WearLeveling/StartGap.h"' NVM/nvmain.h
    echo "  ✓ 加入 #include StartGap.h"
else
    echo "  ✓ StartGap.h 已存在"
fi

# 在 private 區域加入 startGap 指標
if ! grep -q "StartGap \*startGap" NVM/nvmain.h; then
    # 找到 class NVMain 的 private 區域，在那裡加入
    sed -i '/EventQueue \*eventQueue;/a \    StartGap *startGap;' NVM/nvmain.h
    echo "  ✓ 加入 startGap 成員變數"
else
    echo "  ✓ startGap 成員變數已存在"
fi

# ============================================
# 步驟 2：修改 nvmain.cpp - 初始化和使用 StartGap  
# ============================================
echo ""
echo "[2/5] 修改 NVMain.cpp..."

# 備份
cp NVM/nvmain.cpp NVM/nvmain.cpp.bak2

# 在建構子中初始化 startGap
if ! grep -q "startGap = NULL" NVM/nvmain.cpp; then
    # 找到建構子，在 eventQueue = NULL 後面加
    sed -i '/eventQueue = NULL;/a \    startGap = NULL;' NVM/nvmain.cpp
    echo "  ✓ 在建構子中初始化 startGap"
else
    echo "  ✓ startGap 初始化已存在"
fi

# 在 SetConfig 中創建 StartGap 實例
if ! grep -q "startGap = new StartGap" NVM/nvmain.cpp; then
    # 找到 SetConfig 函數的結尾，在 return true 前加入
    cat >> NVM/nvmain.cpp.tmp << 'ENDPATCH'

// 在 SetConfig 中找到合適的位置插入以下代碼
// 通常在設置完所有其他組件後，return true 之前

// 創建並配置 StartGap
if (startGap == NULL) {
    startGap = new StartGap();
    std::cout << "[NVMain] Creating StartGap wear leveling module..." << std::endl;
}

ENDPATCH

    echo "  ⚠️  需要手動加入 StartGap 初始化到 SetConfig()"
    echo "     參考 nvmain.cpp.tmp"
else
    echo "  ✓ StartGap 創建程式碼已存在"
fi

# 修改 IssueRequest 或 IssueCommand 來調用 StartGap
# 這是最關鍵的步驟！

cat > patch_issue_request.txt << 'ENDPATCH'
找到 NVMain::IssueRequest() 函數，在處理寫入請求時加入：

```cpp
bool NVMain::IssueRequest( NVMainRequest *req )
{
    // ... 原有程式碼 ...
    
    // 如果是寫入請求，調用 StartGap
    if (req->type == WRITE && startGap != NULL) {
        uint64_t logicalAddr = req->address.GetPhysicalAddress();
        uint64_t physicalAddr = startGap->LogicalToPhysical(logicalAddr);
        req->address.SetPhysicalAddress(physicalAddr);
        startGap->OnWrite(logicalAddr);
        
        // 每 1000 次寫入輸出一次統計
        static int writeCount = 0;
        if (++writeCount % 1000 == 0) {
            std::cout << "[NVMain] Processed " << writeCount << " writes" << std::endl;
        }
    }
    
    // ... 繼續原有程式碼 ...
}
```
ENDPATCH

echo "  ⚠️  需要手動修改 IssueRequest - 參考 patch_issue_request.txt"

# ============================================
# 步驟 3：找到正確的注入點
# ============================================
echo ""
echo "[3/5] 分析 NVMain 程式碼結構..."

echo "  查找 IssueRequest 函數..."
grep -n "bool NVMain::IssueRequest" NVM/nvmain.cpp || echo "  未找到 IssueRequest"

echo "  查找 IssueCommand 函數..."
grep -n "bool NVMain::IssueCommand" NVM/nvmain.cpp || echo "  未找到 IssueCommand"

echo "  查找 WRITE 處理..."
grep -n "type == WRITE" NVM/nvmain.cpp | head -5 || echo "  未找到 WRITE 處理"

# ============================================
# 步驟 4：創建自動化修補（如果可能）
# ============================================
echo ""
echo "[4/5] 創建簡化的整合方案..."

# 創建一個簡單的 wrapper 函數
cat > MemControl/WearLeveling/StartGapHook.cpp << 'ENDFILE'
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
ENDFILE

echo "  ✓ 創建 StartGapHook.cpp"

# ============================================
# 步驟 5：提供手動整合指南
# ============================================
echo ""
echo "[5/5] 生成手動整合指南..."

cat > INTEGRATION_MANUAL.md << 'ENDFILE'
# Start-Gap 手動整合指南

## 核心修改

### 1. 修改 NVM/nvmain.cpp 的 SetConfig 函數

找到 `NVMain::SetConfig` 函數，在函數末尾 `return true;` 之前加入：

```cpp
// Create and configure StartGap
if (startGap == NULL) {
    startGap = new StartGap();
    std::cout << "[NVMain] StartGap wear leveling enabled" << std::endl;
}
```

### 2. 修改 NVM/nvmain.cpp 的 IssueRequest 函數

找到 `NVMain::IssueRequest` 函數，在函數開始處加入：

```cpp
bool NVMain::IssueRequest(NVMainRequest *req)
{
    // Start-Gap address translation
    if (startGap != NULL && req->type == WRITE) {
        uint64_t logical = req->address.GetPhysicalAddress();
        uint64_t physical = startGap->LogicalToPhysical(logical);
        req->address.SetPhysicalAddress(physical);
        startGap->OnWrite(logical);
    }
    
    // ... 原有的程式碼 ...
}
```

### 3. 在解構子中清理

找到 `NVMain::~NVMain()` 解構子，加入：

```cpp
if (startGap != NULL) {
    delete startGap;
}
```

## 驗證步驟

編譯並執行後，應該看到：
1. `[NVMain] StartGap wear leveling enabled`
2. 在程式結束時輸出 `========== Start-Gap Statistics ==========`

## 如果看不到輸出

檢查：
1. startGap 是否為 NULL
2. 是否有 WRITE 請求
3. trace 檔案是否有寫入操作
ENDFILE

echo "  ✓ 手動整合指南已生成：INTEGRATION_MANUAL.md"

# ============================================
# 完成
# ============================================
echo ""
echo "=========================================="
echo "第二階段準備完成！"
echo "=========================================="
echo ""
echo "接下來需要手動修改："
echo "  1. 閱讀 INTEGRATION_MANUAL.md"
echo "  2. 編輯 NVM/nvmain.cpp"
echo "  3. 找到 IssueRequest 或相關函數"
echo "  4. 加入 StartGap 調用"
echo ""
echo "或者我們可以先檢查程式碼結構："
echo "  grep -A 20 'IssueRequest' NVM/nvmain.cpp"
echo ""