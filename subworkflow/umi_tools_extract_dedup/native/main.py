#!/usr/bin/env python3
"""umi_tools_extract_dedup: 可复用 UMI 处理阶段编排（umi_tools extract -> [流程自行比对] -> umi_tools dedup）

按「subworkflow/ 组合 = 跨模块固定套路」形态提供 UMI 阶段编排：
  extract（SE/PE，reads 去 UMI 写入 read name）
    ->（中间比对由调用流程提供，本编排不内置比对器；riboseq 用 bbmap/bowtie2/STAR）
  dedup（对含 UMI 的已比对 BAM 去 PCR 重复）

可执行三种模式（参照 subworkflow/fastp_bwa_samtools）：
  a) --list-stages：列出 stages
  b) --dry-run（默认）：逐 stage 构造并打印委托 modules/umi_tools/native/main.py 的命令
  c) --real：真实执行（需 umi_tools 已安装、输入文件存在、中间比对已完成）
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent.parent.parent          # 仓库根（subworkflow/<x>/native -> 上三级）
_UMI_NATIVE = _ROOT / "modules" / "umi_tools" / "native" / "main.py"
_STAGES = ["umi_extract", "umi_dedup"]


def _native(sub: list[str], threads: int) -> list[str]:
    """构造 modules/umi_tools/native/main.py 的委托命令。"""
    if not _UMI_NATIVE.exists():
        return ["<MISSING>", str(_UMI_NATIVE)] + sub
    return [sys.executable, str(_UMI_NATIVE)] + sub + ["--threads", str(threads)]


def stage_extract(a: argparse.Namespace) -> tuple[str, list[str]]:
    outdir = Path(a.outdir) / "extract"
    outdir.mkdir(parents=True, exist_ok=True)
    sub: list[str] = ["extract", "-I", a.reads_r1]
    if a.reads_r2:
        out1 = outdir / f"{a.sample_id}_R1.umi.fastq.gz"
        out2 = outdir / f"{a.sample_id}_R2.umi.fastq.gz"
        sub += ["-o", str(out1), "--read2-in", a.reads_r2, "--read2-out", str(out2)]
    else:
        sub += ["-o", str(outdir / f"{a.sample_id}.umi.fastq.gz")]
    sub += ["--bc-pattern", a.bc_pattern]
    if a.bc_pattern2:
        sub += ["--bc-pattern2", a.bc_pattern2]
    if a.extract_method:
        sub += ["--extract-method", a.extract_method]
    if a.three_prime:
        sub.append("--3prime")
    return ("umi_extract", _native(sub, a.threads))


def stage_dedup(a: argparse.Namespace) -> tuple[str, list[str]]:
    outdir = Path(a.outdir) / "dedup"
    outdir.mkdir(parents=True, exist_ok=True)
    sub: list[str] = ["dedup", "-I", a.aligned_bam,
                      "-o", str(outdir / f"{a.sample_id}.dedup.bam")]
    if a.dedup_method:
        sub += ["--method", a.dedup_method]
    if a.paired:
        sub.append("--paired")
    if a.stats:
        stats_dir = Path(a.outdir) / "stats"
        stats_dir.mkdir(parents=True, exist_ok=True)
        sub += ["--output-stats", str(stats_dir / a.sample_id)]
    return ("umi_dedup", _native(sub, a.threads))


def main(argv=None) -> int:
    argv = list(argv) if argv is not None else sys.argv[1:]

    if "--list-stages" in argv:
        print(json.dumps({"id": "custom_umi_tools_extract_dedup", "stages": _STAGES},
                         ensure_ascii=False, indent=2))
        return 0

    p = argparse.ArgumentParser(
        prog="umi-processing-skill",
        description="subworkflow/umi_tools_extract_dedup — UMI 阶段编排（extract -> [比对] -> dedup）",
    )
    p.add_argument("--sample-id", required=True)
    p.add_argument("--reads-r1", required=True, help="extract 输入 R1（SE/PE）")
    p.add_argument("--reads-r2", help="extract 输入 R2（PE 可选）")
    p.add_argument("--bc-pattern", required=True,
                   help="UMI 条形码模式，如 NNNNNNNN / riboseq regex "
                        "'^(?P<umi_1>.{4}).+(?P<umi_2>.{4})$'")
    p.add_argument("--bc-pattern2", help="read2 条形码模式（PE 拆 UMI 时）")
    p.add_argument("--extract-method", choices=("string", "regex"))
    p.add_argument("--3prime", dest="three_prime", action="store_true",
                   help="条形码位于 3' 端")
    p.add_argument("--aligned-bam", required=True,
                   help="dedup 输入：比对后含 UMI 的 BAM（由调用流程/比对器产出）")
    p.add_argument("--dedup-method",
                   choices=("unique", "percentile", "cluster", "adjacency", "directional"))
    p.add_argument("--paired", action="store_true", help="PE 文库（extract 双端 + dedup --paired）")
    p.add_argument("--stats", action="store_true", help="生成 dedup 统计（--output-stats）")
    p.add_argument("--outdir", default="umi_out")
    p.add_argument("--threads", type=int, default=8)
    p.add_argument("--dry-run", action="store_true", default=True, help="仅打印命令（默认）")
    p.add_argument("--real", action="store_true",
                   help="真实执行 modules/umi_tools/native/main.py")
    args = p.parse_args(argv)

    Path(args.outdir).mkdir(parents=True, exist_ok=True)
    mode = "real" if args.real else "dry-run"
    print(f"# custom_umi_tools_extract_dedup ({mode}) sample={args.sample_id}")
    for name, cmd in (stage_extract(args), stage_dedup(args)):
        print(f"[{name}]: " + " ".join(map(str, cmd)))
        if args.real and not (isinstance(cmd, list) and cmd and cmd[0] == "<MISSING>"):
            subprocess.run(cmd, check=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
