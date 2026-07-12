process ECC_FINDER_MAP_ONT {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'quay.io/bioinfortools/ecc_finder:1.0.0' :
        'quay.io/bioinfortools/ecc_finder:1.0.0' }"

    input:
    tuple val(meta), path(idx)
    tuple val(meta2), path(query)
    tuple val(meta3), path(ref)

    output:
    tuple val(meta), path("${prefix}.csv"), emit: csv
    tuple val(meta), path("${prefix}.fasta"), emit: fasta
    tuple val("${task.process}"), val('ecc_finder'), eval("ecc_finder.py --version"), topic: versions, emit: versions_ecc_finder

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "ecc.ont"

    """
    ecc_finder.py map-ont \\
        ${idx} \\
        ${query} \\
        -r ${ref} \\
        -t ${task.cpus} \\
        -o . \\
        -x ${prefix} \\
        $args

    mv eccFinder_output/${prefix}.csv ${prefix}.csv
    mv eccFinder_output/${prefix}.fasta ${prefix}.fasta
    """

    stub:
    prefix = task.ext.prefix ?: "ecc.ont"
    """
    touch ${prefix}.csv
    touch ${prefix}.fasta
    """
}