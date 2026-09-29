#!/usr/bin/env bash
# 复合物（多链）预测：AF2-Multimer
# 用法: bash scripts/run_multimer.sh <input.fasta> <output_dir>
# 关键：多链写在【同一条FASTA记录】里，链间用冒号":"分隔
#   异源二聚体A+B: >complex 换行 序列A:序列B
#   同源二聚体:    >homodimer 换行 序列S:序列S (必须写两遍!)
# ColabFold检测到":"自动切Multimer模式，命令与单体一致。
# 6GB提醒：显存看【所有链残基总和】，总残基>~400大概率OOM；对策=只截界面domain。
set -euo pipefail
INPUT="${1:-examples/multimer/input.fasta}"
OUTDIR="${2:-out_multimer}"
colabfold_batch "$INPUT" "$OUTDIR" --num-recycle 3 --num-models 5
# 判读顺序：1)先看ipTM(>0.8可信/0.6~0.8存疑/<0.6假阳性) 2)跨链PAE区块(深蓝=好,红=差) 3)界面残基pLDDT
# 注意：pTM/pLDDT高 不等于 界面好；低ipTM 不等于 证明不结合(只是证据不足)
