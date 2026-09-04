# umi_tools 技能

处理 Unique Molecular Identifiers（UMI）与细胞条形码的工具集：`extract`（FASTQ 提取条形码/UMI）、`dedup`（按 UMI + 比对坐标去 PCR 重复）、`group`/`count` 等。

## 安装方式

- **native**：官方镜像优先（bioconda → quay.io/biocontainers → depot.galaxyproject.org），本地不再自建容器；宿主机直跑 `native/main.py` 时用 conda/mamba 安装 umi_tools（见 `software_versions`）
- **Conda**：`mamba create -n <env> -c conda-forge -c bioconda umi_tools`
- **容器镜像**：`quay.io/biocontainers/umi_tools:1.1.6--py312h0fa9677_0`（riboseq 流程使用）
- **Docker 运行示例**：`docker pull quay.io/biocontainers/umi_tools:<tag>`（官方镜像只含工具）+ `docker run --rm -u $(id -u):$(id -g) -v "$PWD":/work -w /work <image> umi_tools <subcommand>`（`main.py` 驱动在宿主机跑）

## 三种用法

### 1. native（Agent Function Calling / CLI）

```bash
python3 modules/umi_tools/native/main.py --list-commands
python3 modules/umi_tools/native/main.py extract -I in.fq.gz --bc-pattern NNNNNNNN -S out.fq.gz
python3 modules/umi_tools/native/main.py dedup -I in.bam -S dedup.bam --output-stats stats
```

### 2. snakemake（本地单规则，td2 式 config 驱动）

规则已按 **td2 式规范**拆为单规则文件（每文件一个 rule、config 驱动、摆脱对流程 `samples` / `config[paths]` 的依赖），迁自 `riboseq.smk`：

| 文件 | rule | 说明 |
|---|---|---|
| `snakemake/umi_tools_extract_se.smk` | `umi_tools_extract_se` | extract SE：从单端 reads 提取 UMI |
| `snakemake/umi_tools_extract_pe.smk` | `umi_tools_extract_pe` | extract PE：R1+R2 成对提取（`--read2-in/out`） |
| `snakemake/umi_tools_dedup.smk` | `umi_tools_dedup` | dedup：按 UMI + 比对坐标去 PCR 重复 |

- 三规则共用 `snakemake/umi_tools.yaml`（`bioconda::umi_tools==1.1.6`）；wrapper 为同目录 `umi_tools_extract.py` / `umi_tools_dedup.py`（docker/native/conda 分支由共享的 `modules/docker_wrapper.py` 提供）。
- 流程内 include（可只 include 需要的规则）：

```python
include: "modules/umi_tools/snakemake/umi_tools_extract_se.smk"
include: "modules/umi_tools/snakemake/umi_tools_extract_pe.smk"
include: "modules/umi_tools/snakemake/umi_tools_dedup.smk"
```

- 独立运行示例（config 契约见各 `.smk` 头部）：

```bash
# extract SE（输出 UMI 标记 FASTQ）
snakemake -s modules/umi_tools/snakemake/umi_tools_extract_se.smk \
    --config umi_input_fastq=reads.fastq.gz 'umi_tools.bc_pattern=NNNNNNNN' \
    umi_output_fastq=reads_umi.fastq.gz --cores 4 --use-conda

# dedup（输入已比对 BAM）
snakemake -s modules/umi_tools/snakemake/umi_tools_dedup.smk \
    --config umi_input_bam=aln_sorted.bam umi_output_bam=aln_dedup.bam \
    --cores 4 --use-conda
```

### 3. 官方 wrapper（说明层）

> **强提示**：snakemake-wrappers 官方 `bio/` 树当前（v3.13.0 与 master）**无 umi_tools 目录**（已核实 404），nf-core 目录名为 `umitools`（含 dedup/extract/group/prepareforrsem）。本模块 `snakemake/` 为**自维护 local 规则**；若官方日后新增 wrapper，请用运行时解析的 `wrapper:` 句柄而非本模块脚本。刷新官方子模块清单：
> ```bash
> curl -sL "https://github.com/snakemake/snakemake-wrappers/tree/master/bio/umi_tools" | grep -oE 'href="[^"]*bio/umi_tools/[^"]+"'
> curl -sL "https://github.com/nf-core/modules/tree/master/modules/nf-core/umitools" | grep -oE 'href="[^"]*umitools/[^"]+"'
> ```

## 版本差异

| 实现 | umi_tools | 来源 |
|---|---|---|
| native | 1.1.6 | bioconda / 官方镜像（`quay.io/biocontainers/umi_tools`） |
| snakemake（本地单规则） | 1.1.6 | bioconda（`snakemake/umi_tools.yaml`） |
| nf-core | 1.1.6 | bioconda::umi_tools=1.1.6（`modules/nf-core/umitools/*/environment.yml`） |

详见 [meta.yaml](meta.yaml) `software_versions`。
