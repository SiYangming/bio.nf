#!/usr/bin/env python3
"""RSEM native 标准入口驱动。

RSEM（RNA-Seq by Expectation-Maximization）：从转录组比对结果（或直接 reads）
估计基因 / 转录本表达量。本驱动覆盖 riboseq 流程两个核心阶段：

1. prepare-reference：rsem-prepare-reference
   python main.py prepare-reference genome.fa rsem_index --gtf genes.gtf --bowtie2 --threads 8
2. calculate-expression：rsem-calculate-expression
   python main.py calculate-expression --alignments sample_dedup.bam \
       --index rsem_index --prefix sample --fragment-length-mean 300 \
       --fragment-length-sd 100 --strandedness forward --threads 8
   # 或 reads 直算模式（--bowtie2 让 rsem 内部调用 bowtie2 比对）：
   python main.py calculate-expression --reads reads.fq.gz --index rsem_index \
       --prefix sample --bowtie2 --fragment-length-mean 300 --fragment-length-sd 100

Agent Function Calling / Schema 自省：
   python main.py --schema          # 打印 JSON Schema
   python main.py --list-commands   # 列出支持的子命令

所有子命令自动注入线程（--num-threads）与临时目录（TMPDIR）。
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

# 让 main.py 既能被 skill-cli 导入（已加入 modules/ 路径），也能直接运行
_HERE = Path(__file__).resolve().parent
_SKILLS_ROOT = _HERE.parent.parent
if str(_SKILLS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SKILLS_ROOT))

import base  # noqa: E402

# 子命令语义清单（用于 --list-commands 与 Schema description）
SUBCOMMANDS = {
    "prepare-reference": "rsem-prepare-reference：参考 FASTA + GTF -> RSEM 参考索引（.seq/.grp/.ti/.transcripts.fa）",
    "calculate-expression": "rsem-calculate-expression：转录组 BAM（--alignments）或 reads -> 基因/转录本定量",
}


class RSEMSkill(base.SkillBase):
    software = "rsem"
    binary = "rsem-calculate-expression"

    def __init__(self, meta_path: str | Path | None = None):
        # 单 meta 模式下 meta.yaml 位于软件级 modules/rsem/meta.yaml（不在 native/ 下），
        # 显式指向它，使 --schema / per_subcommand_threads 等真正读到优化配置。
        if meta_path is None:
            meta_path = _HERE.parent / "meta.yaml"
        super().__init__(meta_path)

    def _effective_threads(self, subcommand: str, override: int | None) -> int:
        """线程选择优先级：用户显式 > 子命令建议 > 全局默认。"""
        if override and override > 0:
            return override
        per = (self.meta.get("optimization", {}) or {}).get("per_subcommand_threads", {})
        return int(per.get(subcommand, per.get("default", self.cpus)))

    def _resolve_tool(self, tool: str) -> str:
        """解析配套可执行文件（rsem-prepare-reference），带清晰报错。"""
        path = shutil.which(tool)
        if not path:
            raise RuntimeError(
                f"未找到可执行文件 '{tool}'，请先通过 Conda/Docker/Apptainer 安装 "
                "（Debian 包 rsem / bioconda rsem=1.3.3 会同时提供全部 rsem-* 工具）。"
            )
        return path

    def build_command(self, subcommand: str, **kw) -> list[str]:
        """根据子命令与参数构建 rsem 命令行。"""
        threads = self._effective_threads(subcommand, kw.get("threads"))

        if subcommand == "prepare-reference":
            binary = self._resolve_tool("rsem-prepare-reference")
            reference_genome = kw.get("reference_genome")
            if not reference_genome:
                raise RuntimeError("prepare-reference 需要参考基因组 FASTA（位置参数）")
            reference_name = kw.get("reference_name")
            if not reference_name:
                raise RuntimeError("prepare-reference 需要 reference_name（输出索引 basename，位置参数）")
            cmd: list[str] = [binary, "--num-threads", str(threads)]
            gtf = kw.get("gtf")
            if gtf:
                cmd += ["--gtf", str(gtf)]
            if kw.get("bowtie2"):
                # 默认 aligner 为 bowtie；riboseq 流程与 Debian 容器均配 bowtie2
                cmd += ["--bowtie2"]
            cmd += [str(reference_genome), str(reference_name)]

        elif subcommand == "calculate-expression":
            binary = self._resolve_binary()
            index = kw.get("index")
            if not index:
                raise RuntimeError("calculate-expression 需要 --index（rsem 参考前缀）")
            prefix = kw.get("prefix")
            if not prefix:
                raise RuntimeError("calculate-expression 需要 --prefix（输出前缀，生成 .genes/.isoforms.results）")
            cmd = [binary, "--num-threads", str(threads)]

            bam = kw.get("alignments")
            reads1 = kw.get("reads1")
            reads2 = kw.get("reads2")
            if bam and (reads1 or reads2):
                raise RuntimeError("--alignments 与 --reads/--reads2 输入模式互斥，请二选一")
            if bam:
                cmd += ["--alignments", str(bam)]
                if kw.get("paired_end"):
                    cmd += ["--paired-end"]
            else:
                if reads2 and not reads1:
                    raise RuntimeError("双端 reads 需同时提供 --reads（mate1）与 --reads2（mate2）")
                if reads1:
                    if reads2:
                        cmd += ["--paired-end"]
                    if kw.get("bowtie2"):
                        # fastq 直算模式默认走 bowtie，显式切换 bowtie2
                        cmd += ["--bowtie2"]
                    cmd += [str(reads1)]
                    if reads2:
                        cmd += [str(reads2)]
                else:
                    raise RuntimeError(
                        "calculate-expression 需要 --alignments（BAM，riboseq 主用法）"
                        " 或 --reads（FASTQ，直算模式）"
                    )

            # Ribo-seq 常用参数（riboseq 流程 config：fragment_length_mean=300, sd=100）
            mean = kw.get("fragment_length_mean")
            if mean:
                cmd += ["--fragment-length-mean", str(mean)]
            sd = kw.get("fragment_length_sd")
            if sd:
                cmd += ["--fragment-length-sd", str(sd)]
            strandedness = kw.get("strandedness")
            if strandedness and strandedness != "none":
                cmd += ["--strandedness", str(strandedness)]

            cmd += [str(index), str(prefix)]
        else:
            raise RuntimeError(f"未知子命令: {subcommand}")

        # 高级透传（慎用）
        extra = kw.get("extra_args")
        if extra:
            cmd += str(extra).split()

        return cmd


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="rsem-skill",
        description="RSEM native 技能驱动（自动线程/内存/IO 优化）",
    )
    p.add_argument("--schema", action="store_true", help="输出 JSON Schema 后退出")
    p.add_argument("--list-commands", action="store_true", help="列出支持的子命令")
    sub = p.add_subparsers(dest="subcommand", metavar="<subcommand>")

    # prepare-reference: rsem-prepare-reference [--gtf] [--bowtie2] <genome.fa> <reference_name>
    pp = sub.add_parser("prepare-reference", help=SUBCOMMANDS["prepare-reference"])
    pp.add_argument("reference_genome", help="参考基因组 FASTA（可 .gz；rsem 自动 bgzip/索引）")
    pp.add_argument("reference_name", help="输出索引 basename（生成 .seq/.grp/.ti/.transcripts.fa 等）")
    pp.add_argument("--gtf", help="GTF 基因注释（转录本结构；riboseq 必给）")
    pp.add_argument("--bowtie2", action="store_true", help="用 bowtie2（而非默认 bowtie）建立参考索引")
    pp.add_argument("--extra-args", dest="extra_args", help="透传给 rsem-prepare-reference 的额外参数（高级用法，慎用）")
    _add_runtime_opts(pp)

    # calculate-expression: rsem-calculate-expression [flags] input(s) <reference_name> <sample_name>
    pc = sub.add_parser("calculate-expression", help=SUBCOMMANDS["calculate-expression"])
    pc.add_argument("--alignments", help="输入为已比对 SAM/BAM/CRAM（riboseq 主用法：umi 去重后 BAM）")
    pc.add_argument("--reads", dest="reads1", help="单端 reads 或双端 mate1（FASTQ，可 .gz；直算模式）")
    pc.add_argument("--reads2", help="双端 mate2（FASTQ，可 .gz；提供即自动 --paired-end）")
    pc.add_argument("--bowtie2", action="store_true", help="fastq 直算模式用 bowtie2（而非默认 bowtie）比对")
    pc.add_argument("--paired-end", action="store_true", help="输入为双端数据（BAM 模式显式声明；reads 模式由 --reads2 推断）")
    pc.add_argument("--index", required=True, help="RSEM 参考前缀（prepare-reference 的 reference_name）")
    pc.add_argument("--prefix", required=True, help="输出前缀（生成 <prefix>.genes.results / .isoforms.results）")
    pc.add_argument("--fragment-length-mean", type=int, help="片段长度均值（riboseq 默认 300）")
    pc.add_argument("--fragment-length-sd", type=int, help="片段长度标准差（riboseq 默认 100）")
    pc.add_argument("--strandedness", choices=["forward", "reverse", "none"], default="none",
                    help="链特异性协议（默认 none；riboseq 流程为 forward）")
    pc.add_argument("--extra-args", dest="extra_args", help="透传给 rsem-calculate-expression 的额外参数（高级用法，慎用）")
    _add_runtime_opts(pc)

    return p


def _add_runtime_opts(p: argparse.ArgumentParser) -> None:
    """为每个子命令附加运行期覆盖项（线程/临时目录）。"""
    p.add_argument("--threads", type=int, help="覆盖默认线程数")
    p.add_argument("--tmpdir", help="覆盖默认临时目录")


def main(argv: list[str] | None = None) -> int:
    args = list(argv) if argv is not None else sys.argv[1:]

    # 先拦截自省命令（不依赖子命令）
    if "--list-commands" in args:
        for k, v in SUBCOMMANDS.items():
            print(f"{k:20s} {v}")
        return 0
    if "--schema" in args:
        skill = RSEMSkill()
        print(json.dumps(skill.schema(), indent=2, ensure_ascii=False))
        return 0

    ns = build_parser().parse_args(args)
    if not ns.subcommand:
        build_parser().print_help(sys.stderr)
        return 2

    skill = RSEMSkill()
    if getattr(ns, "tmpdir", None):
        skill.tmpdir = ns.tmpdir
        skill.env_vars["TMPDIR"] = ns.tmpdir

    kw = {k: v for k, v in vars(ns).items()
          if k not in ("subcommand", "threads", "tmpdir") and v is not None}
    kw["threads"] = ns.threads

    try:
        result = skill.run(ns.subcommand, **kw)
    except RuntimeError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    # rsem 主产物为文件，日志走 stderr/stdout；原样透传
    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
