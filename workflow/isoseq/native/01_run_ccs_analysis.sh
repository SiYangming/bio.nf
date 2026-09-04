#!/usr/bin/env bash
set -euo pipefail

# Stage 01 · CCS（pbccs：subreads -> HiFi，对应 01PBCCS）

# ---- 路径自锚定：以脚本位置解析仓库根与包装器（保证任意机器/工作目录可运行）----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CCS_ANALYSIS=${CCS_ANALYSIS:-"${REPO_ROOT}/modules/pbccs/native/ccs_analysis.py"}   # pbccs 包装器（可环境变量覆盖）

# 可选：激活运行环境
# conda activate pacbio_iso_seq

# 配置参数（可通过环境变量覆盖）
DATA_DIR=${DATA_DIR:-""}                # 必填：指向包含样本子目录的路径（每样本内含 *.subreads.bam）
OUT_BASE=${OUT_BASE:-"ccs_output"}      # 输出根目录（默认当前目录下 ccs_output）
CHUNK_TOTAL=${CHUNK_TOTAL:-40}          # 若不分块，将其设为 1
CPUS_PER_TASK=${CPUS_PER_TASK:-8}       # 每个 ccs 任务使用的线程数
PARA_CPU=${PARA_CPU:-28}                # 并发任务数（总并发 = PARA_CPU * CPUS_PER_TASK 近似）
CMD_FILE=${CMD_FILE:-"${OUT_BASE}/ccs_commands.txt"}
CCS_BIN=${CCS_BIN:-""}                  # 可选：ccs 可执行文件路径（留空则从 PATH 解析）

if [[ -z "$DATA_DIR" || ! -d "$DATA_DIR" ]]; then
  echo "[ERROR] 未设置或不存在 DATA_DIR。请导出含样本子目录的路径：export DATA_DIR=/path/to/subreads" >&2
  exit 1
fi

mkdir -p "$OUT_BASE"
> "$CMD_FILE"

echo "生成命令列表到: $CMD_FILE"
found=0
for bam in "$DATA_DIR"/*/*.subreads.bam; do
  [[ -e "$bam" ]] || continue
  found=1
  sample_dir=$(basename "$(dirname "$bam")")
  for i in $(seq 1 "$CHUNK_TOTAL"); do
    cmd_line="python3 \"${CCS_ANALYSIS}\" --subreads \"$bam\" --outdir \"$OUT_BASE/$sample_dir\" --chunk-num \"$i\" --chunk-total \"$CHUNK_TOTAL\" --cpus \"$CPUS_PER_TASK\""
    if [[ -n "$CCS_BIN" ]]; then
      cmd_line+=" --ccs-bin \"$CCS_BIN\""
    fi
    echo "$cmd_line" >> "$CMD_FILE"
  done
done
if [[ "$found" -eq 0 ]]; then
  echo "[ERROR] $DATA_DIR 下未找到 */*.subreads.bam（样本须按子目录组织）" >&2
  exit 1
fi

echo "命令数量: $(wc -l < "$CMD_FILE")"

# 优先使用 ParaFly，其次 GNU parallel，最后 xargs 作为降级方案
if command -v ParaFly >/dev/null 2>&1; then
  echo "使用 ParaFly 并发执行, CPU=$PARA_CPU"
  ParaFly -c "$CMD_FILE" -CPU "$PARA_CPU"
elif command -v parallel >/dev/null 2>&1; then
  echo "使用 GNU parallel 并发执行, -j=$PARA_CPU"
  parallel -j "$PARA_CPU" --delay 0.2 --bar < "$CMD_FILE"
else
  echo "使用 xargs 并发执行, -P=$PARA_CPU (如遇到复杂引号问题，建议安装 ParaFly 或 parallel)"
  xargs -I CMD -P "$PARA_CPU" bash -c 'CMD' < "$CMD_FILE"
fi

echo "全部任务提交完成，CCS分析完成"
