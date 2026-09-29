# 已验证 Demo：Protein G B1 结构域（单体）

本项目部署完成后跑通的**第一个官方测试用例**，用于验证环境（尤其 GPU）是否正常。

## 输入
`input.fasta`：Protein G B1 结构域，**69 残基**。

## 运行
```bash
colabfold_batch input.fasta results/ --num-recycle 3 --num-models 5
```

## 结果
| 指标 | 值 | 含义 |
|------|-----|------|
| pLDDT (rank_001) | **97.6** | 逐残基局部置信度极高（>90 侧链都可信） |
| pTM (rank_001) | **0.84** | 整体拓扑质量高（>0.8 整体可信） |
| GPU 耗时 | ~1 分钟 | CPU 模式约 20 分钟，**GPU 提速 ~19x** |

CPU 与 GPU 两次运行结果**完全一致**（pLDDT/pTM 相同），验证了 GPU 后端的正确性。

## 结果文件说明
| 文件 | 内容 |
|------|------|
| `*_plddt.png` | 逐残基 pLDDT 曲线（看哪些区段可信） |
| `*_pae.png` | PAE 热图（残基对相对位置误差，看 domain 间关系） |
| `*_coverage.png` | MSA 覆盖度（各数据库命中情况） |
| `*_unrelaxed_rank_001_*.pdb` | 排名第一的预测结构坐标 |
| `*_scores_rank_001_*.json` | rank_001 的 pLDDT/pTM 等数值 |
| `*_predicted_aligned_error_v1.json` | 完整 PAE 矩阵（可自己画图） |
| `config.json` / `log.txt` | 运行配置与日志（可见 "Running on GPU"） |
| `cite.bibtex` | ColabFold 引用 |

> 注：为控制仓库体积，已**排除**大体积 MSA 中间文件（`*.a3m`、`*_env/` 下的 tar.gz 等）。这些文件在本地运行时会自动生成。

## 判读顺序
先看 **pTM**（整体）→ 再看 **pLDDT 图**（可信区段）→ 再看 **PAE 热图**（domain 间关系）。
本例 pLDDT 97.6 + pTM 0.84，是一个**高质量、可直接采信**的预测。
