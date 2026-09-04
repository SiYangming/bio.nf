#!/usr/bin/env bash
# umi_tools native 最小回归测试
# 前置：python3 与 yaml 已可用；装有 umi_tools 时才执行真实 extract/dedup 链路，
#       装有 samtools（或 pysam）时用其把 reads.sam 转 BAM 供 dedup。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> [1/5] 生成测试数据（带 UMI 的合成 FASTQ + mapped SAM）"
python3 "$HERE/generate_data.py" "$WORK"
# 产物：$WORK/reads.fastq  $WORK/reads.sam

echo "==> [2/5] 驱动自省：--list-commands"
python3 "$NATIVE/main.py" --list-commands

echo "==> [3/5] 驱动自省：--schema（JSON Schema 非空且含 input 字段）"
python3 "$NATIVE/main.py" --schema > "$WORK/schema.json"
python3 - "$WORK/schema.json" <<'PY'
import json
import sys

schema = json.load(open(sys.argv[1]))
assert schema["title"] == "umi_tools", schema["title"]
assert "input" in schema["properties"], list(schema["properties"])
assert "subcommand" in schema["required"], schema["required"]
PY

if command -v umi_tools >/dev/null 2>&1; then
    echo "==> [4/5] extract 真实链路（--bc-pattern NNNNNN 提取 5' 端 UMI）"
    python3 "$NATIVE/main.py" extract \
        -I "$WORK/reads.fastq" \
        -o "$WORK/reads.umi.fastq" \
        --bc-pattern "NNNNNN" \
        --extract-method string \
        --tmpdir "$WORK"
    test -s "$WORK/reads.umi.fastq"
    # read1 序列 5' 端为 AAAAAA -> extract 后 read name 追加 _AAAAAA
    grep -q "^@read1_AAAAAA$" "$WORK/reads.umi.fastq"

    echo "==> [5/5] dedup 真实链路（6 条 reads / 4 个 UMI 组 -> 去重后 4 条）"
    if command -v samtools >/dev/null 2>&1; then
        samtools view -bS "$WORK/reads.sam" -o "$WORK/reads.bam"
    else
        # umi_tools 环境必有 pysam，作为无 samtools 时的 BAM 转换兜底
        python3 - "$WORK/reads.sam" "$WORK/reads.bam" <<'PY'
import sys

import pysam

sam_path, bam_path = sys.argv[1], sys.argv[2]
with pysam.AlignmentFile(sam_path, "r") as fin, \
        pysam.AlignmentFile(bam_path, "wb", template=fin) as fout:
    for read in fin:
        fout.write(read)
PY
    fi
    python3 "$NATIVE/main.py" dedup \
        -I "$WORK/reads.bam" \
        -o "$WORK/dedup.bam" \
        --method unique \
        --tmpdir "$WORK"
    n_in=$(samtools view -c "$WORK/reads.bam")
    n_out=$(samtools view -c "$WORK/dedup.bam")
    echo "dedup: $n_in reads -> $n_out reads"
    test "$n_in" -eq 6
    test "$n_out" -eq 4
else
    echo "==> [4/5, 5/5] 未检测到 umi_tools，跳过真实 extract/dedup 链路（仅通过自省测试）"
fi

echo "ALL TESTS PASSED"
