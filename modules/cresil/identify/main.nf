process CRESIL_IDENTIFY {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/cresil:1.2.0--hdfd78af_0' :
        'quay.io/bioinfortools/cresil:1.2.1' }"

    input:
    tuple val(meta), path(fasta)
    tuple val(meta2), path(fai)
    tuple val(meta3), path(reads)
    tuple val(meta4), path(trim)

    output:
    tuple val(meta), path("${prefix}.eccDNA_final.txt"), emit: identify
    tuple val("${task.process}"), val('cresil'), eval("cresil --version | sed 's/cresil //'"), topic: versions, emit: versions_cresil

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def trim_arg = trim ? "-trim ${trim}" : ''

    """
    cresil identify \\
        -t ${task.cpus} \\
        -fa ${fasta} \\
        -fai ${fai} \\
        -fq ${reads} \\
        ${trim_arg} \\
        $args

    mv cresil_result/eccDNA_final.txt ${prefix}.eccDNA_final.txt
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.eccDNA_final.txt
    """
}
