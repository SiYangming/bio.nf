#!/usr/bin/env python3
"""STAR native 标准入口驱动。

支持两种调用模式：
1. CLI 直跑（人类 / Shell）：
   python main.py index refs.fa genomeDir --gtf ann.gtf --sjdb-overhang 100 --threads 8
   python main.py align --genome-dir genomeDir -1 r1.fq.gz -2 r2.fq.gz -o out.bam --threads 8
   python main.py align --genome-dir genomeDir -U single.fq.gz -o out.sam \
       --out-sam-type SAM --threads 4
2. Agent Function Calling / Schema 自省：
   python main.py --schema          # 打印 JSON Schema
   python main.py --list-commands   # 列出支持的子命令

所有子命令自动注入线程（--runThreadN）与临时目录（--outTmpDir / TMPDIR）。
二进制名称为 STAR（Debian 软件包名为 rna-star）。
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

# 让 main.py 既能被 skill-cli 导入（已加入 modules/ 路径），也能直接运行
_HERE = Path(__file__).resolve().parent
_SKILLS_ROOT = _HERE.parent.parent
if str(_SKILLS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SKILLS_ROOT))

import base  # noqa: E402

# 子命令语义清单（用于 --list-commands 与 Schema description）
SUBCOMMANDS = {
    "index": "STAR --runMode genomeGenerate：参考 FASTA（+可选 GTF）→ STAR 基因组索引目录",
    "align": "STAR --runMode alignReads：SE/PE reads → 基因组比对 SAM/BAM",
}

# --outSAMtype → 最终比对文件后缀（STAR 的 --outFileNamePrefix 为纯前缀拼接）
ALIGN_OUT_SUFFIX = {
    "BAM SortedByCoordinate": "Aligned.sortedByCoord.out.bam",
    "BAM Unsorted": "Aligned.out.bam",
    "SAM": "Aligned.out.sam",
}
VALID_OUT_SAM_TYPES = tuple(ALIGN_OUT_SUFFIX)


class StarSkill(base.SkillBase):
    software = "star"
    binary = "STAR"

    def __init__(self, meta_path: str | Path | None = None):
        # 单 meta 模式下 meta.yaml 位于软件级 modules/star/meta.yaml（不在 native/ 下），
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

    def _readfiles_command(self, first_read: str, override: str | None) -> list[str]:
        """根据输入后缀自动推导 --readFilesCommand（.gz→zcat / .bz2→bunzip2 -c）。"""
        if override:
            return ["--readFilesCommand", override]
        if first_read.endswith(".gz"):
            return ["--readFilesCommand", "zcat"]
        if first_read.endswith(".bz2"):
            return ["--readFilesCommand", "bunzip2", "-c"]
        return []

    def build_command(self, subcommand: str, **kw) -> list[str]:
        """根据子命令与参数构建 STAR 命令行。"""
        threads = self._effective_threads(subcommand, kw.get("threads"))

        if subcommand == "index":
            binary = self._resolve_binary()
            fasta = kw.get("fasta")
            if not fasta:
                raise RuntimeError("index 需要参考 FASTA（--genomeFastaFiles，可多文件逗号分隔）")
            genome_dir = kw.get("genome_dir")
            if not genome_dir:
                raise RuntimeError("index 需要 genome_dir（输出索引目录 --genomeDir）")
            cmd: list[str] = [
                binary,
                "--runThreadN", str(threads),
                "--runMode", "genomeGenerate",
                "--genomeDir", str(genome_dir),
                "--genomeFastaFiles", str(fasta),
            ]
            if kw.get("gtf"):
                cmd += ["--sjdbGTFfile", str(kw["gtf"])]
            if kw.get("sjdb_overhang"):
                cmd += ["--sjdbOverhang", str(kw["sjdb_overhang"])]
            if kw.get("genome_sa_index_nbases") is not None:
                # 小基因组（< 2^14 bp）必须调小，否则 STAR 报 FATAL
                cmd += ["--genomeSAindexNbases", str(kw["genome_sa_index_nbases"])]
            if kw.get("out_file_name_prefix"):
                cmd += ["--outFileNamePrefix", str(kw["out_file_name_prefix"])]
        elif subcommand == "align":
            binary = self._resolve_binary()
            genome_dir = kw.get("genome_dir")
            if not genome_dir:
                raise RuntimeError("align 需要 --genome-dir（STAR 索引目录）")

            reads1 = kw.get("reads1")
            reads2 = kw.get("reads2")
            reads = kw.get("reads")
            if reads1 and reads2:
                read_files = [str(reads1), str(reads2)]
            elif reads1 or reads2:
                raise RuntimeError("双端比对需同时提供 -1/--reads1 与 -2/--reads2")
            elif reads:
                read_files = [str(reads)]
            else:
                raise RuntimeError("align 需要 -1/-2（双端）或 -U/--reads（单端）reads 输入")

            out_sam_type = kw.get("out_sam_type") or "BAM SortedByCoordinate"
            if out_sam_type not in VALID_OUT_SAM_TYPES:
                raise RuntimeError(f"--out-sam-type 必须是 {' / '.join(VALID_OUT_SAM_TYPES)} 之一")

            cmd = [
                binary,
                "--runThreadN", str(threads),
                "--runMode", "alignReads",
                "--genomeDir", str(genome_dir),
                "--readFilesIn", *read_files,
                "--outSAMtype", *out_sam_type.split(),
                "--genomeLoad", kw.get("genome_load") or "NoSharedMemory",
            ]
            cmd += self._readfiles_command(read_files[0], kw.get("read_files_command"))
            # 前缀/临时目录由 main() 计算好传入（默认隔离 run_dir，防止 Log/SJ 等污染工作目录）
            prefix = kw.get("_prefix")
            if prefix:
                cmd += ["--outFileNamePrefix", str(prefix)]
            out_tmp_dir = kw.get("_out_tmp_dir")
            if out_tmp_dir:
                cmd += ["--outTmpDir", str(out_tmp_dir)]
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
        prog="star-skill",
        description="STAR native 技能驱动（自动线程/内存/IO 优化）",
    )
    p.add_argument("--schema", action="store_true", help="输出 JSON Schema 后退出")
    p.add_argument("--list-commands", action="store_true", help="列出支持的子命令")
    sub = p.add_subparsers(dest="subcommand", metavar="<subcommand>")

    # index: STAR --runMode genomeGenerate
    pi = sub.add_parser("index", help=SUBCOMMANDS["index"])
    pi.add_argument("fasta", help="参考基因组 FASTA（可多文件，用逗号分隔路径）")
    pi.add_argument("genome_dir", help="输出 STAR 索引目录（--genomeDir）")
    pi.add_argument("--gtf", help="注释 GTF（--sjdbGTFfile，生成剪接位点索引）")
    pi.add_argument("--sjdb-overhang", type=int, dest="sjdb_overhang",
                    help="--sjdbOverhang（建议 readLength-1，默认 100）")
    pi.add_argument("--genome-sa-index-nbases", type=int, dest="genome_sa_index_nbases",
                    help="--genomeSAindexNbases（小基因组请调小，如 5）")
    pi.add_argument("--out-file-name-prefix", dest="out_file_name_prefix",
                    help="--outFileNamePrefix（默认空：Log.out/SJ.out.tab 等落在当前目录）")
    pi.add_argument("--extra-args", dest="extra_args", help="透传给 STAR 的额外参数（高级用法，慎用）")
    _add_runtime_opts(pi)

    # align: STAR --runMode alignReads
    pa = sub.add_parser("align", help=SUBCOMMANDS["align"])
    pa.add_argument("--genome-dir", "-g", dest="genome_dir", required=True,
                    help="STAR 索引目录（--genomeDir）")
    pa.add_argument("-1", "--reads1", help="双端 reads mate1（FASTQ/FASTA，可 .gz/.bz2）")
    pa.add_argument("-2", "--reads2", help="双端 reads mate2（FASTQ/FASTA，可 .gz/.bz2）")
    pa.add_argument("-U", "--reads", help="单端 reads（FASTQ/FASTA，可 .gz/.bz2）")
    pa.add_argument("-o", "--output", help="比对结果文件路径（SAM/BAM，依 --out-sam-type）")
    pa.add_argument("--out-sam-type", dest="out_sam_type", default="BAM SortedByCoordinate",
                    choices=list(VALID_OUT_SAM_TYPES), help="--outSAMtype（默认 BAM SortedByCoordinate）")
    pa.add_argument("--genome-load", dest="genome_load", default="NoSharedMemory",
                    choices=["NoSharedMemory", "LoadAndRemove", "LoadAndKeep", "Load"],
                    help="--genomeLoad 共享内存模式（默认 NoSharedMemory）")
    pa.add_argument("--read-files-command", dest="read_files_command",
                    help="--readFilesCommand（默认按扩展名自动 zcat / bunzip2 -c）")
    pa.add_argument("--out-file-name-prefix", dest="out_file_name_prefix",
                    help="--outFileNamePrefix（自定义时跳过 -o 挪动，结果留在该前缀下）")
    pa.add_argument("--extra-args", dest="extra_args", help="透传给 STAR 的额外参数（高级用法，慎用）")
    _add_runtime_opts(pa)

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
            print(f"{k:12s} {v}")
        return 0
    if "--schema" in args:
        skill = StarSkill()
        print(json.dumps(skill.schema(), indent=2, ensure_ascii=False))
        return 0

    ns = build_parser().parse_args(args)
    if not ns.subcommand:
        build_parser().print_help(sys.stderr)
        return 2

    skill = StarSkill()
    if getattr(ns, "tmpdir", None):
        skill.tmpdir = ns.tmpdir
        skill.env_vars["TMPDIR"] = ns.tmpdir

    kw = {k: v for k, v in vars(ns).items()
          if k not in ("subcommand", "threads", "tmpdir") and v is not None}
    kw["threads"] = ns.threads

    run_dir: str | None = None
    try:
        if ns.subcommand == "align" and not ns.out_file_name_prefix:
            # 隔离 run_dir：STAR 的 Log.out / SJ.out.tab 等副产物留在临时目录，
            # 结束后只把主比对结果挪到 -o；run_dir 放在输出同目录（保证 --outTmpDir 同文件系统）。
            parent = os.path.dirname(os.path.abspath(ns.output)) if ns.output else skill.tmpdir
            run_dir = tempfile.mkdtemp(prefix="star_align_", dir=parent)
            kw["_prefix"] = run_dir + os.sep
            kw["_out_tmp_dir"] = os.path.join(run_dir, "_STARtmp")

        result = skill.run(ns.subcommand, **kw)

        # align：把 run_dir 内主结果文件挪到 -o 指定位置（自定义 prefix 时跳过）
        if ns.subcommand == "align" and not ns.out_file_name_prefix:
            out_sam_type = ns.out_sam_type or "BAM SortedByCoordinate"
            produced = os.path.join(run_dir, ALIGN_OUT_SUFFIX[out_sam_type])
            if ns.output:
                if not os.path.exists(produced):
                    raise RuntimeError(
                        f"STAR 未产出预期文件 {produced}（返回码 {result.returncode}），"
                        "请检查 --extra-args / --out-sam-type 组合"
                    )
                out_abs = os.path.abspath(ns.output)
                os.makedirs(os.path.dirname(out_abs), exist_ok=True)
                shutil.move(produced, out_abs)
            else:
                # 未指定 -o：打印产物路径（run_dir 保留，便于取 SJ.out.tab 等副产物）
                run_dir = None  # 跳过 finally 清理
                print(produced)
    except RuntimeError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1
    finally:
        if run_dir is not None and os.path.isdir(run_dir):
            shutil.rmtree(run_dir, ignore_errors=True)

    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
