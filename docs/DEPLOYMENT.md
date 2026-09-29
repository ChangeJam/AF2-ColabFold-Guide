# AF2 部署日志

> 每个里程碑完成时记录：做了什么、踩坑与解决、❓疑问解答。
> 与 TUTOR.md（交互规则/教学记录）分离，本文档纯工程记录。

## ❓疑问清单

| # | 问题 | 提出时间 | 解答时间 | 解答位置 |
|---|------|---------|---------|---------|
| 1 | 为什么先装了 575 分支，后来自动变成了 580？ | 09-21 | 09-21 | [M0 踩坑记录](#踩坑与解决) |

---

## M0: 驱动修复 ✅

**完成时间**：2026-09-19 ~ 09-21

### 做了什么
- 目标：让 RTX 3060 Mobile 在当前内核下可用
- 原方案（TUTOR.md 中）：回退内核到 6.17.0-40 以适配旧版 535 驱动
- **实际方案**：留在 7.0.0-31 内核，将驱动从 535 升级到 580（DKMS open）分支
- 安装 `nvidia-driver-580-open`（含 `nvidia-dkms-580-open`），DKMS 自动为当前内核编译模块
- 清理残留的 `nvidia-driver-575-open` metapackage

### 最终状态
| 项目 | 值 |
|------|-----|
| 内核 | 7.0.0-31-generic（默认，无需手切 GRUB） |
| 驱动 | 580.178.04（nvidia-dkms-580-open） |
| CUDA | 13.0 |
| GPU | RTX 3060 Mobile 6GB，nvidia-smi 正常 ✅ |
| bbswitch | 已不再需要（Runtime PM 由 580 驱动原生支持） |

### 踩坑与解决

**坑1：575 → 580 分支自动切换**

现象：手动装了 `nvidia-driver-575-open`，后来 dpkg 里出现了 580 的包，575 的 metapackage 残留。

原因：Ubuntu 24.04 仓库推送了 580 分支后，575 被标记为过渡包（transitional package），其依赖被重新指向 580。跑 `apt upgrade` 时，底层库全部自动替换为 580 版本，但手动安装的 metapackage（`nvidia-driver-575-open`）不会被自动移除，成为残留。

解决：`sudo apt remove nvidia-driver-575-open` 清理残留。这是 Ubuntu 包管理的正常行为，非操作失误。

**坑2（历史）：内核 7.0 + 旧驱动 535 = GPU 不可用**

现象：`nvidia-smi` 报错，独显不可用。

原因：535 是预编译驱动包（非 DKMS），只为 6.17 内核编译了内核模块。升级到 7.0 内核后，没有匹配的内核模块，且 535 分支本身不支持 7.0 的 ABI。

解决：升级到 580 分支（DKMS open 版），DKMS 会为当前内核自动编译模块，且 580 分支支持 7.0 内核。

---

## M1: 环境搭建 ✅

**完成时间**：2026-09-21

### 做了什么
- 创建 conda 环境 `colabfold`，Python 3.11.16
- 安装 `colabfold[alphafold]`（pip 版）
- 验证 `colabfold_batch --help` 正常输出

### 已安装核心包
| 包 | 版本 |
|----|------|
| colabfold | 1.6.3 |
| alphafold-colabfold | 2.3.20 |
| jax | 0.10.2 |
| jaxlib | 0.10.2 |
| numpy | 2.4.6 |

### 当前环境总览
- conda env：`colabfold`（Python 3.11.16）
- 激活命令：`conda activate colabfold`
- 部署方案：pip 版 colabfold + 公共 MSA API 服务器（无需本地数据库）
- 磁盘占用：环境本身约 2-3GB，844GB 可用空间充足

### 踩坑与解决
（暂无，安装顺利）

---

## M2: 参数与数据库下载 ✅

**完成时间**：2026-09-21

### 做了什么
- 下载 AF2 模型权重（3.5GB tar 包）从 Google Cloud Storage
- URL: `https://storage.googleapis.com/alphafold/alphafold_params_2021-07-14.tar`
- 解压到 `~/.cache/colabfold/params/`，包含 10 个 .npz 文件（5 个模型 + 5 个 ptm 变体）
- 创建 `download_finished.txt` 成功标记文件

### 踩坑与解决

**坑：tar 包需要手动解压**

现象：下载完 tar 包后跑 colabfold_batch，它又重新开始下载。

原因：colabfold 检查的是 `download_finished.txt` 标记文件和解压后的 .npz 文件，而不是 tar 包本身。

解决：手动解压 `tar xf` 并创建标记文件。

---

## M3: 官方测试用例跑通（单体预测） ✅

**完成时间**：2026-09-21

### 做了什么
- 测试序列：Protein G B1 结构域（69 残基）
- CPU 模式下成功跑通（pLDDT = 97.6，pTM = 0.84），但速度很慢
- 诊断并修复 JAX GPU 支持问题（见下方 CUDA/JAX 学习记录）
- GPU 模式下重跑成功，结果一致，速度提升 19 倍

### CPU vs GPU 对比
| 指标 | CPU 模式 | GPU 模式 |
|------|---------|----------|
| 总耗时 | ~20 分钟 | ~1 分钟 |
| 加速比 | — | **~19x** |
| rank_001 pLDDT | 97.6 | 97.6 |
| rank_001 pTM | 0.84 | 0.84 |
| 日志确认 | WARNING: no GPU detected | Running on GPU ✅ |

### 踩坑：JAX 未启用 GPU

现象：`WARNING: no GPU detected, will be using CPU`

原因：`pip install colabfold[alphafold]` 安装的 jaxlib 是 CPU 版本，不包含 CUDA 支持。

解决：`pip install 'jax[cuda12]'` 安装 CUDA12 插件（jax-cuda12-plugin + nvidia-*-cu12 系列库），JAX 0.10.2 采用插件架构，GPU 能力通过插件叠加，无需替换 jaxlib。

→ 详见下方 [CUDA/JAX 学习记录](#cuda--jax-学习记录)

---

## CUDA / JAX 学习记录

> 诊断和修复 JAX GPU 支持的过程，采用 PPT 学习法。

### Probe - Q1

JAX 启动时说了这句话：
> "An NVIDIA GPU may be present on this machine, but **a CUDA-enabled jaxlib is not installed**. Falling back to cpu."

这里涉及一个关键的层级关系。你觉得：

**JAX 要用 GPU 跑计算，它需要经过哪些层才能"碰到" GPU 硬件？**

> 提示：回忆 N1 里学的分层模型（硬件 → 内核 → 用户态），JAX 在哪一层？它要"穿过"什么才能到达 GPU？

**你的回答**：硬件-内核-驱动-CUDA-JAX这样的层级顺序

> ✅ 对的部分：你抓住了核心——这是一个**分层栈**，JAX 不能直接碰硬件，中间要穿过好几层。方向完全正确。
>
> ⚠️ 需要精修的地方：你把"CUDA"当成了一个独立的层，但实际上 **CUDA 不是一个层，它被"打包"在 jaxlib 里面**。这才是整个问题的关键。

精确的栈如下：

```
用户代码 (colabfold_batch)
    ↓
  JAX          ← 纯 Python 框架，只负责定义计算图
    ↓
  jaxlib       ← 真正的"桥梁"，内部捆绑了 CUDA Runtime 库
    ↓
  NVIDIA 内核驱动 (nvidia.ko)  ← M0 修好的那层
    ↓
  GPU 硬件 (RTX 3060)
```

关键洞察：**jaxlib 不是一个单纯的 Python 包，它是一个"捆绑包"**——里面包含了：
- XLA 编译器（把 JAX 计算图编译成 GPU 能执行的代码）
- CUDA Runtime 库（libcudart 等，不需要你单独装 CUDA Toolkit）
- cuDNN 库（深度学习常用算子）

所以 JAX 报错说 "a CUDA-enabled jaxlib is not installed"，意思就是：**你现在装的 jaxlib 里面没有捆绑 CUDA 那一套东西**，它只有 CPU 的 XLA 后端。

---

### Check Quiz（Q1 即时检验）

**你现在要修复 GPU 支持，需要做的事情是什么？（选最准确的一项）**

- A) 先安装 NVIDIA CUDA Toolkit，再重新装 jaxlib
- B) 把当前的 jaxlib 卸载，换成一个捆绑了 CUDA 支持的同版本 jaxlib
- C) 安装一个单独的 `jax-cuda` 插件包，让现有 jaxlib 获得 GPU 能力

