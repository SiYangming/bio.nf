# bowtie2 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake）的用法；官方 snakemake-wrappers 与 nf-core 子模块信息记录于此（不建目录，仅说明层）。安装方式见下方各节，容器与 conda 环境信息记录于此。

---

## native 实现

# bowtie2 / native

自包含的 bowtie2 驱动实现（`source_type: custom`），二进制由**官方容器/conda**（quay.io/biocontainers/bowtie2 / bioconda bowtie2）提供。

## 能力

| 子命令 | 说明 | 线程 |
|--------|------|------|
| `build` | bowtie2-build：参考序列 → .bt2 索引族 | ✅（默认 8） |
| `align` | bowtie2：SE(`-U`)/PE(`-1/-2`) reads → SAM | ✅（默认 4） |

## 快速开始

### 1. 安装环境

```bash
# 路线 A：官方容器/conda（bioconda bowtie2 → quay.io/biocontainers/bowtie2；官方镜像内只含 bowtie2 工具，main.py 驱动在宿主机跑）
docker pull quay.io/biocontainers/bowtie2:<tag>        # tag 见文末「容器与 Conda 链接」
# 路线 B：本机二进制（macOS/Linux 包管理或源码均可，见文末链接）
# 路线 C：conda 兜底（HPC 无 root 时）
mamba env create -f environment.yml   # 配方见文末「Conda 环境」节
conda activate bowtie2-native
```

### 2. CLI 调用

```bash
# 建立索引（参考 FASTA -> bt2idx.1.bt2 ... bt2idx.rev.2.bt2）
python main.py build refs.fa bt2idx --threads 8
# 双端比对
python main.py align -x bt2idx -1 r1.fq.gz -2 r2.fq.gz -o out.sam --threads 8
# 单端比对（SAM 走 stdout 时省略 -o/-S）
python main.py align -x bt2idx -U single.fq.gz -o out.sam --threads 4
```

### 3. Agent / Schema 自省

```bash
python main.py --schema              # 输出 JSON Schema
python main.py --list-commands       # 列出支持的子命令
```

### 4. 容器运行（官方镜像优先，不维护本地配方）

官方已维护（bioconda → quay.io/biocontainers → depot.galaxyproject.org），直接拉取官方镜像运行工具二进制：

```bash
# Docker：工具直跑（官方镜像内只含 bowtie2/bowtie2-build，main.py 驱动在宿主机运行）
docker pull quay.io/biocontainers/bowtie2:<tag>        # tag 见 quay 页面 / 文末链接
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data quay.io/biocontainers/bowtie2:<tag> \
  bowtie2-build /data/refs.fa /data/bt2idx --threads 8
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data quay.io/biocontainers/bowtie2:<tag> \
  bowtie2 -x /data/bt2idx -1 /data/r1.fq.gz -2 /data/r2.fq.gz -S /data/out.sam --threads 8

# Singularity/Apptainer
apptainer pull bowtie2.sif docker://quay.io/biocontainers/bowtie2:<tag>
# 或直链 depot.galaxyproject.org/singularity/bowtie2%3A<tag>（与 quay 同 build tag）
```

> 容器内为原生工具入口（bowtie2 / bowtie2-build）；需要 Schema/自省/参数注入时在**宿主机**（conda 装 bowtie2 或官方镜像同款 env）运行 `python main.py <subcommand> ...`。

### 5. 测试

```bash
bash test/run_test.sh
```

## 性能优化约定

- **线程**：`build` 默认 8 线程（CPU 密集），`align` 默认 4；用户显式 `--threads` 永远优先。
- **临时目录**：通过 `TMPDIR`（`meta.yaml.optimization.env_vars`，占位符 `{tmpdir}`）注入，避免污染工作目录。
- **内存**：通过 `meta.yaml.optimization.default_mem_mb` 声明，供上层调度器读取。


---

## snakemake 实现

# bowtie2 / snakemake（本地规则 + 官方 wrappers 参考）

### 本地拆分规则（td2 式：每 rule 一个 .smk，config 驱动）

| 文件 | 规则 | 作用 |
|------|------|------|
| `snakemake/bowtie2_index.smk` | `bowtie2_index` | 参考 FASTA → `.bt2` 索引族（bowtie2-build） |
| `snakemake/bowtie2_align.smk` | `bowtie2_align` | reads（SE/PE）→ SAM（bowtie2 align） |

- 配套文件（均平铺 `snakemake/`，`.smk` 同目录相对引用）：`bowtie2.yaml`（conda env）、`bowtie2_index.py` / `bowtie2_align.py`（wrapper，docker/native/conda 三模式分派，注入共享 `modules/docker_wrapper.py`）。
- 规则 **config 驱动、可独立运行**（不依赖流程 `samples`/`is_pe()`/`config["paths"]`），契约见各 `.smk` 头注。独立运行示例：
  ```bash
  snakemake -s modules/bowtie2/snakemake/bowtie2_index.smk \
      --config bowtie2_input_fasta=ref.fa bowtie2_index_prefix=bt2/bowtie2 --cores 8 --use-conda
  ```
