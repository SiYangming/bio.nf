process CRESIL_TRIM {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/cresil:1.2.0--hdfd78af_0' :
        'quay.io/bioinfortools/cresil:1.2.1' }"

    input:
    tuple val(meta), path(reads)
    tuple val(meta2), path(mmi)

    output:
    tuple val(meta), path("${prefix}.trim.txt"), emit: trim
    tuple val("${task.process}"), val('cresil'), eval("cresil --version | sed 's/cresil //'"), topic: versions, emit: versions_cresil

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    cresil trim \\
        -t ${task.cpus} \\
        -fq ${reads} \\
        -r ${mmi} \\
        -o . \\
        $args

    mv trim.txt ${prefix}.trim.txt
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.trim.txt
    """
}
