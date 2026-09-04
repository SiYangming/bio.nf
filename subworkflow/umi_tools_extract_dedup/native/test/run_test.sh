#!/usr/bin/env bash
# umi_tools_extract_dedup 编排最小回归测试（--list-stages / dry-run 形态断言，不真实执行 umi_tools）
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN="$HERE/../main.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> [1/5] 语法检查与 --list-stages"
python3 -m py_compile "$MAIN"
OUT=$(python3 "$MAIN" --list-stages)
echo "$OUT" | grep -q "umi_extract" || { echo "[FAIL] stages 缺 umi_extract"; exit 1; }
echo "$OUT" | grep -q "umi_dedup" || { echo "[FAIL] stages 缺 umi_dedup"; exit 1; }
echo "  OK"

echo "==> [2/5] 依赖文件在位"
for f in "$MAIN" "$HERE/generate_data.py" "$HERE/../test/run_test.sh" \
         "$HERE/../../umi_tools_extract_dedup.md" "$HERE/../../meta.yaml" \
         "$HERE/../../snakemake/umi_tools_extract_dedup.smk"; do
    test -f "$f" || { echo "[FAIL] 缺少 $f"; exit 1; }
done
test -f "$HERE/../../../../modules/umi_tools/native/main.py" || { echo "[FAIL] 缺 modules/umi_tools/native/main.py"; exit 1; }
echo "  OK"

echo "==> [3/5] dry-run（SE）委托命令断言"
python "$HERE/generate_data.py" "$WORK" >/dev/null
OUT=$(python3 "$MAIN" --sample-id s1 \
    --reads-r1 "$WORK/s1_R1.fastq.gz" \
    --bc-pattern NNNNNNNN \
    --aligned-bam "$WORK/s1.aligned.bam" \
    --stats --outdir "$WORK/out")
echo "$OUT" | grep -q "umi_tools/native/main.py extract" || { echo "[FAIL] 缺 extract 委托"; exit 1; }
echo "$OUT" | grep -q -- "--bc-pattern NNNNNNNN" || { echo "[FAIL] 缺 bc-pattern"; exit 1; }
echo "$OUT" | grep -q "umi_tools/native/main.py dedup" || { echo "[FAIL] 缺 dedup 委托"; exit 1; }
echo "$OUT" | grep -q -- "--output-stats" || { echo "[FAIL] 缺 --output-stats(--stats)"; exit 1; }
echo "$OUT" | grep -q "umi_out" || true
echo "  OK"

echo "==> [4/5] dry-run（PE + regex + --paired）断言"
OUT=$(python3 "$MAIN" --sample-id s1 \
    --reads-r1 "$WORK/s1_R1.fastq.gz" --reads-r2 "$WORK/s1_R2.fastq.gz" --paired \
    --bc-pattern '^(?P<umi_1>.{4}).+(?P<umi_2>.{4})$' --extract-method regex \
    --aligned-bam "$WORK/s1.aligned.bam" --outdir "$WORK/out")
echo "$OUT" | grep -q -- "--read2-in" || { echo "[FAIL] PE 缺 --read2-in"; exit 1; }
echo "$OUT" | grep -q -- "--read2-out" || { echo "[FAIL] PE 缺 --read2-out"; exit 1; }
echo "$OUT" | grep -q -- "--extract-method regex" || { echo "[FAIL] 缺 --extract-method regex"; exit 1; }
echo "$OUT" | grep -q -- "--paired" || { echo "[FAIL] dedup 缺 --paired"; exit 1; }
echo "  OK"

echo "==> [5/5] meta.yaml YAML 解析"
python3 -c "import yaml,sys; yaml.safe_load(open('$HERE/../../meta.yaml')); print('  OK: meta.yaml 解析通过')"

echo "ALL TESTS PASSED"
