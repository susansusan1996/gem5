#!/bin/bash
################################################################################
# 步驟 4: 執行實驗
################################################################################

cd /work

echo "=========================================="
echo "步驟 4: 執行實驗"
echo "=========================================="
echo ""

# 檢查 trace 檔案是否存在
if [ ! -f "trace_hotspot.trace" ] || [ ! -f "trace_uniform.trace" ]; then
    echo "錯誤: trace 檔案不存在！"
    echo "請先執行 step3_generate_traces.py"
    exit 1
fi

# 檢查 nvmain.fast 是否存在
if [ ! -f "nvmain.fast" ]; then
    echo "錯誤: nvmain.fast 不存在！"
    echo "請先執行 step2_compile.sh"
    exit 1
fi

# ============================================
# 實驗 1: Hotspot 模式 + Start-Gap
# ============================================
echo "【實驗 1】Hotspot 模式 + Start-Gap"
echo "執行中... (預計 1-2 分鐘)"
./nvmain.fast Config/PCM_ISSCC_2012_4GB.config trace_hotspot.trace 10000000 \
    > exp1_hotspot.txt 2>&1

if [ $? -eq 0 ]; then
    echo "✓ 實驗 1 完成"
    echo ""
    echo "--- 關鍵結果 ---"
    grep -A 12 "Start-Gap Statistics" exp1_hotspot.txt | head -13
    echo ""
else
    echo "✗ 實驗 1 失敗"
    echo "錯誤訊息："
    tail -20 exp1_hotspot.txt
    exit 1
fi

# ============================================
# 實驗 2: Uniform 模式 + Start-Gap
# ============================================
echo "【實驗 2】Uniform 模式 + Start-Gap"
echo "執行中... (預計 1-2 分鐘)"
./nvmain.fast Config/PCM_ISSCC_2012_4GB.config trace_uniform.trace 10000000 \
    > exp2_uniform.txt 2>&1

if [ $? -eq 0 ]; then
    echo "✓ 實驗 2 完成"
    echo ""
    echo "--- 關鍵結果 ---"
    grep -A 12 "Start-Gap Statistics" exp2_uniform.txt | head -13
    echo ""
else
    echo "✗ 實驗 2 失敗"
    echo "錯誤訊息："
    tail -20 exp2_uniform.txt
    exit 1
fi

# ============================================
# 實驗 3: Sequential 模式 + Start-Gap (選做)
# ============================================
if [ -f "trace_sequential.trace" ]; then
    echo "【實驗 3】Sequential 模式 + Start-Gap"
    echo "執行中... (預計 1-2 分鐘)"
    ./nvmain.fast Config/PCM_ISSCC_2012_4GB.config trace_sequential.trace 10000000 \
        > exp3_sequential.txt 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✓ 實驗 3 完成"
        echo ""
        echo "--- 關鍵結果 ---"
        grep -A 12 "Start-Gap Statistics" exp3_sequential.txt | head -13
        echo ""
    else
        echo "✗ 實驗 3 失敗 (非必要，可忽略)"
    fi
fi

# ============================================
# 總結
# ============================================
echo "=========================================="
echo "✓ 所有實驗完成！"
echo "=========================================="
echo ""
echo "輸出檔案:"
echo "  - exp1_hotspot.txt    (Hotspot 模式完整輸出)"
echo "  - exp2_uniform.txt    (Uniform 模式完整輸出)"
if [ -f "exp3_sequential.txt" ]; then
    echo "  - exp3_sequential.txt (Sequential 模式完整輸出)"
fi
echo ""
echo "下一步: 執行 step5_analyze.py 分析結果"
echo ""