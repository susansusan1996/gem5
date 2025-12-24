cd /work

# 查看完整輸出（包括最終統計）
echo "=========================================="
echo "查看 150 次寫入測試的完整統計"
echo "=========================================="
./nvmain.fast Config/PCM_ISSCC_2012_4GB.config test_150_writes.trace 200000 2>&1 | tail -60 | head -40

# 查看 StartGap 最終統計
echo ""
echo "=========================================="
echo "查看 Start-Gap 最終統計報告"
echo "=========================================="
./nvmain.fast Config/PCM_ISSCC_2012_4GB.config test_150_writes.trace 200000 2>&1 | grep -A 5 "Start-Gap Statistics"

# 也檢查最後幾行
echo ""
echo "=========================================="
echo "最後 20 行"
echo "=========================================="
./nvmain.fast Config/PCM_ISSCC_2012_4GB.config test_150_writes.trace 200000 2>&1 | tail -20