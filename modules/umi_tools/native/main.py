#!/usr/bin/env python3
"""umi_tools native 标准入口驱动。

支持两种调用模式：
1. CLI 直跑（人类 / Shell）：
   python main.py extract -I input.fastq -o umi.fastq --bc-pattern NNNNNNNN --extract-method string
   python main.py dedup -I input.bam -o dedup.bam --method unique
   python main.py dedup -I input.bam -o dedup.bam --paired --output-stats stats_prefix
2. Agent Function Calling / Schema 自省：
   python main.py --schema          # 打印 JSON Schema（合并软件级 meta.yaml 导出）
   python main.py --list-commands   # 列出支持的子命令

说明：umi_tools 1.1.6 的 extract/dedup 为单进程 Python 实现，无多线程开关
（extract 的 -p 短选项属于 --bc-pattern，勿与线程混淆）；--threads 仅作
资源声明保留（供上层调度器读取 optimization.per_subcommand_threads），不注入命令。
"""

from __future__ import annotations

import argparse
import json
import os
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
    "extract": "从 FASTQ 中提取 UMI/细胞条形码并写入 read name（支持 SE/PE）",
    "dedup": "依据 read name 中的 UMI 与比对坐标去除 PCR 重复",
}

# extract 可用的官方提取方法（umi_tools 1.1.6：string / regex；read_id 已并入 dedup）
EXTRACT_METHODS = ["string", "regex"]
# dedup 可用的 UMI 分组方法（默认 directional）
DEDUP_METHODS = ["unique", "percentile", "cluster", "adjacency", "directional"]


class UmiToolsSkill(base.SkillBase):
    software = "umi_tools"
    binary = "umi_tools"

    def _guess_meta_path(self) -> Path:
        # 单 meta.yaml 结构：native/main.py 的上级目录即 modules/umi_tools/，软件级 meta.yaml 在此
        return _HERE.parent / "meta.yaml"

    def _effective_threads(self, subcommand: str, override: int | None) -> int:
        """线程选择优先级：用户显式 > 子命令建议 > 全局默认（仅资源声明用）。"""
        if override and override > 0:
            return override
        per = (self.meta.get("optimization", {}) or {}).get("per_subcommand_threads", {})
        return int(per.get(subcommand, per.get("default", self.cpus)))

    def build_command(self, subcommand: str, **kw) -> list[str]:
        """根据子命令与参数构建 umi_tools 命令行。"""
        binary = self._resolve_binary()
        cmd: list[str] = [binary, subcommand]

        # 公共 I/O（umi_tools 约定 -I / -S）
        inp = kw.get("input")
        if inp:
            cmd += ["-I", str(inp)]
        out = kw.get("output")
        if out:
            cmd += ["-S", str(out)]

        # 临时目录：显式 --temp-dir（umi_tools 公共选项），并依赖 env TMPDIR 兜底
        if self.tmpdir:
            cmd += ["--temp-dir", str(self.tmpdir)]

        if subcommand == "extract":
            if kw.get("bc_pattern"):
                cmd += ["--bc-pattern", str(kw["bc_pattern"])]
            if kw.get("bc_pattern2"):
                cmd += ["--bc-pattern2", str(kw["bc_pattern2"])]
            if kw.get("read2_in"):
                cmd += ["--read2-in", str(kw["read2_in"])]
            if kw.get("read2_out"):
                cmd += ["--read2-out", str(kw["read2_out"])]
            method = kw.get("extract_method")
            if method:
                if method not in EXTRACT_METHODS:
                    raise ValueError(f"extract_method 必须是 {EXTRACT_METHODS} 之一: {method}")
                cmd += ["--extract-method", method]
            if kw.get("three_prime"):
                cmd.append("--3prime")
        elif subcommand == "dedup":
            method = kw.get("method")
            if method:
                if method not in DEDUP_METHODS:
                    raise ValueError(f"dedup method 必须是 {DEDUP_METHODS} 之一: {method}")
                cmd += ["--method", method]
            if kw.get("paired"):
                cmd.append("--paired")
            if kw.get("output_stats"):
                cmd += ["--output-stats", str(kw["output_stats"])]
        else:
            raise ValueError(f"不支持的子命令: {subcommand}")

        # 让日志走 stderr，stdout 仅保留真正数据（BAM/FASTQ）
        cmd.append("--log2stderr")

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
        prog="umi-tools-skill",
        description="umi_tools native 技能驱动（UMI 提取 / 去重）",
    )
    p.add_argument("--schema", action="store_true", help="输出 JSON Schema 后退出")
    p.add_argument("--list-commands", action="store_true", help="列出支持的子命令")
    sub = p.add_subparsers(dest="subcommand", metavar="<subcommand>")

    # extract
    pe = sub.add_parser("extract", help=SUBCOMMANDS["extract"])
    pe.add_argument("-I", "--input", help="输入 FASTQ（.gz 自动解压；省略则读 stdin）")
    pe.add_argument("-o", "--output", help="输出 FASTQ（省略则写 stdout）")
    pe.add_argument("--bc-pattern", help="read1 条形码模式（N=UMI, C=cell, X=保留；如 NNNNNNNN）")
    pe.add_argument("--bc-pattern2", help="read2 条形码模式（PE 拆分 UMI 时）")
    pe.add_argument("--read2-in", help="PE read2 输入文件")
    pe.add_argument("--read2-out", help="PE read2 输出文件")
    pe.add_argument("--extract-method", choices=EXTRACT_METHODS,
                    help="提取方法：string=序列固定位置 / regex=正则（默认由 umi_tools 决定）")
    pe.add_argument("--3prime", action="store_true", help="条形码位于 read 3' 端")
    _add_runtime_opts(pe)

    # dedup
    pd = sub.add_parser("dedup", help=SUBCOMMANDS["dedup"])
    pd.add_argument("-I", "--input", required=True, help="输入 BAM（read name 需含 UMI）")
    pd.add_argument("-o", "--output", required=True, help="去重输出 BAM")
    pd.add_argument("--method", choices=DEDUP_METHODS,
                    help="UMI 分组方法（默认 directional；测试/确定性场景用 unique）")
    pd.add_argument("--paired", action="store_true", help="paired-end BAM，成对输出")
    pd.add_argument("--output-stats", help="输出统计前缀（生成 _edit_distance.tsv 等）")
    _add_runtime_opts(pd)

    return p


