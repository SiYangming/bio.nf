process FLAIR_DIFFEXP {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/flair:3.0.0b1--pyhdfd78af_0' :
        'docker.1ms.run/brookslab/flair:3.0.0' }"

    input:
    tuple val(meta), path(counts)

    output:
    tuple val(meta), path("${prefix}/*deseq2*.tsv")          , emit: deseq2_results
    tuple val(meta), path("${prefix}/*deseq2*.pdf")          , emit: deseq2_plots, optional: true
    tuple val("${task.process}"), val('flair'), eval("flair --version | sed 's/flair //'"), topic: versions, emit: versions_flair

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    flair diffExp \\
        -q ${counts} \\
        -o ${prefix} \\
        -t ${task.cpus} \\
        $args

    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}
    touch ${prefix}/genes_deseq2_results.tsv
    touch ${prefix}/genes_deseq2.pdf
    touch ${prefix}/isoforms_deseq2.pdf

    """
}
