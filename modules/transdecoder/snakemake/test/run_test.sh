#!/usr/bin/env bash
# transdecoder snakemake 集成最小回归测试（静态 + 可选 dry-run；td2 式）
#
# 运行：bash modules/transdecoder/snakemake/test/run_test.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMK_DIR="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> [1/6] 生成测试数据（占位 FASTA）"
python "$HERE/generate_data.py" "$WORK"
test -s "$WORK/transcripts.fa"

echo "==> [2/6] 拆分产物与共用环境存在"
for f in transdecoder_longorfs.smk transdecoder_predict.smk \
         transdecoder_longorfs.py transdecoder_predict.py transdecoder.yaml; do
    test -f "$SMK_DIR/$f" || { echo "[FAIL] 缺少 $f"; exit 1; }
done
test ! -e "$SMK_DIR/transdecoder.smk" || { echo "[FAIL] transdecoder.smk 应已删除"; exit 1; }
echo "  OK: 5 个集成文件在位，旧 transdecoder.smk 已移除"

echo "==> [3/6] .smk 规则与引用（conda/script 同目录，不得指向 ../envs ../scripts）"
grep -q '^rule transdecoder_longorfs:' "$SMK_DIR/transdecoder_longorfs.smk"
grep -q '^rule transdecoder_predict:' "$SMK_DIR/transdecoder_predict.smk"
grep -q 'conda: "transdecoder.yaml"' "$SMK_DIR/transdecoder_longorfs.smk"
grep -q 'conda: "transdecoder.yaml"' "$SMK_DIR/transdecoder_predict.smk"
for f in "$SMK_DIR"/transdecoder_*.smk; do
    grep -q '\.\./' "$f" && { echo "[FAIL] $f 含 ../ 引用"; exit 1; }
done
echo "  OK: 两规则均 conda=transdecoder.yaml 且无 ../ 失效引用"

echo "==> [4/6] wrapper 编译与 docker_wrapper 注入"
python3 -m py_compile "$SMK_DIR/transdecoder_longorfs.py" "$SMK_DIR/transdecoder_predict.py"
python3 - <<PY
import sys
from pathlib import Path
smk = Path("$SMK_DIR")
for f in ("transdecoder_longorfs.py", "transdecoder_predict.py"):
    src = (smk / f).read_text(encoding="utf-8")
    assert '"..", ".."' in src, f"{f}: 缺少到 modules/ 的 sys.path 注入"
modules = smk.parent.parent
sys.path.insert(0, str(modules))
import docker_wrapper
assert callable(docker_wrapper.docker_wrapper_binary)
print("  OK: wrapper py_compile 通过且注入 modules/（docker_wrapper 可导入）")
PY

echo "==> [5/6] config 契约一致性（smk setdefault 键 vs wrapper 使用键）"
python3 - <<PY
import re
from pathlib import Path
smk_dir = Path("$SMK_DIR")
def keys(p: Path):
    txt = p.read_text(encoding="utf-8")
    return set(re.findall(r'config\.setdefault\("([A-Za-z0-9_]+)"', txt)) | \
           set(re.findall(r'_td\.setdefault\("([A-Za-z0-9_]+)"', txt))
def used(p: Path):
    txt = p.read_text(encoding="utf-8")
    return set(re.findall(r'params\["([A-Za-z0-9_]+)"\]', txt))
lo_k = keys(smk_dir / "transdecoder_longorfs.smk"); lo_u = used(smk_dir / "transdecoder_longorfs.py")
pr_k = keys(smk_dir / "transdecoder_predict.smk"); pr_u = used(smk_dir / "transdecoder_predict.py")
assert "longorfs_bin" in lo_k and "gene_trans_map" in lo_u and "extra" in lo_u
assert "predict_bin" in pr_k and "retain_pfam_hits" in pr_u and "retain_blastp_hits" in pr_u
common = {"transdecoder_input_fasta", "transdecoder_outdir", "exec_mode", "threads"}
assert common <= (lo_k & pr_k), (lo_k, pr_k)
print("  OK: config 契约键（transdecoder_input_fasta/transdecoder_outdir/exec_mode/threads/transdecoder.*）一致")
PY

echo "==> [6/6] snakemake dry-run（若已安装）"
if command -v snakemake >/dev/null 2>&1; then
    (cd "$SMK_DIR" && snakemake -s transdecoder_longorfs.smk \
        --config transdecoder_input_fasta="$WORK/transcripts.fa" transdecoder_outdir="$WORK/out" \
        -c 1 -n >/dev/null)
    echo "  OK: transdecoder_longorfs.smk dryrun 通过"
else
    echo "  snakemake 未安装，跳过真实 dryrun（静态自检已通过）"
fi

echo "ALL TESTS PASSED"
