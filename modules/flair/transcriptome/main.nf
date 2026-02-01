process FLAIR_TRANSCRIPTOME {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/flair:3.0.0b1--pyhdfd78af_0' :
        'docker.1ms.run/brookslab/flair:3.0.0' }"

    input:
    tuple val(meta), path(bam), path(bai)
    tuple val(meta2), path(genome)
    tuple val(meta3), path(gtf)

    output:
    tuple val(meta), path("${prefix}.isoforms.bed")         , emit: isoforms_bed
    tuple val(meta), path("${prefix}.isoforms.gtf")         , emit: isoforms_gtf
    tuple val(meta), path("${prefix}.isoforms.fa")          , emit: isoforms_fa
    tuple val("${task.process}"), val('flair'), eval("flair --version | sed 's/flair //'"), topic: versions, emit: versions_flair

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def gtf_arg = gtf ? "-f ${gtf}" : ""
    
    """
    flair transcriptome \\
        -b ${bam} \\
        -g ${genome} \\
        ${gtf_arg} \\
        -t ${task.cpus} \\
        -o ${prefix} \\
        $args

    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.isoforms.bed
    touch ${prefix}.isoforms.gtf
    touch ${prefix}.isoforms.fa

    """
}
