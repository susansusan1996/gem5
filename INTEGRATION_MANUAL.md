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
