#!/usr/bin/env bash
# 单体预测（走远程 MSA，无需本地数据库）
# 用法: bash scripts/run_monomer.sh <input.fasta> <output_dir>
set -euo pipefail
INPUT="${1:-examples/test_monomer/input.fasta}"
OUTDIR="${2:-out_monomer}"
# 首次运行会自动下载模型权重(~3.5GB)到 ~/.cache/colabfold/
colabfold_batch "$INPUT" "$OUTDIR" --num-recycle 3 --num-models 5
# 说明：--msa-mode auto(默认)走远程MMseqs2；不加--data=不用本地库；不加--amber=不做relax
# 判读顺序：pTM(整体) -> pLDDT图(可信区段) -> PAE热图(domain间关系)
