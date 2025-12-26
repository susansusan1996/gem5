#!/bin/bash
################################################################################
# 步驟 4: 執行實驗
# trace 檔案位於 my_trace/ 目錄
# 結果輸出到 my_result/ 目錄
################################################################################

cd /work

echo "=========================================="
echo "步驟 4: 執行實驗"
echo "=========================================="
echo ""

# 定義目錄
TRACE_DIR="my_trace"
RESULT_DIR="my_result"

# 檢查 trace 目錄是否存在
if [ ! -d "$TRACE_DIR" ]; then
    echo "錯誤: $TRACE_DIR/ 目錄不存在！"
    echo "請先執行 step3_generate_traces_v2.py"
    exit 1
fi

# 檢查 trace 檔案是否存在
if [ ! -f "$TRACE_DIR/trace_hotspot.trace" ] || [ ! -f "$TRACE_DIR/trace_uniform.trace" ]; then
    echo "錯誤: trace 檔案不存在！"
    echo "請先執行 step3_generate_traces_v2.py 生成 trace"
    echo ""
    echo "缺少的檔案："
    [ ! -f "$TRACE_DIR/trace_hotspot.trace" ] && echo "  - $TRACE_DIR/trace_hotspot.trace"
    [ ! -f "$TRACE_DIR/trace_uniform.trace" ] && echo "  - $TRACE_DIR/trace_uniform.trace"
    exit 1
fi

# 檢查 nvmain.fast 是否存在
if [ ! -f "nvmain.fast" ]; then
    echo "錯誤: nvmain.fast 不存在！"
    echo "請先執行 step2_compile.sh 編譯"
    exit 1
fi

# 創建結果目錄
if [ ! -d "$RESULT_DIR" ]; then
    mkdir -p "$RESULT_DIR"
    echo "✓ 創建結果目錄: $RESULT_DIR/"
else
    echo "✓ 結果目錄已存在: $RESULT_DIR/"
fi

echo "trace 來源: $TRACE_DIR/"
echo "結果輸出: $RESULT_DIR/"
echo ""

# ============================================
# 實驗 1: Hotspot 模式 + Start-Gap
# ============================================
echo "【實驗 1】Hotspot 模式 + Start-Gap"
echo "使用 trace: $TRACE_DIR/trace_hotspot.trace"
echo "執行中... (預計 1-2 分鐘)"
./nvmain.fast Config/PCM_ISSCC_2012_4GB.config $TRACE_DIR/trace_hotspot.trace 10000000 \
    > $RESULT_DIR/exp1_hotspot.txt 2>&1

if [ $? -eq 0 ]; then
    echo "✓ 實驗 1 完成"
    echo ""
    echo "--- 關鍵結果 ---"
    grep -A 12 "Start-Gap Statistics" $RESULT_DIR/exp1_hotspot.txt | head -13
    echo ""
else
    echo "✗ 實驗 1 失敗"
    echo "錯誤訊息："
    tail -20 $RESULT_DIR/exp1_hotspot.txt
    exit 1
fi

# ============================================
# 實驗 2: Uniform 模式 + Start-Gap
# ============================================
echo "【實驗 2】Uniform 模式 + Start-Gap"
echo "使用 trace: $TRACE_DIR/trace_uniform.trace"
echo "執行中... (預計 1-2 分鐘)"
./nvmain.fast Config/PCM_ISSCC_2012_4GB.config $TRACE_DIR/trace_uniform.trace 10000000 \
    > $RESULT_DIR/exp2_uniform.txt 2>&1

if [ $? -eq 0 ]; then
    echo "✓ 實驗 2 完成"
    echo ""
    echo "--- 關鍵結果 ---"
    grep -A 12 "Start-Gap Statistics" $RESULT_DIR/exp2_uniform.txt | head -13
    echo ""
else
    echo "✗ 實驗 2 失敗"
    echo "錯誤訊息："
    tail -20 $RESULT_DIR/exp2_uniform.txt
    exit 1
fi

# ============================================
# 實驗 3: Sequential 模式 + Start-Gap (選做)
# ============================================
if [ -f "$TRACE_DIR/trace_sequential.trace" ]; then
    echo "【實驗 3】Sequential 模式 + Start-Gap"
    echo "使用 trace: $TRACE_DIR/trace_sequential.trace"
    echo "執行中... (預計 1-2 分鐘)"
    ./nvmain.fast Config/PCM_ISSCC_2012_4GB.config $TRACE_DIR/trace_sequential.trace 10000000 \
        > $RESULT_DIR/exp3_sequential.txt 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✓ 實驗 3 完成"
        echo ""
        echo "--- 關鍵結果 ---"
        grep -A 12 "Start-Gap Statistics" $RESULT_DIR/exp3_sequential.txt | head -13
        echo ""
    else
        echo "✗ 實驗 3 失敗 (非必要，可忽略)"
    fi
else
    echo "【實驗 3】Sequential 模式 - 跳過 (檔案不存在)"
fi

# ============================================
# 總結
# ============================================
echo "=========================================="
echo "✓ 所有實驗完成！"
echo "=========================================="
echo ""
echo "trace 來源: $TRACE_DIR/"
echo "結果輸出: $RESULT_DIR/"
echo ""
echo "輸出檔案:"
echo "  - $RESULT_DIR/exp1_hotspot.txt    (Hotspot 模式)"
echo "  - $RESULT_DIR/exp2_uniform.txt    (Uniform 模式)"
if [ -f "$RESULT_DIR/exp3_sequential.txt" ]; then
    echo "  - $RESULT_DIR/exp3_sequential.txt (Sequential 模式)"
fi
echo ""
echo "下一步: 執行 final_analyze.py 分析結果"
echo ""