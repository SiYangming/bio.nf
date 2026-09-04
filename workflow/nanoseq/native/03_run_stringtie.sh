#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Stage 03 · StringTie 组装：逐样本 assemble → 坐标修复 → 跨样本 merge
# 输入：alignment_results_bam/sorted_bam（01 比对产物）+ gencode.v49.annotation.gtf
# 产物：stringtie_results/{assembled_gtf/fixed_gtf/*.stringtie.fixed.gtf, merged_gtf/stringtie_merged_nonredundant.gtf}（供 04 TD2 使用）
# ---------------------------------------------------------------------------

###########################################################################
# 终极防重跑版 StringTie 重构+合并脚本
###########################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "$0")"
LOCK_FILE="${SCRIPT_DIR}/.${SCRIPT_NAME}.lock"
OUTPUT_DIR="${SCRIPT_DIR}/stringtie_results"
PID_FILE="${OUTPUT_DIR}/stringtie_pid.pid"
MASTER_LOG="${OUTPUT_DIR}/stringtie_master.log"

acquire_lock() {
    if ! mkdir "${LOCK_FILE}" 2>/dev/null; then
        echo "错误：另一个 $SCRIPT_NAME 正在运行！"
        [ -f "$PID_FILE" ] && echo "PID: $(cat "$PID_FILE")"
        echo "使用 $0 stop 或 $0 clean 解决"
        exit 1
    fi
}

release_lock() { rm -rf "${LOCK_FILE}" 2>/dev/null || true; }
trap release_lock EXIT

show_status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "StringTie 任务运行中 → PID: $(cat "$PID_FILE")"
        echo "实时日志 → tail -f \"$MASTER_LOG\""
    else
        echo "无运行任务"
    fi
}

stop_task() {
    [ -f "$PID_FILE" ] && kill -9 "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
    release_lock
    echo "任务已停止"
}

clean_all() {
    echo "正在强制清理 stringtie_results 目录..."
    stop_task
    rm -rf "$OUTPUT_DIR"
    release_lock
    echo "清理完成！可重新运行"
}

case "${1:-}" in
    status) show_status; exit 0 ;;
    stop|kill) stop_task; exit 0 ;;
    clean) clean_all; exit 0 ;;
    "") ;; run) ;;
    *) echo "用法: $0 [status|stop|clean]"; exit 1 ;;
esac

if [ "${1:-}" != "run" ]; then
    acquire_lock
    mkdir -p "$OUTPUT_DIR"
    echo "===== StringTie 转录本重构启动（$(date)）=====" | tee "$MASTER_LOG"

    nohup "$0" run > "$MASTER_LOG" 2>&1 &
    echo $! > "$PID_FILE"
    echo "后台任务已启动！PID: $(cat "$PID_FILE")"
    echo "命令：$0 status | $0 stop | $0 clean"
    exit 0
fi

acquire_lock

STRINGTIE_PATH=${STRINGTIE_PATH:-stringtie}   # 支持 export 绝对路径；缺省从 PATH 检测（未安装会提示）
INPUT_BAM_DIR=${INPUT_BAM_DIR:-./alignment_results_bam/sorted_bam}   # 输入 sorted BAM 目录
GTF_ANNOTATION=${GTF_ANNOTATION:-./gencode.v49.annotation.gtf}       # 参考注释 GTF
GENOME_FASTA=${GENOME_FASTA:-./hg38}                                 # 保留给 04 阶段（本脚本未直接使用）
ASSEMBLED_GTF_DIR="${OUTPUT_DIR}/assembled_gtf"
FIXED_GTF_DIR="${ASSEMBLED_GTF_DIR}/fixed_gtf"
MERGED_GTF_DIR="${OUTPUT_DIR}/merged_gtf"
LOG_DIR="${OUTPUT_DIR}/logs"
THREADS=9
STRINGTIE_THREADS=20
MIN_TRANSCRIPT_LEN=200

mkdir -p "$ASSEMBLED_GTF_DIR" "$FIXED_GTF_DIR" "$MERGED_GTF_DIR" "$LOG_DIR"

check_dependency() { # $1=可执行名/路径  $2=env 变量名  $3=安装提示
    local exe="$1" var="${2:-}" hint="${3:-}"
    if command -v "$exe" &>/dev/null; then return 0; fi
    echo "[ERROR] 未找到工具: $exe" >&2
    [ -n "$var" ] && echo "  提示: export ${var}=/绝对/路径/${exe##*/}" >&2
    [ -n "$hint" ] && echo "  安装: ${hint}" >&2
    exit 1
}
check_dependency "$STRINGTIE_PATH" STRINGTIE_PATH "conda install -c conda-forge -c bioconda stringtie"
check_dependency parallel parallel "conda install -c conda-forge parallel"

# 输入守卫（缺失提示 export 绝对路径）
[ -d "$INPUT_BAM_DIR" ] || {
    echo "[ERROR] 目录不存在: $INPUT_BAM_DIR（export INPUT_BAM_DIR=/绝对/路径/sorted_bam）" >&2
    exit 1
}
[ -f "$GTF_ANNOTATION" ] || {
    echo "[ERROR] GTF 不可读: $GTF_ANNOTATION（export GTF_ANNOTATION=/绝对/路径/annotation.gtf）" >&2
    exit 1
}
BAM_FILES=("$INPUT_BAM_DIR"/*.sorted.bam)
[ ${#BAM_FILES[@]} -eq 0 ] && { echo "[ERROR] $INPUT_BAM_DIR 下未找到 *.sorted.bam 文件" >&2; exit 1; }

process_stringtie() {
    local bam="$1"
    local sample=$(basename "$bam" .sorted.bam)
    local gtf="${ASSEMBLED_GTF_DIR}/${sample}.stringtie.gtf"
    local log="${LOG_DIR}/${sample}.log"

    "$STRINGTIE_PATH" "$bam" --conservative -L -R -G "$GTF_ANNOTATION" -o "$gtf" -l "$sample" -m "$MIN_TRANSCRIPT_LEN" -p "$STRINGTIE_THREADS" >"$log" 2>&1
    echo "[$(date +%Y-%m-%d_%H:%M:%S)] $sample 完成"
}
export -f process_stringtie
export STRINGTIE_PATH GTF_ANNOTATION MIN_TRANSCRIPT_LEN STRINGTIE_THREADS ASSEMBLED_GTF_DIR LOG_DIR

printf "%s\n" "${BAM_FILES[@]}" | parallel -j "$THREADS" --progress process_stringtie {}

# 坐标修复
for gtf in "$ASSEMBLED_GTF_DIR"/*.stringtie.gtf; do
    [ -f "$gtf" ] || continue
    sample=$(basename "$gtf" .stringtie.gtf)
    fixed="${FIXED_GTF_DIR}/${sample}.stringtie.fixed.gtf"
    awk -F'\t' -v OFS='\t' '/^#/{print;next} $4>$5{t=$4;$4=$5;$5=t} {print}' "$gtf" > "$fixed"
done

# merge
gtf_list="${LOG_DIR}/gtf_list.txt"
find "$FIXED_GTF_DIR" -name "*.fixed.gtf" -size +0 > "$gtf_list"
"$STRINGTIE_PATH" --merge -G "$GTF_ANNOTATION" -o "${MERGED_GTF_DIR}/stringtie_merged_nonredundant.gtf" -l MSTRG -m "$MIN_TRANSCRIPT_LEN" "$gtf_list"

echo "[$(date +%Y-%m-%d_%H:%M:%S)] StringTie 流程全部完成！" | tee -a "$MASTER_LOG"
release_lock
