#!/usr/bin/env python3
"""riboseq native 流程编排入口。

从 native/ 经典脚本库（Shell_scripts / Python_scripts / R_scripts）提取编排逻辑：
以各 pipeline 的 *_all.sh 一键链为主干（RPFs / Totals / Downstream / DataPrep），
支持 --step 单步执行与 --list-stages 自省。

执行模式：
  a) --dry-run：仅打印各 stage 将执行的脚本命令（默认，不真实运行）
  b) --real：真实执行（conda/local 两种环境模式；需按 native/README.md 准备好
     测试/参考数据，并按需编辑 common_variables.sh 与 Data_Preparation 模板）
  c) --list-stages：列出 pipeline / 单步脚本目录

编排原则：与 native/run.sh 相同的阶段顺序与脚本归属，不重复实现脚本内部逻辑；
每条 stage 即一个 Shell_scripts（或 Python_scripts）经典脚本调用。
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
SHELL = _HERE / "Shell_scripts"
SHELL_DATA = SHELL / "Data_Preparation"
PYTHON = _HERE / "Python_scripts"

# pipeline -> 一键链脚本（Shell_scripts 下）
CHAIN = {
    "RPFs": "RPFs_all.sh",
    "Totals": "Totals_all.sh",
    "Downstream": "Downstream_all.sh",
    "DataPrep": "DataPrep_all.sh",
}

# pipeline -> 单步脚本（用于 --step；RPFs 链条与 run.sh RPFS_STEPS 一致）
STEPS = {
    "RPFs": [
        "RPFs_0_QC.sh", "RPFs_1_adaptor_removal.sh", "RPFs_2_extract_UMIs.sh",
        "RPFs_3_align_reads.sh", "RPFs_4_deduplication.sh",
        "RPFs_5_Extract_counts_all_lengths.sh", "RPFs_6a_summing_region_counts.sh",
        "RPFs_6b_summing_spliced_counts.sh", "RPFs_6c_periodicity.sh",
        "RPFs_6d_extract_read_counts.sh", "RPFs_7_Extract_final_counts.sh",
        "RPFs_8a_CDS_counts.sh", "RPFs_8b_UTR5_counts.sh",
        "RPFs_8c_counts_to_csv.sh", "RPFs_8d_count_codon_occupancy.sh",
    ],
    "Totals": [
        "check_and_build_indices.sh", "Totals_0_QC.sh", "Totals_1_adaptor_removal.sh",
        "Totals_2_extract_UMIs.sh", "Totals_3a_align_reads_transcriptome.sh",
        "Totals_3b_align_reads_genome.sh", "Totals_4a_deduplication_transcriptome.sh",
        "Totals_4b_deduplication_genome.sh", "Totals_5_isoform_quantification.sh",
        "Totals_6a_write_most_abundant_transcript_fasta.sh",
        "Totals_6b_extract_read_counts.sh",
    ],
    "Downstream": [
        "Downstream_1_QC.sh", "Downstream_2_DESeq2.sh", "Downstream_3_MetaPlots.sh",
        "Downstream_4_CodonOccupancy.sh", "Downstream_5_GSEA.sh",
    ],
    "DataPrep": [
        "DataPrep_1_Download.sh", "DataPrep_1_Demultiplex.sh",
        "DataPrep_2_Concatenate.sh", "DataPrep_3_Rename.sh", "DataPrep_4_Unzip.sh",
    ],
}

# 单步脚本所在目录（相对 native/）
STEP_DIR = {
    "DataPrep_1_Download.sh": SHELL_DATA, "DataPrep_1_Demultiplex.sh": SHELL_DATA,
    "DataPrep_2_Concatenate.sh": SHELL_DATA, "DataPrep_3_Rename.sh": SHELL_DATA,
    "DataPrep_4_Unzip.sh": SHELL_DATA,
}

# conda 环境映射（与 run.sh setup_conda 一致）
CONDA_ENV = {
    "RPFs": "RiboSeq", "Totals": "RNAseq", "Downstream": "R_analysis",
    "DataPrep": "RNAseq",
}

NOTES = {
    # RPFs
    "RPFs_0_QC.sh": "RPF 原始/中间读段质控（FastQC）",
    "RPFs_1_adaptor_removal.sh": "RPF 3' 接头去除 + 长度过滤（cutadapt）",
    "RPFs_2_extract_UMIs.sh": "UMI 提取（建库含 UMI 时）",
    "RPFs_3_align_reads.sh": "rRNA/tRNA/转录组 分步比对（bbmap，先比对后去 rRNA/tRNA）",
    "RPFs_4_deduplication.sh": "UMI 去重",
    "RPFs_5_Extract_counts_all_lengths.sh": "提取全部长度读段计数",
    "RPFs_6a_summing_region_counts.sh": "按区域（CDS/UTR）汇总计数",
    "RPFs_6b_summing_spliced_counts.sh": "剪接读段计数汇总",
    "RPFs_6c_periodicity.sh": "三碱基周期性统计（质控）",
    "RPFs_6d_extract_read_counts.sh": "提取读段计数表",
    "RPFs_7_Extract_final_counts.sh": "生成最终计数文件",
    "RPFs_8a_CDS_counts.sh": "CDS 读段计数",
    "RPFs_8b_UTR5_counts.sh": "5'UTR 读段计数",
    "RPFs_8c_counts_to_csv.sh": "计数转 CSV",
    "RPFs_8d_count_codon_occupancy.sh": "密码子占据率统计",
    # Totals
    "check_and_build_indices.sh": "检查/构建比对索引（STAR / RSEM / bbmap）",
    "Totals_0_QC.sh": "Total RNA-seq 读段质控（FastQC）",
    "Totals_1_adaptor_removal.sh": "3' 接头去除 + 质控剪切（cutadapt）",
    "Totals_2_extract_UMIs.sh": "UMI 提取（建库含 UMI 时）",
    "Totals_3a_align_reads_transcriptome.sh": "转录组比对（bowtie2，兼容 RSEM 索引）",
    "Totals_3b_align_reads_genome.sh": "基因组比对（STAR，可选）",
    "Totals_4a_deduplication_transcriptome.sh": "转录组比对 UMI 去重",
    "Totals_4b_deduplication_genome.sh": "基因组比对 UMI 去重",
    "Totals_5_isoform_quantification.sh": "RSEM 基因/转录本定量",
    "Totals_6a_write_most_abundant_transcript_fasta.sh": "导出丰度最高转录本 FASTA",
    "Totals_6b_extract_read_counts.sh": "提取读段计数表",
    # Downstream
    "Downstream_1_QC.sh": "下游质控图（R_scripts/QC）",
    "Downstream_2_DESeq2.sh": "差异表达/翻译效率分析（R_scripts/DESeq2）",
    "Downstream_3_MetaPlots.sh": "meta 图（R_scripts/meta_plots）",
    "Downstream_4_CodonOccupancy.sh": "密码子占据率（R_scripts/codon_occupancy.R）",
    "Downstream_5_GSEA.sh": "GSEA 富集分析（R_scripts/gsea）",
    # DataPrep
    "DataPrep_1_Download.sh": "下载 SRA 并转 FASTQ（prefetch/fasterq-dump，模板需编辑）",
    "DataPrep_1_Demultiplex.sh": "demultiplex 拆分（如适用）",
    "DataPrep_2_Concatenate.sh": "合并同一样本多个 lane 的 fastq",
    "DataPrep_3_Rename.sh": "重命名样本文件",
    "DataPrep_4_Unzip.sh": "解压 .gz 文件",
    # all / init
    "RPFs_all.sh": "RPFs 全链一键（依次跑上述单步）",
    "Totals_all.sh": "Totals 全链一键",
    "Downstream_all.sh": "Downstream 全链一键",
    "DataPrep_all.sh": "Data_Preparation 数据准备全链一键",
    "makeDirs.sh": "初始化输出目录树",
    "prepare_data.py": "解析 info.csv → 生成 samples.env 与 fastq_files 链接（Python_scripts）",
}


def _note(script: str) -> str:
    return NOTES.get(script, "Ribo-seq 流程步骤脚本（详见脚本头注释）")


def _script_path(script: str) -> Path:
    """脚本绝对路径（单步/链脚本均在 Shell_scripts 下，DataPrep_* 在 Data_Preparation 下）。"""
    if script.startswith("DataPrep_") and script != "DataPrep_all.sh":
        return STEP_DIR.get(script, SHELL_DATA) / script
    return SHELL / script


def _shell_step(script: str) -> tuple[str, str, list[str]]:
    """构造 (stage, note, cmd)：以 bash 运行脚本（cwd=脚本所在目录，脚本 source common_variables.sh）。"""
    path = _script_path(script)
    return script, _note(script), ["bash", str(path)]


def _python_step(input_csv: str, outdir: str) -> tuple[str, str, list[str]]:
    """prepare_data.py：解析 info.csv，产出 samples.env 与 fastq 软链（cwd=native/）。"""
    return ("prepare_data.py", _note("prepare_data.py"),
            [sys.executable, str(PYTHON / "prepare_data.py"),
             "--input-csv", input_csv, "--output-dir", outdir])


def build_plan(pipeline: str, args) -> list[tuple[str, str, list[str]]]:
    """按 run.sh 阶段顺序生成 (stage, note, cmd) 计划。"""
    plan: list[tuple[str, str, list[str]]] = []
    # 前置：RPFs/Totals/Downstream 先 prepare_data（生成 samples.env）再建目录
    if pipeline in ("RPFs", "Totals", "Downstream"):
        plan.append(_python_step(args.input_csv, args.outdir))
        plan.append(_shell_step("makeDirs.sh"))
    else:
        plan.append(_shell_step("makeDirs.sh"))
    # 主链：--step 单步 或 一键链（DataPrep 链需先经 Data_Preparation 模板编辑）
    if args.step:
        steps = STEPS[pipeline]
        if args.step not in steps:
            raise ValueError(f"--step {args.step} 不属于 pipeline {pipeline}（可用 --list-stages 查看）")
        plan.append(_shell_step(args.step))
    else:
        chain = CHAIN[pipeline]
        # Totals 一键链前先构建索引（与 run.sh 顺序一致）；单步模式索引在 STEPS 列表中
        if pipeline == "Totals":
            plan.append(_shell_step("check_and_build_indices.sh"))
        plan.append(_shell_step(chain))
    return plan


def _discover_conda_base() -> str:
    exe = os.environ.get("CONDA_EXE")
    if exe:
        return str(Path(exe).resolve().parent.parent)
    cand = Path("/opt/homebrew/Caskroom/miniforge/base")  # 与 run.sh 默认一致
    return str(cand) if cand.exists() else os.environ.get("CONDA_PREFIX", "")


def _real_exec(plan: list[tuple[str, str, list[str]]], env_mode: str, conda_base: str,
               env_name: str, outdir: str) -> int:
    """执行计划。conda 模式经 conda activate 包装（同 run.sh）；随后注入 samples.env。"""
    env = dict(os.environ)
    env_file = Path(outdir) / "samples.env"
    if env_file.is_file():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[len("export "):].strip()
            if "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    executed = 0
    for stage, note, cmd in plan:
        print(f"[{stage}]: " + " ".join(map(str, cmd)) + f"   # {note}")
        if env_mode == "conda" and stage.endswith(".sh"):
            # 与 run.sh 一致：source conda.sh -> conda activate -> 在脚本目录内执行
            full = (f'source "{conda_base}/etc/profile.d/conda.sh" && '
                    f'conda activate "{env_name}" && '
                    f'cd "{_script_path(stage).parent}" && bash "{_script_path(stage)}"')
            proc = subprocess.run(["bash", "-c", full], env=env)
        elif stage.endswith(".sh"):
            proc = subprocess.run(["bash", "-c", f'cd "{_script_path(stage).parent}" && bash "{_script_path(stage)}"'],
                                  env=env)
        else:  # python 步骤
            proc = subprocess.run(cmd, env=env)
        if proc.returncode != 0:
            print(f"[ERROR] stage {stage} 失败（exit={proc.returncode}）", file=sys.stderr)
            return proc.returncode
        executed += 1
    return 0


def main(argv=None):
    argv = list(argv) if argv is not None else sys.argv[1:]

    if "--list-stages" in argv:
        catalog = {"id": "custom_riboseq",
                   "pipelines": {p: {"chain": CHAIN[p], "chain_note": _note(CHAIN[p]),
                                     "steps": [{"script": s, "note": _note(s)} for s in STEPS[p]]}
                                 for p in CHAIN}}
        print(json.dumps(catalog, ensure_ascii=False, indent=2))
        return 0

    p = argparse.ArgumentParser(description="workflow/riboseq/native — 经典脚本库流程编排入口")
    p.add_argument("--pipeline", required=True, choices=list(CHAIN),
                   help="选择要运行的 pipeline：RPFs / Totals / Downstream / DataPrep")
    p.add_argument("--step", help="只运行单个步骤脚本（见 --list-stages）")
    p.add_argument("--env-mode", choices=("conda", "local"), default="conda",
                   help="环境模式（默认 conda；--real 时生效）")
    p.add_argument("--conda-base", help="conda 安装根目录（默认自动探测；--real 时生效）")
    p.add_argument("--input-csv", default=str(_HERE / "info.csv"),
                   help="输入样本表 info.csv（prepare_data.py 用，默认 native/info.csv）")
    p.add_argument("--outdir", default=str(_HERE / "results"),
                   help="输出根目录（默认 native/results）")
    p.add_argument("--dry-run", action="store_true", default=True, help="仅打印命令（默认）")
    p.add_argument("--real", action="store_true", help="真实执行（需按 native/README.md 准备环境与数据）")
    p.add_argument("--list-stages", action="store_true")
    args = p.parse_args(argv)

    mode = "real" if args.real else "dry-run"
    print(f"# custom_riboseq ({mode}) pipeline={args.pipeline}"
          + (f" step={args.step}" if args.step else "") + f" env={args.env_mode}")

    try:
        plan = build_plan(args.pipeline, args)
    except ValueError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 2
    for stage, note, cmd in plan:
        print(f"[{stage}]: " + " ".join(map(str, cmd)) + f"   # {note}")

    if args.real:
        base = args.conda_base or _discover_conda_base()
        if args.env_mode == "conda" and not (Path(base) / "etc" / "profile.d" / "conda.sh").is_file():
            print(f"[WARN] 未在 {base} 找到 conda.sh，回退 local 模式（工具需已在 PATH）", file=sys.stderr)
        code = _real_exec(plan, args.env_mode, base, CONDA_ENV[args.pipeline], args.outdir)
        if code != 0:
            return code
        print("# 流程执行完成")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
