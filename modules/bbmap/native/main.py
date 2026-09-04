#!/usr/bin/env python3
"""bbmap native 标准入口驱动。

支持两种调用模式：
1. CLI 直跑（人类 / Shell）：
   python main.py index --ref refs.fa --path refs_index --threads 8
   python main.py align --in reads.fq.gz --path refs_index \
       --out out.sam --outm mapped.fq.gz --outu unmapped.fq.gz --threads 8
   python main.py align --in reads.fq --ref rRNA.fa \
       --outm rRNA.fq.gz --outu non_rRNA.fq.gz --nodisk --ambiguous best \
       --trimreaddescription --threads 8
2. Agent Function Calling / Schema 自省：
   python main.py --schema          # 打印 JSON Schema
   python main.py --list-commands   # 列出支持的子命令

参数命名对齐 bbmap.sh 的 key=value 风格（in/ref/path/out/outm/outu/threads/
nodisk/ambiguous/trimreaddescription），核心参数自动注入线程与临时目录。
"""

from __future__ import annotations

import argparse
import json
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
    "index": "bbmap.sh：为参考序列构建 BBMap 索引目录（ref= + path=，索引落盘供 align 复用）",
    "align": "bbmap.sh：reads 比对到参考（ref=）或已有索引（path=），支持 out/outm/outu 分流输出",
}


class BBMapSkill(base.SkillBase):
    software = "bbmap"
    binary = "bbmap.sh"

    def __init__(self, meta_path: str | Path | None = None):
        # 单 meta 模式下 meta.yaml 位于软件级 modules/bbmap/meta.yaml（不在 native/ 下），
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

    def build_command(self, subcommand: str, **kw) -> list[str]:
        """根据子命令与参数构建 bbmap.sh 命令行（key=value 风格）。"""
        binary = self._resolve_binary()
        threads = self._effective_threads(subcommand, kw.get("threads"))
        cmd: list[str] = [binary, f"threads={threads}"]

        if subcommand == "index":
            # bbmap.sh ref=<ref.fa> path=<dir>：把参考索引构建到 path 目录
            reference = kw.get("ref") or kw.get("reference")
            index_dir = kw.get("path") or kw.get("index_dir")
            if not reference:
                raise RuntimeError("index 需要 --ref/--reference（参考 FASTA）")
            if not index_dir:
                raise RuntimeError("index 需要 --path/--index-dir（索引输出目录）")
            cmd += [f"ref={reference}", f"path={index_dir}"]
        elif subcommand == "align":
            reads = kw.get("in") or kw.get("reads")
            if not reads:
                raise RuntimeError("align 需要 --in/--reads（reads FASTQ/FASTA，可 .gz）")
            cmd.append(f"in={reads}")
            reference = kw.get("ref") or kw.get("reference")
            index_dir = kw.get("path") or kw.get("index_dir")
            if reference:
                cmd.append(f"ref={reference}")
            elif index_dir:
                cmd.append(f"path={index_dir}")
            else:
                raise RuntimeError("align 需要 --ref（参考 FASTA）或 --path（已有索引目录）之一")

            output = kw.get("out") or kw.get("output")
            if output:
                cmd.append(f"out={output}")
            outm = kw.get("outm") or kw.get("mapped")
            if outm:
                cmd.append(f"outm={outm}")
            outu = kw.get("outu") or kw.get("unmapped")
            if outu:
                cmd.append(f"outu={outu}")

            if kw.get("nodisk") is True:
                cmd.append("nodisk=t")
            ambiguous = kw.get("ambiguous")
            if ambiguous:
                cmd.append(f"ambiguous={ambiguous}")
            if kw.get("trimreaddescription") is True:
                cmd.append("trimreaddescription=t")
        else:
            raise RuntimeError(f"未知子命令: {subcommand}")

        # 高级透传（慎用，key=value 风格直接透传）
        extra = kw.get("extra_args")
        if extra:
            cmd += str(extra).split()

        return cmd


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="bbmap-skill",
        description="bbmap native 技能驱动（自动线程/内存/IO 优化）",
    )
    p.add_argument("--schema", action="store_true", help="输出 JSON Schema 后退出")
    p.add_argument("--list-commands", action="store_true", help="列出支持的子命令")
    sub = p.add_subparsers(dest="subcommand", metavar="<subcommand>")

    # index: bbmap.sh ref=<ref> path=<dir>
    pi = sub.add_parser("index", help=SUBCOMMANDS["index"])
    pi.add_argument("--ref", "--reference", dest="ref", help="参考序列 FASTA（等价 bbmap ref=）")
    pi.add_argument("--path", "--index-dir", dest="path", help="索引输出目录（等价 bbmap path=）")
    _add_runtime_opts(pi)

    # align: bbmap.sh in=<reads> (ref=<ref> | path=<dir>) [out=/outm=/outu=]
    pa = sub.add_parser("align", help=SUBCOMMANDS["align"])
    pa.add_argument("--in", "--reads", dest="in_reads", help="reads 输入（FASTQ/FASTA，可 .gz，等价 bbmap in=）")
    pa.add_argument("--ref", "--reference", dest="ref", help="参考序列 FASTA（等价 bbmap ref=，临时索引）")
    pa.add_argument("--path", "--index-dir", dest="path", help="已有 BBMap 索引目录（等价 bbmap path=）")
    pa.add_argument("--out", "--output", dest="out", help="比对输出文件（.sam/.bam，等价 bbmap out=）")
    pa.add_argument("--outm", "--mapped", dest="outm", help="比对上的 reads 输出（等价 bbmap outm=）")
    pa.add_argument("--outu", "--unmapped", dest="outu", help="未比对 reads 输出（等价 bbmap outu=）")
    pa.add_argument("--nodisk", action="store_true", help="不把索引写入磁盘（等价 nodisk=t）")
    pa.add_argument("--ambiguous", choices=["best", "toss", "all"],
                    help="多匹配处理策略（等价 ambiguous=best/toss/all）")
    pa.add_argument("--trimreaddescription", action="store_true",
                    help="去除 read 描述中的空格及之后内容（等价 trimreaddescription=t）")
    pa.add_argument("--extra-args", dest="extra_args",
                    help="透传给 bbmap.sh 的额外 key=value 参数（高级用法，慎用）")
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
        skill = BBMapSkill()
        print(json.dumps(skill.schema(), indent=2, ensure_ascii=False))
        return 0

    ns = build_parser().parse_args(args)
    if not ns.subcommand:
        build_parser().print_help(sys.stderr)
        return 2

    skill = BBMapSkill()
    if getattr(ns, "tmpdir", None):
        skill.tmpdir = ns.tmpdir
        skill.env_vars["TMPDIR"] = ns.tmpdir

    kw = {k: v for k, v in vars(ns).items()
          if k not in ("subcommand", "threads", "tmpdir") and v is not None}
    # align 的 --in 归一到 reads（build_command 同时接受 in/reads 键）
    if kw.get("in_reads"):
        kw["reads"] = kw.pop("in_reads")
    kw["threads"] = ns.threads

    try:
        result = skill.run(ns.subcommand, **kw)
    except RuntimeError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    # 非捕获类（无 stdout）的子命令直接继承退出码
    if not result.stdout and not result.stderr:
        return result.returncode
    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
