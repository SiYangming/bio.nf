# fastqc 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake/nextflow）的用法；安装方式见下方各节，容器与 conda 环境信息记录于此。

***

## native 实现

# fastqc / native 自包含实现

基于 bioconda `fastqc=0.12.1` + OpenJDK 17 的 Python 驱动包装：

* 自动注入 `-t` 线程（默认 4，可 CPU 核数协商）

* 通过 `JAVA_OPTS` 注入 JVM 最大堆内存（默认 8 GB）与 `TMPDIR`

* `-o` 不存在时自动创建

* `--nogroup` / `--extract` / `-f` / `-c` / `-a` / `-k` 等常见参数透传

* 运行时仍需本地安装 `fastqc` + `java`：推荐 `mamba env create -f environment.yml`

## CLI 用法示例

```bash
python main.py run sample_R1.fq.gz sample_R2.fq.gz -o qc_out --threads 8 --java-mem-mb 16384
python main.py run sample.fastq -f fastq --nogroup
python main.py --list-commands
python main.py --schema
```

## 容器运行（官方镜像优先，不维护本地配方）

官方已维护（bioconda → quay.io/biocontainers → depot.galaxyproject.org），直接拉取官方镜像运行工具二进制：

```bash
# Docker：工具直跑（官方镜像内只含 fastqc + JVM，main.py 驱动在宿主机运行）
docker pull quay.io/biocontainers/fastqc:<tag>        # tag 见文末「容器与 Conda 链接」（如 0.12.1--hdfd78af_0）
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/data quay.io/biocontainers/fastqc:<tag> \
    fastqc /data/sample_R1.fq.gz -o /data/qc_out --threads 8

# Singularity/Apptainer
apptainer pull fastqc.sif docker://quay.io/biocontainers/fastqc:<tag>
# 或直链 depot.galaxyproject.org/singularity/fastqc%3A<tag>（与 quay 同 build tag）
```

> 容器内为原生工具入口（fastqc）；需要 Schema/自省/参数注入时在**宿主机**（conda 装 fastqc + openjdk 17）运行 `python main.py run ...`。

## 运行测试

```bash
bash test/run_test.sh
```

***

## snakemake 实现

# fastqc snakemake 本地规则（td2 式：每 rule 一个 .smk，config 驱动）

`snakemake/fastqc.smk`（rule `fastqc`）由原 `rule.smk.template`（通用模板）与 `fastqc_riboseq.smk`（riboseq 流程版）合并而来，两者已删除。当 snakemake-wrappers 官方 bio/fastqc 不满足特定需求（如强制 `-f fastq_bismark`、定制 contaminant/adapter 列表等）时使用。

* 配套文件（均平铺 `snakemake/`，`.smk` 同目录相对引用）：`fastqc.yaml`（bioconda fastqc==0.12.1）、`fastqc.py`（nf-core 风格 wrapper：tempdir 运行防并发竞争、`--memory` 按线程均摊、exec\_mode 三模式分派，依赖共享 `modules/docker_wrapper.py`）。

* 规则 config 驱动、可独立 dry-run（单输入文件，多样本由调用方逐文件赋 config）：

  ```bash
  snakemake -s modules/fastqc/snakemake/fastqc.smk \
      --config fastqc_input=s1_R1.fastq.gz --cores 4 --use-conda
  ```

  产物 `<fastqc_outdir>/<输入去扩展名>_fastqc.{html,zip}`；config 契约（exec\_mode/docker\_image/fastqc\_bin/extra/mem\_mb/fastqc\_input/fastqc\_outdir 等）见 `.smk` 头注。

***

## nextflow 实现

# fastqc nextflow local 自定义实现

仅作为占位：当 nf-core 官方 FASTQC 不符合特殊参数需求（例如自定义 -k / -c 污染序列、强制 format 等）时使用。

## 启用步骤

1. 打开本目录下的 `main.nf.template`，按参数需求定制为 `main.nf`；
2. 将本目录复制到用户项目的 `modules/local/fastqc/`；
3. 在 workflow 中：

```nextflow
include { FASTQC_LOCAL } from './modules/local/fastqc/main'
FASTQC_LOCAL( reads_ch )
```

1. 在本目录写好 `meta.yaml` / `module.json`（已预置骨架）。

***

## Conda 环境（原 native/environment.yml）

```yaml
name: fastqc
channels:
  - conda-forge
  - bioconda
  - defaults
dependencies:
  - conda-forge::python>=3.10
  - bioconda::fastqc=0.12.1
  - conda-forge::openjdk=17.*
  - conda-forge::pigz
  - conda-forge::perl
  - conda-forge::coreutils
```

## 容器与 Conda 链接

* **Bioconda 页面**：<https://anaconda.org/channels/bioconda/packages/fastqc/overview>

* **Docker**：`docker pull quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0`

* **Singularity**：<https://depot.galaxyproject.org/singularity/fastqc%3A0.12.1--hdfd78af_0>

* 安装方式（本地）：`mamba create -n fastqc -c conda-forge -c bioconda fastqc=0.12.1`

