#!/bin/bash

SRA_DIR="/data2/users/liuqi/eccdna/Arabidopsis_thaliana"
OUT_DIR="/data1/users/siyangming/eccDNA"

mkdir -p "${OUT_DIR}"

for sra_dir in "${SRA_DIR}"/*/; do
    sra_id=$(basename "${sra_dir}")
    sra_file="${sra_dir}${sra_id}.sra"
    
    if [ ! -f "${sra_file}" ]; then
        echo "Skipping ${sra_id}: SRA file not found"
        continue
    fi
    
    echo "Processing ${sra_id}..."
    mkdir -p "${OUT_DIR}/${sra_id}"
    
    fasterq-dump \
        --threads 8 \
        --outfile "${OUT_DIR}/${sra_id}/${sra_id}" \
        "${sra_file}"
    
    if [ -f "${OUT_DIR}/${sra_id}/${sra_id}_1.fastq" ]; then
        pigz --processes 8 "${OUT_DIR}/${sra_id}/${sra_id}_1.fastq"
    fi
    if [ -f "${OUT_DIR}/${sra_id}/${sra_id}_2.fastq" ]; then
        pigz --processes 8 "${OUT_DIR}/${sra_id}/${sra_id}_2.fastq"
    fi
    
    echo "Completed ${sra_id}"
done

echo "All SRA files converted!"