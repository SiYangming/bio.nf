process FLAIR_QUANTIFY {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/flair:3.0.0b1--pyhdfd78af_0' :
        'docker.1ms.run/brookslab/flair:3.0.0' }"

    input:
    tuple val(meta), path(manifest), path(reads)
    tuple val(meta2), path(isoforms)
    path isoform_bed

    output:
    tuple val(meta), path("${prefix}.counts.tsv")       , emit: counts
    tuple val(meta), path("${prefix}.tpm.tsv")          , emit: tpm, optional: true
    tuple val(meta), path("${prefix}/*.bam")            , emit: bam, optional: true
    tuple val(meta), path("${prefix}*.map.txt")         , emit: map, optional: true
    tuple val("${task.process}"), val('flair'), eval("flair --version | sed 's/flair //'"), topic: versions, emit: versions_flair

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def isoform_bed_args = isoform_bed ? "--isoform_bed ${isoform_bed}" : ''
    
    """
    flair quantify \\
        -r ${manifest} \\
        -i ${isoforms} \\
        -t ${task.cpus} \\
        -o ${prefix} \\
        $isoform_bed_args \\
        $args

    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}
    touch ${prefix}.counts.tsv
    touch ${prefix}.tpm.tsv
    touch ${prefix}/sample.bam
    """
}
