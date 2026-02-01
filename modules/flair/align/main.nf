process FLAIR_ALIGN {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/flair:3.0.0b1--pyhdfd78af_0' :
        'docker.1ms.run/brookslab/flair:3.0.0' }"

    input:
    tuple val(meta), path(reads)
    tuple val(meta2), path(genome)

    output:
    tuple val(meta), path("${prefix}.bam")    , emit: bam
    tuple val(meta), path("${prefix}.bam.bai"), emit: bai
    tuple val(meta), path("${prefix}.bed")    , emit: bed
    tuple val("${task.process}"), val('flair'), eval("flair --version | sed 's/flair //'"), topic: versions, emit: versions_flair

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    flair align \\
        -g ${genome} \\
        -r ${reads} \\
        -t ${task.cpus} \\
        -o ${prefix} \\
        $args

    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.bam
    touch ${prefix}.bam.bai
    touch ${prefix}.bed

    """
}