- 两规则共用同一 `bowtie2_index_prefix` 时 include 两文件即可自动串联（index 产物为 align 输入）。

### 官方 snakemake-wrappers（说明层，运行时靠 `wrapper:` 句柄解析）

> 本模块**不重写官方 wrapper 源码**。官方仓库 `bio/bowtie2/` 子模块如下（2026-09 抓取，以官方在线目录为准）：

| wrapper | wrapper 句柄 | 环境 pin（master） |
|---------|--------------|--------------------|
| align | `vX.Y.Z/bio/bowtie2/align` | bowtie2=2.5.5, samtools=1.24, snakemake-wrapper-utils=0.9.0 |
| build | `vX.Y.Z/bio/bowtie2/build` | bowtie2=2.5.5 |

引用示例（Snakefile）：

```python
rule bowtie2_align:
    input:
        reads=["reads_1.fastq", "reads_2.fastq"],
        idx=multiext("refs", ".1.bt2", ".2.bt2", ".3.bt2", ".4.bt2", ".rev.1.bt2", ".rev.2.bt2"),
    output:
        "mapped.sam"
    log: "logs/bowtie2_align.log"
    params:
        extra=""
    threads: 8
    wrapper: "v3.13.0/bio/bowtie2/align"
```

> ⚠️ 本模块未内置官方 wrapper 的 wrapper.py：Snakemake 运行时按 `wrapper:` 句柄解析（联网拉取中央 wrapper 缓存）；离线/私有环境缺失时请改用本模块 `snakemake/bowtie2_{index,align}.smk` 本地规则。
> 更新子模块清单的抓取命令：
> `curl -s https://api.github.com/repos/snakemake/snakemake-wrappers/contents/bio/bowtie2 | python3 -c "import json,sys; [print(x['name']) for x in json.load(sys.stdin)]"`

### nf-core 官方参考（Nextflow，说明层）

本模块未建 `nextflow/` 目录；nf-core 官方 `modules/nf-core/bowtie2/` 子模块（2026-09 抓取，以官方在线目录为准）：

| 子模块 | environment.yml 关键 pin |
|--------|--------------------------|
| align | bioconda::bowtie2=2.5.4, htslib=1.21, samtools=1.21, pigz=2.8 |
| build | bioconda::bowtie2=2.5.4, htslib=1.21, samtools=1.21, pigz=2.8 |

组装 Nextflow DSL2 流程时执行 `nf modules install nf-core bowtie2 align build`（安装到项目自身 `modules/nf-core/`，不要直接 include 本仓库文件），随后：

```nextflow
include { BOWTIE2_ALIGN } from '../modules/nf-core/bowtie2/align/main'
include { BOWTIE2_BUILD } from '../modules/nf-core/bowtie2/build/main'
```

> 抓取命令：`curl -s https://api.github.com/repos/nf-core/modules/contents/modules/nf-core/bowtie2 | python3 -c "import json,sys; [print(x['name']) for x in json.load(sys.stdin)]"`


---

## 版本差异声明（native / snakemake-wrappers / nf-core）

| 实现 | bowtie2 版本 | 来源 |
|------|-------------|------|
| native（官方容器/conda） | **2.5.4** | official biocontainer：quay.io/biocontainers/bowtie2:2.5.4--he96a11b_7 / bioconda bowtie2=2.5.4（riboseq 流程同款） |
| snakemake 本地规则 env | 2.5.4 | bioconda（本模块 `snakemake/bowtie2.yaml`，与 riboseq 流程一致） |
| snakemake-wrappers v3.13.0 | 2.5.4 | bioconda（bio/bowtie2/align/environment.yaml） |
| snakemake-wrappers master | 2.5.5 | bioconda（autobump） |
| nf-core master | 2.5.4 | bioconda（modules/nf-core/bowtie2/*/environment.yml） |

> native 与 riboseq 流程统一 2.5.4（官方容器 quay.io/biocontainers/bowtie2:2.5.4--he96a11b_7 / conda bowtie2=2.5.4）；原 apt 打包 2.5.0-3+b2 的历史差异已随本地容器移除。


---

## Conda 环境（离线 / 非容器兜底备选）

```yaml
# bowtie2 native Conda 环境配方（HPC 无 root / 非容器兜底）
# 创建：mamba env create -f environment.yml
name: bowtie2-native
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - bowtie2=2.5.4     # 与 riboseq 流程一致；如需 apt 同款 2.5.0 请装二进制
  - pyyaml>=6.0
```

## 容器与 Conda 链接

- **Bioconda 页面**：https://anaconda.org/bioconda/bowtie2
- **Docker**：`docker pull quay.io/biocontainers/bowtie2:2.5.4--he96a11b_7`（riboseq 流程同款）
- **Singularity**：https://depot.galaxyproject.org/singularity/bowtie2%3A2.5.4--he96a11b_7
- 安装方式（本地）：`mamba create -n bowtie2 -c conda-forge -c bioconda bowtie2=2.5.4`（官方镜像/conda 提供，本地不再自建容器）
- 上游 GitHub：https://github.com/BenLangmead/bowtie2
