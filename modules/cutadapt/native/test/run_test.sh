#!/usr/bin/env bash
# cutadapt native 最小回归测试
# 前置：python3（必装）；cutadapt 二进制非必需——
#   未装时跳过真实子命令（仅驱动自省），装了则跑 SE/PE trim + adapter-removal。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NATIVE="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> [1/5] 驱动自省 --list-commands"
python3 "$NATIVE/main.py" --list-commands

echo "==> [2/5] 驱动自省 --schema（须为合法 JSON 且含 properties）"
python3 "$NATIVE/main.py" --schema > "$WORK/schema.json"
test -s "$WORK/schema.json"
python3 - "$WORK/schema.json" <<'PY'
import json, sys
schema = json.load(open(sys.argv[1], encoding="utf-8"))
assert "properties" in schema, "schema 缺少 properties"
print(f"schema OK: title={schema.get('title')!r}")
PY

if command -v cutadapt >/dev/null 2>&1; then
    echo "==> [3/5] 生成测试数据（合成 FASTQ）"
    python3 "$HERE/generate_data.py" "$WORK"

    echo "==> [4/5] trim: SE 去除 3' adapter"
    python3 "$NATIVE/main.py" trim -a AACCGGTT -o "$WORK/trimmed_se.fastq" \
        "$WORK/reads_R1.fastq" --threads 2 2> "$WORK/trim_se.log"
    test -s "$WORK/trimmed_se.fastq"
    # 序列行（FASTQ 第 2/4 行）不应再出现全长 3' adapter
    if awk 'NR%4==2' "$WORK/trimmed_se.fastq" | grep -q "AACCGGTT"; then
        echo "[FAIL] trimmed SE 输出仍含 3' adapter" >&2
        exit 1
    fi

    echo "==> [5/5] trim: PE（-a/-A/-p） + adapter-removal"
    python3 "$NATIVE/main.py" trim -a AACCGGTT -A AACCGGTT \
        -o "$WORK/pe_R1.fastq" -p "$WORK/pe_R2.fastq" \
        "$WORK/reads_R1.fastq" "$WORK/reads_R2.fastq" --threads 2 2> "$WORK/trim_pe.log"
    test -s "$WORK/pe_R1.fastq"
    test -s "$WORK/pe_R2.fastq"
    if awk 'NR%4==2' "$WORK/pe_R1.fastq" "$WORK/pe_R2.fastq" | grep -q "AACCGGTT"; then
        echo "[FAIL] trimmed PE 输出仍含 3' adapter" >&2
        exit 1
    fi

    python3 "$NATIVE/main.py" adapter-removal -a AACCGGTT -o "$WORK/ar.fastq" \
        "$WORK/reads_R1.fastq" --threads 2 2> "$WORK/ar.log"
    test -s "$WORK/ar.fastq"
else
    echo "==> [3-5/5] 未检测到 cutadapt 二进制，跳过真实子命令（仅驱动自省通过）"
fi

echo "ALL TESTS PASSED"
