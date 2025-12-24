cd /work

# 測試修復後的版本
echo "=========================================="
echo "測試 Start-Gap 統計輸出"
echo "=========================================="
./nvmain.fast Config/PCM_ISSCC_2012_4GB.config test_150_writes.trace 200000 2>&1 | grep -E "\[StartGap\]|Start-Gap|Gap moved" | head -10

# 查看完整統計
echo ""
echo "=========================================="
echo "查看完整的 Start-Gap 統計"
echo "=========================================="
./nvmain.fast Config/PCM_ISSCC_2012_4GB.config test_150_writes.trace 200000 2>&1 | grep -A 5 "Start-Gap Statistics"

# 檢查是否有錯誤
echo ""
echo "=========================================="
echo "檢查最後輸出（是否有錯誤）"
echo "=========================================="
./nvmain.fast Config/PCM_ISSCC_2012_4GB.config test_150_writes.trace 200000 2>&1 | tail -5