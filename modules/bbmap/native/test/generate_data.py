#!/usr/bin/env python3
"""生成 bbmap native 测试用的合成数据。

产出（<outdir> 下）：
  refs.fa       微型参考序列（chr1/chr2 各 500 bp，确定性随机序列）
  reads.fq      5 条 chr1 30 bp reads（唯一可比对）+ 1 条 poly-A（无法比对，
                用于验证 outu 输出非空）
"""
from __future__ import annotations

import random
import sys
from pathlib import Path

rng = random.Random(42)
SEQ1 = "".join(rng.choice("ACGT") for _ in range(500))  # chr1
SEQ2 = "".join(rng.choice("ACGT") for _ in range(500))  # chr2
STARTS = (0, 60, 120, 180, 240)          # chr1 上的 5 个 read 起点
UNMAPPED_SEQ = "A" * 30                   # poly-A，无法唯一比对到随机参考


def write_fasta(path: Path) -> None:
    seqs = {"chr1": SEQ1, "chr2": SEQ2}
    with open(path, "w") as fh:
        for name, seq in seqs.items():
            fh.write(f">{name}\n")
            for i in range(0, len(seq), 60):
                fh.write(seq[i:i + 60] + "\n")


def write_fastq(path: Path, reads: list[str]) -> None:
    with open(path, "w") as fh:
        for i, seq in enumerate(reads, start=1):
            fh.write(f"@read{i}\n{seq}\n+\n{'I' * len(seq)}\n")


def main() -> int:
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <outdir>", file=sys.stderr)
        return 2
    outdir = Path(sys.argv[1])
    outdir.mkdir(parents=True, exist_ok=True)
    write_fasta(outdir / "refs.fa")
    mapped = [SEQ1[s:s + 30] for s in STARTS]
    write_fastq(outdir / "reads.fq", mapped + [UNMAPPED_SEQ])
    print(f"已生成测试数据 -> {outdir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