> 提示：想想 jaxlib 的角色——它是"桥梁"，CUDA 东西是"打包在里面"的。

**你的回答**：C。因为CUDA包含在CUDA的相关内容，所以我认为只需要补充缺失的CUDA部分应该就可以？

> ✅ **答案正确！** 而且你的推理直觉非常好——"补充缺失的 CUDA 部分"这个思路完全对。
>
> 🔄 **助教自我修正**：我在上面的讲解中说"jaxlib 是捆绑包"，这是旧版 JAX（≤0.4.x）的架构。实际上在 JAX 0.10.2 中，架构已经演变为**插件模式**：

```
jax (Python 前端)
  ↓
jaxlib (核心：XLA 编译器 + CPU 后端)    ← 已安装，保持不变
  +
jax-cuda12-plugin (GPU 后端插件)         ← 缺失，需要安装
  +
nvidia-*-cu12 系列库 (CUDA Runtime 等)   ← 缺失，随插件自动安装
```

> 所以 jaxlib 现在只管"核心计算 + CPU"，GPU 能力是通过 **插件** 加上去的——这正好验证了你的判断：不需要替换 jaxlib，只需要"补充缺失的 CUDA 部分"。

---

### Plan（修复方案）

**目标**：安装 `jax[cuda12]`，为现有 JAX 添加 GPU 支持。

**具体步骤**：
1. `pip install 'jax[cuda12]'` — 安装 CUDA12 插件 + NVIDIA CUDA 库（约 2-3GB）
2. 验证 GPU 是否被识别：`python -c "import jax; print(jax.devices())"`
3. 用 GPU 重跑 M3 测试用例

**兼容性说明**：
- 你的驱动支持 CUDA 13.0（向下兼容 CUDA 12.x），没问题
- 不需要单独安装 NVIDIA CUDA Toolkit，pip 包自带

---

## M4: 第一个真实预测

**状态**：⏳ 待开始

---

## M5: 多聚体/复合物预测

**状态**：⏳ 待开始
