#!/usr/bin/env python3
"""cutadapt native 标准入口驱动。

支持两种调用模式：
1. CLI 直跑（人类 / Shell）：
   python main.py trim -a AACCGGTT -o out.fastq in.fastq --threads 4
   python main.py trim -a AGATCGGAAGAGC -A AGATCGGAAGAGC \
       -o out_R1.fastq.gz -p out_R2.fastq.gz in_R1.fastq.gz in_R2.fastq.gz
   python main.py adapter-removal -g ^ACACTCTTTCCCTACACG -o out.fastq in.fastq
2. Agent Function Calling / Schema 自省：
   python main.py --schema          # 打印 JSON Schema（读软件级 modules/cutadapt/meta.yaml）
   python main.py --list-commands   # 列出支持的子命令

子命令语义对齐 cutadapt 实际 CLI（-a/-g/-b/-q/-m/-M/-o/-p/--cores/--nextseq-trim 等）：
  - trim            通用 reads 裁剪：3'/5'/anywhere 接头（SE 与 PE）+ 质量修剪 + 长度过滤
  - adapter-removal 纯接头去除快捷入口（不暴露质量/长度选项，必须至少给一个接头参数）
线程注入使用 --cores；临时目录经 TMPDIR 注入。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

# 让 main.py 既能被 skill-cli 导入（已加入 modules/ 路径），也能直接运行
_HERE = Path(__file__).resolve().parent
_SKILLS_ROOT = _HERE.parent.parent  # modules/（base.py 所在层）
if str(_SKILLS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SKILLS_ROOT))

import base  # noqa: E402

# 子命令 -> 3'/5'/anywhere 接头是否可用的参数名（cutadapt 官方 CLI 短选项）
ADAPTER_FLAGS = {
    "adapter": "-a",      # 3' adapter（R1/SE）
    "front": "-g",        # 5' adapter（R1/SE）
    "anywhere": "-b",     # 5' 或 3' 均可
    "adapter_2": "-A",    # 3' adapter（R2，PE）
    "front_2": "-G",      # 5' adapter（R2，PE）
    "anywhere_2": "-B",   # 5' 或 3' 均可（R2，PE）
}

# 子命令语义清单（用于 --list-commands 与 Schema description）
SUBCOMMANDS = {
    "trim": "通用 reads 裁剪：3'/5'/anywhere 接头（SE/PE）+ 质量修剪 -q + 长度过滤 -m/-M + --nextseq-trim",
    "adapter-removal": "纯接头去除快捷入口（仅 -a/-g/-b 及 PE 配对 -A/-G/-B，必须提供接头序列）",
}


class CutadaptSkill(base.SkillBase):
    software = "cutadapt"
    binary = "cutadapt"

    def _guess_meta_path(self) -> Path:
        # 本仓库为单 meta.yaml 模式：软件级 meta 在 modules/<software>/meta.yaml（native/ 下不再放 meta.yaml）
        return _HERE.parent / "meta.yaml"

    def _effective_threads(self, subcommand: str, override: int | None) -> int:
        """线程选择优先级：用户显式 > per_subcommand_threads > default_cpus。"""
        if override and override > 0:
            return override
        per = (self.meta.get("optimization", {}) or {}).get("per_subcommand_threads", {})
        return int(per.get(subcommand, per.get("default", self.cpus)))

    def _add_adapter_args(self, cmd: list[str], kw: dict) -> None:
        """按 ADAPTER_FLAGS 顺序加入接头参数（先 R1/SE 后 R2/PE）。"""
        for key, flag in ADAPTER_FLAGS.items():
            val = kw.get(key)
            if val:
                cmd += [flag, str(val)]

    def build_command(self, subcommand: str, **kw) -> list[str]:
        """根据子命令与参数构建 cutadapt 命令行。"""
        binary = self._resolve_binary()
        cmd: list[str] = [binary]
        threads = self._effective_threads(subcommand, kw.get("threads"))
        cmd += ["--cores", str(threads)]

        inputs = kw.get("input") or []
        if isinstance(inputs, (list, tuple)):
            inputs = list(inputs)
        else:
            inputs = [str(inputs)] if inputs else []
        if not inputs:
            raise RuntimeError("cutadapt 至少需要一个输入 FASTQ（PE 时为 R1、R2 两个文件）")
        if len(inputs) > 2:
            raise RuntimeError(f"cutadapt 最多接受两个输入（SE/PE），收到 {len(inputs)} 个")

        # ---- 接头参数 ----
        if subcommand == "adapter-removal":
            has_adapter = any(kw.get(k) for k in ("adapter", "front", "anywhere",
                                                  "adapter_2", "front_2", "anywhere_2"))
            if not has_adapter:
                raise RuntimeError(
                    "adapter-removal 需要至少一个接头序列参数（-a/--adapter、-g/--front、"
                    "-b/--anywhere，PE 再加 -A/-G/-B）"
                )
        self._add_adapter_args(cmd, kw)

        # ---- 质量 / 长度 / NextSeq（trim 专属；adapter-removal 不暴露）----
        if subcommand == "trim":
            q = kw.get("quality_cutoff")
            if q:
                cmd += ["-q", str(q)]
            if kw.get("nextseq_trim"):
                cmd += ["--nextseq-trim", str(kw["nextseq_trim"])]
            if kw.get("min_length") is not None:
                cmd += ["-m", str(kw["min_length"])]
            if kw.get("max_length") is not None:
                cmd += ["-M", str(kw["max_length"])]

        # ---- 输出 ----
        output = kw.get("output")
        if output:
            cmd += ["-o", str(output)]
        paired_output = kw.get("paired_output")
        if paired_output:
            cmd += ["-p", str(paired_output)]

        # ---- 高级透传（慎用；如 4.3+ 才有的 --poly-a 等，先 cutadapt --help 核对）----
        extra = kw.get("extra_args")
        if extra:
            cmd += str(extra).split()

        # ---- 输入位置参数（PE：R1 在前 R2 在后）----
        cmd += [str(i) for i in inputs]
        return cmd


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="cutadapt-skill",
        description="cutadapt native 技能驱动（接头/质量/长度修剪；自动注入 --cores 线程与 TMPDIR）",
    )
    p.add_argument("--schema", action="store_true", help="输出 JSON Schema 后退出")
    p.add_argument("--list-commands", action="store_true", help="列出支持的子命令")
    sub = p.add_subparsers(dest="subcommand", metavar="<subcommand>")

    # trim：全参数
    pt = sub.add_parser("trim", help=SUBCOMMANDS["trim"])
    _add_adapter_opts(pt)
    pt.add_argument("-q", "--quality-cutoff", dest="quality_cutoff",
                    help="质量修剪阈值，如 20 或 20,15（3' 端 / 5' 端）")
    pt.add_argument("--nextseq-trim", type=int,
                    help="NextSeq 特殊质量修剪（如 20）")
    pt.add_argument("-m", "--min-length", dest="min_length", type=int, help="最短保留长度")
    pt.add_argument("-M", "--max-length", dest="max_length", type=int, help="最长保留长度")
    _add_output_opts(pt)

    # adapter-removal：纯接头去除
    pa = sub.add_parser("adapter-removal", help=SUBCOMMANDS["adapter-removal"])
    _add_adapter_opts(pa)
    _add_output_opts(pa)

    return p


def _add_adapter_opts(p: argparse.ArgumentParser) -> None:
    p.add_argument("-a", "--adapter", dest="adapter", help="3' adapter（R1/SE，如 -a AACCGGTT）")
    p.add_argument("-g", "--front", dest="front", help="5' adapter（R1/SE；^ 前缀锚定起始）")
    p.add_argument("-b", "--anywhere", dest="anywhere", help="5' 或 3' 均可的 adapter")
    p.add_argument("-A", "--adapter-2", dest="adapter_2", help="3' adapter（R2，PE）")
    p.add_argument("-G", "--front-2", dest="front_2", help="5' adapter（R2，PE）")
    p.add_argument("-B", "--anywhere-2", dest="anywhere_2", help="5' 或 3' 均可的 adapter（R2，PE）")


def _add_output_opts(p: argparse.ArgumentParser) -> None:
    p.add_argument("input", nargs="+", help="输入 FASTQ：SE 给 1 个，PE 给 R1 R2 两个")
    p.add_argument("-o", "--output", dest="output", help="输出 FASTQ（SE 主输出 / PE 的 R1）")
    p.add_argument("-p", "--paired-output", dest="paired_output", help="PE 的 R2 输出")
    p.add_argument("--extra-args", dest="extra_args",
                   help="透传给 cutadapt 的额外参数（高级用法，慎用；以空格分词）")
    # 运行期覆盖（放在子命令后）：线程/临时目录
    p.add_argument("--threads", type=int, help="覆盖默认线程数（映射到 --cores）")
    p.add_argument("--tmpdir", help="覆盖默认临时目录")


def main(argv: list[str] | None = None) -> int:
    args = list(argv) if argv is not None else sys.argv[1:]

    # 先拦截自省命令（不依赖子命令 / 不要求二进制存在）
    if "--list-commands" in args:
        for k, v in SUBCOMMANDS.items():
            print(f"{k:16s} {v}")
        return 0
    if "--schema" in args:
        skill = CutadaptSkill()
        print(json.dumps(skill.schema(), indent=2, ensure_ascii=False))
        return 0

    ns = build_parser().parse_args(args)
    if not ns.subcommand:
        build_parser().print_help(sys.stderr)
        return 2

    skill = CutadaptSkill()
    if getattr(ns, "tmpdir", None):
        skill.tmpdir = ns.tmpdir

    kw = {k: v for k, v in vars(ns).items()
          if k not in ("subcommand", "threads", "tmpdir") and v is not None}
    kw["threads"] = ns.threads

    try:
        result = skill.run(ns.subcommand, **kw)
    except RuntimeError as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    # cutadapt 运行统计写在 stderr；无 stdout 时直接回传退出码并透传 stderr
    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
