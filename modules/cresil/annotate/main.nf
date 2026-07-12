process CRESIL_ANNOTATE {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/cresil:1.2.0--hdfd78af_0' :
        'quay.io/bioinfortools/cresil:1.2.1' }"

    input:
    tuple val(meta), path(identify_table)
    tuple val(meta2), path(rmsk_bed)
    tuple val(meta3), path(cpg_bed)
    tuple val(meta4), path(gene_bed)

    output:
    tuple val(meta), path("*_gene.annotate.txt"), emit: gene_annot
    tuple val(meta), path("*_CpG.annotate.txt"), emit: cpg_annot
    tuple val(meta), path("*_repeat.annotate.txt"), emit: repeat_annot
    tuple val(meta), path("*_variant.annotate.txt"), emit: variant_annot
    tuple val("${task.process}"), val('cresil'), eval("cresil --version | sed 's/cresil //'"), topic: versions, emit: versions_cresil

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def rmsk_arg = rmsk_bed && rmsk_bed.exists() ? "-rp ${rmsk_bed}" : ''
    def cpg_arg = cpg_bed && cpg_bed.exists() ? "-cg ${cpg_bed}" : ''
    def gene_arg = gene_bed && gene_bed.exists() ? "-gb ${gene_bed}" : ''

    """
    cresil annotate \\
        -t ${task.cpus} \\
        -identify ${identify_table} \\
        ${rmsk_arg} \\
        ${cpg_arg} \\
        ${gene_arg} \\
        $args

    for f in cresil_gAnnotation/*.txt; do
        basename="\$(basename "\$f")"
        case "\$basename" in
            *gene*) mv "\$f" "${prefix}_gene.annotate.txt" ;;
            *CpG*) mv "\$f" "${prefix}_CpG.annotate.txt" ;;
            *repeat*) mv "\$f" "${prefix}_repeat.annotate.txt" ;;
            *variant*) mv "\$f" "${prefix}_variant.annotate.txt" ;;
        esac
    done
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_gene.annotate.txt
    touch ${prefix}_CpG.annotate.txt
    touch ${prefix}_repeat.annotate.txt
    touch ${prefix}_variant.annotate.txt
    """
}
