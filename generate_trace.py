#!/usr/bin/env python3
"""
步驟 3: 生成測試 trace

生成兩種 trace:
1. Hotspot 模式 (80-20 pattern) - 80% 寫入集中在 20% 的地址
2. Uniform 模式 - 均勻分布
"""

import random
import sys

def generate_hotspot_trace(num_writes=100000, output_file='trace_hotspot.trace'):
    """
    生成 Hotspot 模式的 trace
    80% 的寫入集中在 20% 的地址
    """
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


def generate_uniform_trace(num_writes=100000, output_file='trace_uniform.trace'):
    """
    生成 Uniform 模式的 trace
    所有地址均勻分布
    """
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


def generate_sequential_trace(num_writes=100000, output_file='trace_sequential.trace'):
    """
    生成循序寫入的 trace (極端情況)
    """
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
    
    # 可以從命令列參數指定寫入次數
    num_writes = 100000
    if len(sys.argv) > 1:
        num_writes = int(sys.argv[1])
        print(f"使用自訂寫入次數: {num_writes}")
    
    # 生成三種 trace
    generate_hotspot_trace(num_writes, 'trace_hotspot.trace')
    generate_uniform_trace(num_writes, 'trace_uniform.trace')
    generate_sequential_trace(num_writes, 'trace_sequential.trace')
    
    print()
    print("=" * 60)
    print("✓ 所有 trace 已生成完成！")
    print("=" * 60)
    print()
    print("檔案清單:")
    print("  - trace_hotspot.trace    (80-20 hotspot)")
    print("  - trace_uniform.trace    (均勻分布)")
    print("  - trace_sequential.trace (循序寫入)")
    print()