# stringtie 软件模块

> 汇总说明：本 README 合并各实现（native/snakemake/nextflow）的用法；安装方式见下方各节，容器与 conda 环境信息记录于此。

---

## native 实现

# stringtie / native — 自包含转录本组装驱动

StringTie 的本地自包含实现（`source_type: custom`、`type: native`；Nanopore long-read 模式）。

## 功能

三个子命令对应 nanoseq 的 STRINGTIE 三段链路：

| 子命令 | 命令 | 作用 |
|--------|------|------|
| `assemble` | `stringtie <bam> --conservative -L -R -G <gtf> -o <out> -l <label> -m <len> -p N` | 样本级转录本重构 |
| `fix_gtf` | `awk '$4>$5{交换}'` | 修复 GTF 坐标颠倒（纯文本，无需 stringtie） |
| `merge` | `stringtie --merge -G <gtf> -o <merged> -l MSTRG -m <len> <gtf_list>` | 多样本非冗余合并 |

## 用法

```bash
# CLI 直跑
python main.py assemble sample.sorted.bam -G gencode.v49.annotation.gtf -o sample.stringtie.gtf --threads 8
python main.py fix_gtf sample.stringtie.gtf -o sample.stringtie.fixed.gtf
python main.py merge gtf_list.txt -G gencode.v49.annotation.gtf -o stringtie_merged_nonredundant.gtf

# Agent / Schema 自省
python main.py --schema
python main.py --list-commands
```

每个子命令支持 `--threads` / `--tmpdir` 运行期覆盖。

## 环境安装（官方镜像优先，不维护本地配方）

官方已维护（bioconda → quay.io/biocontainers → depot.galaxyproject.org），直接拉取官方镜像运行工具二进制；main.py 驱动在宿主机跑。

### 1. Conda（宿主机直跑 main.py / HPC 无 root）

```bash
mamba env create -f environment.yml   # name: stringtie-native（配方见文末「Conda 环境」节）
conda activate stringtie-native
```

### 2. Docker（官方镜像）

```bash
docker pull quay.io/biocontainers/stringtie:3.0.3--h29c0135_0
# 注意：必须 -u $(id -u):$(id -g) 挂载宿主用户，否则产物归 root
docker run --rm -u $(id -u):$(id -g) -v $PWD:/data -w /data \
    quay.io/biocontainers/stringtie:3.0.3--h29c0135_0 assemble \
    sample.sorted.bam -G gencode.v49.annotation.gtf -o sample.stringtie.gtf
```

### 3. Apptainer / Singularity

```bash
apptainer pull stringtie.sif docker://quay.io/biocontainers/stringtie:3.0.3--h29c0135_0
apptainer run -B $PWD:/data -H /data stringtie.sif assemble \
    /data/sample.sorted.bam -G /data/gencode.v49.annotation.gtf -o /data/sample.stringtie.gtf
```

## 测试

```bash
bash test/run_test.sh   # fix_gtf 为真实回归；assemble/merge 退化为 argv 构造验证
```

## 版本

* stringtie 3.0.3（bioconda::stringtie=3.0.3）
* 构建路线：官方镜像/conda 提供（quay.io/biocontainers/stringtie / depot.galaxyproject.org；本地不再自建容器）
* 与 nf-core 子模块 stringtie/stringtie + stringtie/merge 的 bioconda pin 一致

## 历史留存

多步组合脚本（逐样本 assemble + 坐标修复 + 跨样本 merge）的流程版见 `workflow/nanoseq/native/03_run_stringtie.sh`（Stage 03 · StringTie；硬编码项目路径，仅供追溯对照 / 一键运行）；正式能力请走 `main.py` 的 assemble / fix_gtf / merge 原子子命令。


---

## snakemake 实现

# stringtie / snakemake / local — 自维护 Snakemake 规则（td2 式单规则拆分）

官方 `snakemake-wrappers` 无 `bio/stringtie`（抓取 404），因此本目录提供自维护规则，
作为 Snakemake 场景的**主执行路径**（`source_type: custom`、`type: snakemake_local`）。
规则按子命令拆为**每 rule 一个 config 驱动 .smk**（参照 td2/bbmap 规范；conda 环境与
wrapper 平铺于 `snakemake/` 根，规则内 `conda:` / `script:` 一律用同目录相对名）：

## 规则文件

