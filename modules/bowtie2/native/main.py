#!/usr/bin/env python3
"""bowtie2 native 标准入口驱动。

支持两种调用模式：
1. CLI 直跑（人类 / Shell）：
   python main.py build refs.fa refs --threads 8
   python main.py align -x refs -1 r1.fq.gz -2 r2.fq.gz -o out.sam --threads 8
   python main.py align -x refs -U single.fq.gz -o out.sam --threads 4
2. Agent Function Calling / Schema 自省：
   python main.py --schema          # 打印 JSON Schema
   python main.py --list-commands   # 列出支持的子命令

所有子命令自动注入线程（--threads）与临时目录（--tmpdir）。
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
    "build": "bowtie2-build：为参考序列建立 FM-Index（.bt2 索引族）",
    "align": "bowtie2：将单端(-U)/双端(-1/-2) reads 比对到索引并输出 SAM",
}


class Bowtie2Skill(base.SkillBase):
    software = "bowtie2"
    binary = "bowtie2"

    def __init__(self, meta_path: str | Path | None = None):
        # 单 meta 模式下 meta.yaml 位于软件级 modules/bowtie2/meta.yaml（不在 native/ 下），
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
        """解析配套可执行文件（如 bowtie2-build），带清晰报错。"""
        path = shutil.which(tool)
        if not path:
            raise RuntimeError(
                f"未找到可执行文件 '{tool}'，请先通过 Conda/Docker/Apptainer 安装 "
                "（Debian 包 bowtie2 会同时提供 bowtie2 / bowtie2-build）。"
            )
        return path

    def build_command(self, subcommand: str, **kw) -> list[str]:
        """根据子命令与参数构建 bowtie2 命令行。"""
        threads = self._effective_threads(subcommand, kw.get("threads"))

        if subcommand == "build":
            binary = self._resolve_tool("bowtie2-build")
            reference = kw.get("reference")
            if not reference:
                raise RuntimeError("build 需要 reference（参考 FASTA）")
            index_base = kw.get("index_base") or kw.get("index")
            if not index_base:
                raise RuntimeError("build 需要 index_base（输出索引 basename）")
            cmd: list[str] = [binary, "--threads", str(threads)]
            # 临时目录优化（bowtie2-build 自身无 -T，用 TMPDIR 已覆盖；保留此处便于扩展）
            cmd += [str(reference), str(index_base)]
        elif subcommand == "align":
            binary = self._resolve_binary()
            index = kw.get("index")
            if not index:
                raise RuntimeError("align 需要 -x/--index（bowtie2 索引 basename）")
            cmd = [binary, "--threads", str(threads), "-x", str(index)]

            reads1 = kw.get("reads1")
            reads2 = kw.get("reads2")
            reads = kw.get("reads")
            if reads1 and reads2:
                cmd += ["-1", str(reads1), "-2", str(reads2)]
            elif reads1 or reads2:
                raise RuntimeError("双端比对需同时提供 -1/--reads1 与 -2/--reads2")
            elif reads:
                cmd += ["-U", str(reads)]
            else:
                raise RuntimeError("align 需要 -U/--reads（单端）或 -1/-2（双端）reads 输入")

            output = kw.get("output")
            if output:
                cmd += ["-S", str(output)]
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
        prog="bowtie2-skill",
        description="bowtie2 native 技能驱动（自动线程/内存/IO 优化）",
    )
    p.add_argument("--schema", action="store_true", help="输出 JSON Schema 后退出")
    p.add_argument("--list-commands", action="store_true", help="列出支持的子命令")
    sub = p.add_subparsers(dest="subcommand", metavar="<subcommand>")

    # build: bowtie2-build <reference_in> <bt2_index_base>
    pb = sub.add_parser("build", help=SUBCOMMANDS["build"])
    pb.add_argument("reference", help="参考序列 FASTA（可多文件，用逗号分隔路径）")
    pb.add_argument("index_base", help="输出索引 basename（生成 .1.bt2 … .rev.2.bt2）")
    _add_runtime_opts(pb)

    # align: bowtie2 -x <index> (-1/-2 | -U) [-S out.sam]
    pa = sub.add_parser("align", help=SUBCOMMANDS["align"])
    pa.add_argument("-x", "--index", required=True, help="bowtie2 索引 basename（不含 .1.bt2 后缀）")
    pa.add_argument("-1", "--reads1", help="双端 reads mate1（FASTQ/FASTA，可 .gz）")
    pa.add_argument("-2", "--reads2", help="双端 reads mate2（FASTQ/FASTA，可 .gz）")
    pa.add_argument("-U", "--reads", help="单端 reads（FASTQ/FASTA，可 .gz）")
    pa.add_argument("-S", "--output", help="SAM 输出文件（默认 stdout）")
    pa.add_argument("--extra-args", dest="extra_args", help="透传给 bowtie2 的额外参数（高级用法，慎用）")
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
        skill = Bowtie2Skill()
        print(json.dumps(skill.schema(), indent=2, ensure_ascii=False))
        return 0

    ns = build_parser().parse_args(args)
    if not ns.subcommand:
        build_parser().print_help(sys.stderr)
        return 2

    skill = Bowtie2Skill()
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

    # 非捕获类（无 stdout）的子命令直接继承退出码
    if not result.stdout and not result.stderr:
        return result.returncode
    if result.stdout:
        # align 无 -S 时 SAM 走 stdout 直接打印
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
