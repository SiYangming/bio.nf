process FLAIR_DIFFSPLICE {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/flair:3.0.0b1--pyhdfd78af_0' :
        'docker.1ms.run/brookslab/flair:3.0.0' }"

    input:
    tuple val(meta), path(counts)
    tuple val(meta2), path(isoforms)

    output:
    tuple val(meta), path("${prefix}/*drimseq*.tsv")         , emit: drimseq_results, optional: true
    tuple val(meta), path("${prefix}/*events.quant.tsv")     , emit: quant_results, optional: true
    tuple val(meta), path("${prefix}/*drimseq*.pdf")         , emit: drimseq_plots, optional: true
    tuple val("${task.process}"), val('flair'), eval("flair --version | sed 's/flair //'"), topic: versions, emit: versions_flair

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def isoforms_arg = isoforms ? "-i ${isoforms}" : ""
    
    """
    flair diffSplice \\
        -q ${counts} \\
        ${isoforms_arg} \\
        -o ${prefix} \\
        -t ${task.cpus} \\
        $args

    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}
    touch ${prefix}/drimseq_results.tsv
    touch ${prefix}/diffsplice.events.quant.tsv
    touch ${prefix}/isoforms_drimseq.pdf

    """
}