| 规则文件 | 规则 | 命令 | 执行指令 |
|----------|------|------|----------|
| `stringtie_assemble.smk` | `stringtie_assemble` | `stringtie <bam> --conservative -L -R [-G <gtf>] -o <out> -l <label> -m 200 -p N` | `script:` 同目录 wrapper（docker/native/conda 三模式分派） |
| `stringtie_fix_gtf.smk` | `stringtie_fix_gtf` | `awk -F'\t' -v OFS='\t' -f fix_gtf.awk <gtf>`（坐标修复 $4<=$5，纯文本） | `script:` 同目录 wrapper `stringtie_fix_gtf.py` |
| `stringtie_merge.smk` | `stringtie_merge` | `stringtie --merge [-G <gtf>] -o <merged> -l MSTRG -m 200 <gtf_list>` | `script:` 同目录 wrapper（docker/native/conda 三模式分派） |

配套文件（同目录平铺，无 `envs/` / `scripts/` 幽灵引用）：
- `stringtie.yaml` —— assemble/merge 共用的 conda 环境（bioconda `stringtie==3.0.3`）
- `stringtie_assemble.py` / `stringtie_merge.py` —— assemble/merge 的 script wrapper（两级注入共享
  `modules/docker_wrapper.py`，docker/native/conda 三模式分派）
- `stringtie_fix_gtf.py` + `fix_gtf.awk` —— fix_gtf 的 script wrapper 与其 awk helper：
  wrapper 以 `Path(__file__).parent` 定位**同目录** `fix_gtf.awk`（helper 归属本目录，同目录相对定位；
  该规则纯文本处理、不挂 conda，awk 走系统 PATH）

去除 nohup/PID/LOCK 后台运行封装、绝对路径与 GNU parallel 依赖；规则 **config 驱动**
（`config.setdefault` 默认值 + `--config` 覆盖，头注含完整契约与独立运行示例），不依赖
workflow 的 SAMPLES / {sample} 目录层级。merge 的输入 GTF 列表文件由流程层对逐样本
`stringtie_fix_gtf` 产物汇总生成（`ls` / `find` 写列表，每行一个 GTF）。

## 用法

独立运行（每个 .smk 头注均有 config 契约）：

```bash
# assemble：BAM -> 样本级 GTF
snakemake -s modules/stringtie/snakemake/stringtie_assemble.smk \
    --config stringtie_bam=sample.sorted.bam \
             stringtie_gtf_annotation=gencode.v49.annotation.gtf \
    --cores 8 --use-conda

# fix_gtf：坐标修复（无需 conda / 不需要 stringtie 二进制）
snakemake -s modules/stringtie/snakemake/stringtie_fix_gtf.smk \
    --config stringtie_gtf=sample.stringtie.gtf \
             stringtie_fixed_gtf=sample.stringtie.fixed.gtf

# merge：多样本非冗余合并（gtf_list 每行一个 GTF，由流程层生成）
snakemake -s modules/stringtie/snakemake/stringtie_merge.smk \
    --config stringtie_gtf_list=gtf_list.txt \
             stringtie_gtf_annotation=gencode.v49.annotation.gtf \
    --cores 4 --use-conda
```

流程内（Snakefile 中 include 各单规则并串起三段链路）：

```python
include: "modules/stringtie/snakemake/stringtie_assemble.smk"
include: "modules/stringtie/snakemake/stringtie_fix_gtf.smk"
include: "modules/stringtie/snakemake/stringtie_merge.smk"

rule all:
    input: config["stringtie_merged_gtf"]   # merge 输入列表由流程层规则生成
```

## 与其它实现的关系

- 官方 snakemake-wrappers 无 `bio/stringtie`（2026-09 抓取 404，登记于软件级 meta.yaml `software_versions` / implementations）；若未来官方 wrapper 出现，可改走 `wrapper:` 句柄，本目录规则作 `../local` 兜底
- 非 Snakemake 场景（独立 CLI / Agent Function Calling）请走本模块 `native/`（见上「native 实现」节）


---

## Conda 环境（离线 / 非容器兜底备选）

```yaml
# stringtie native Conda 环境配方
# 创建：mamba env create -f environment.yml
# 说明：stringtie 不在 Debian bookworm apt；本文件是 Conda 兜底（HPC 无 root / 离线场景）。
#      官方镜像（quay.io/biocontainers/stringtie）即由 bioconda 本环境构建；本地不再自建 Dockerfile/Apptainer.def（见上「环境安装」）。
name: stringtie-native
channels:
  - conda-forge
  - bioconda
dependencies:
  - python=3.11
  - stringtie=3.0.3
  - pyyaml>=6.0
  - pip
```

## 容器与 Conda 链接

- **Bioconda 页面**：https://anaconda.org/channels/bioconda/packages/stringtie/overview
- **Docker**：`docker pull quay.io/biocontainers/stringtie:3.0.3--h29c0135_0`
- **Singularity**：https://depot.galaxyproject.org/singularity/stringtie%3A3.0.3--h29c0135_0
- 安装方式（本地）：`mamba create -n stringtie -c conda-forge -c bioconda stringtie=3.0.3`