def _add_runtime_opts(p: argparse.ArgumentParser) -> None:
    """为每个子命令附加运行期覆盖项（线程/临时目录）。"""
    p.add_argument("--threads", type=int, help="资源声明用（umi_tools 单进程，不注入命令）")
    p.add_argument("--tmpdir", help="覆盖默认临时目录（映射 umi_tools --temp-dir / TMPDIR）")
    p.add_argument("--extra-args", dest="extra_args", help="额外透传参数（慎用）")


def main(argv: list[str] | None = None) -> int:
    args = list(argv) if argv is not None else sys.argv[1:]

    # 先拦截自省命令（不依赖子命令）
    if "--list-commands" in args:
        for k, v in SUBCOMMANDS.items():
            print(f"{k:12s} {v}")
        return 0
    if "--schema" in args:
        skill = UmiToolsSkill()
        print(json.dumps(skill.schema(), indent=2, ensure_ascii=False))
        return 0

    ns = build_parser().parse_args(args)
    if not ns.subcommand:
        build_parser().print_help(sys.stderr)
        return 2

    skill = UmiToolsSkill()
    if getattr(ns, "tmpdir", None):
        skill.tmpdir = ns.tmpdir

    kw = {k: v for k, v in vars(ns).items()
          if k not in ("subcommand", "threads", "tmpdir") and v is not None}
    kw["threads"] = ns.threads

    try:
        result = skill.run(ns.subcommand, **kw)
    except (RuntimeError, ValueError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    if result.stderr:
        sys.stderr.write(result.stderr)
    if result.stdout:
        sys.stdout.write(result.stdout)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
