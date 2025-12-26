#!/usr/bin/env python3
"""
步驟 3: 生成測試 trace

生成兩種 trace:
1. Hotspot 模式 (80-20 pattern) - 80% 寫入集中在 20% 的地址
2. Uniform 模式 - 均勻分布
3. Sequential 模式 - 循序寫入

輸出到: /work/my_trace/ 目錄
"""

import random
import sys
import os

# 定義輸出目錄
OUTPUT_DIR = 'my_trace'

def ensure_output_dir():
    """確保輸出目錄存在"""
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        print(f"✓ 創建目錄: {OUTPUT_DIR}/")
    else:
        print(f"✓ 目錄已存在: {OUTPUT_DIR}/")

def generate_hotspot_trace(num_writes=100000):
    """
    生成 Hotspot 模式的 trace
    80% 的寫入集中在 20% 的地址
    """
    output_file = os.path.join(OUTPUT_DIR, 'trace_hotspot.trace')
    print(f"生成 Hotspot trace: {num_writes} 次寫入...")
    
    # 定義地址空間
    hot_addresses = [i * 0x100 for i in range(200)]       # 20% 的地址 (200 個)
    cold_addresses = [i * 0x100 for i in range(200, 1000)] # 80% 的地址 (800 個)
    
    with open(output_file, 'w') as f:
        for i in range(num_writes):
            cycle = i * 10  # 每 10 個週期一次寫入
            
            # 80% 機率寫入 hot addresses
            if random.random() < 0.8:
                addr = random.choice(hot_addresses)
            else:
                addr = random.choice(cold_addresses)
            
            # 格式: cycle operation address data thread_id
            data = '0' * 128  # 128 個 '0' 代表資料
            f.write(f"{cycle} W 0x{addr:x} {data} 0\n")
        
        # 最後加一個讀取避免格式問題
        f.write(f"{num_writes * 10} R 0x0 {data} 0\n")
    
    print(f"✓ {output_file} 已生成 ({num_writes} writes, 80-20 hotspot)")


def generate_uniform_trace(num_writes=100000):
    """
    生成 Uniform 模式的 trace
    所有地址均勻分布
    """
    output_file = os.path.join(OUTPUT_DIR, 'trace_uniform.trace')
    print(f"生成 Uniform trace: {num_writes} 次寫入...")
    
    # 定義地址空間 (1000 個地址)
    addresses = [i * 0x100 for i in range(1000)]
    
    with open(output_file, 'w') as f:
        for i in range(num_writes):
            cycle = i * 10
            addr = random.choice(addresses)  # 隨機選擇
            
            data = '0' * 128
            f.write(f"{cycle} W 0x{addr:x} {data} 0\n")
        
        # 最後加一個讀取
        f.write(f"{num_writes * 10} R 0x0 {data} 0\n")
    
    print(f"✓ {output_file} 已生成 ({num_writes} writes, uniform)")


def generate_sequential_trace(num_writes=100000):
    """
    生成循序寫入的 trace (極端情況)
    """
    output_file = os.path.join(OUTPUT_DIR, 'trace_sequential.trace')
    print(f"生成 Sequential trace: {num_writes} 次寫入...")
    
    with open(output_file, 'w') as f:
        for i in range(num_writes):
            cycle = i * 10
            addr = (i % 1000) * 0x100  # 循序寫入 1000 個地址
            
            data = '0' * 128
            f.write(f"{cycle} W 0x{addr:x} {data} 0\n")
        
        f.write(f"{num_writes * 10} R 0x0 {data} 0\n")
    
    print(f"✓ {output_file} 已生成 ({num_writes} writes, sequential)")


if __name__ == '__main__':
    print("=" * 60)
    print(" 步驟 3: 生成測試 Trace")
    print("=" * 60)
    print()
    
    # 確保輸出目錄存在
    ensure_output_dir()
    print()
    
    # 可以從命令列參數指定寫入次數
    num_writes = 100000
    if len(sys.argv) > 1:
        num_writes = int(sys.argv[1])
        print(f"使用自訂寫入次數: {num_writes}")
        print()
    
    # 生成三種 trace
    generate_hotspot_trace(num_writes)
    generate_uniform_trace(num_writes)
    generate_sequential_trace(num_writes)
    
    print()
    print("=" * 60)
    print("✓ 所有 trace 已生成完成！")
    print("=" * 60)
    print()
    print(f"檔案位置: {OUTPUT_DIR}/")
    print("  - trace_hotspot.trace    (80-20 hotspot)")
    print("  - trace_uniform.trace    (均勻分布)")
    print("  - trace_sequential.trace (循序寫入)")
    print()