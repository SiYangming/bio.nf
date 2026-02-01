process FLAIR_CORRECT {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/flair:3.0.0b1--pyhdfd78af_0' :
        'docker.1ms.run/brookslab/flair:3.0.0' }"

    input:
    tuple val(meta) , path(bed)
    tuple val(meta3), path(gtf)

    output:
    tuple val(meta), path("${prefix}_all_corrected.bed")       , emit: bed
    tuple val(meta), path("${prefix}_all_inconsistent.bed")    , emit: inconsistent, optional: true
    tuple val("${task.process}"), val('flair'), eval("flair --version | sed 's/flair //'"), topic: versions, emit: versions_flair

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def gtf_arg = gtf ? "-f ${gtf}" : ""
    
    """
    flair correct \\
        -q ${bed} \\
        ${gtf_arg} \\
        -t ${task.cpus} \\
        -o ${prefix} \\
        $args

    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_all_corrected.bed
    touch ${prefix}_all_inconsistent.bed

    """
}
