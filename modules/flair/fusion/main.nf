process FLAIR_FUSION {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/flair:3.0.0b1--pyhdfd78af_0' :
        'docker.1ms.run/brookslab/flair:3.0.0' }"

    input:
    tuple val(meta), path(reads), path(genome_chim_bam)
    path(genome)
    path(gtf)

    output:
    tuple val(meta), path("${prefix}*"), emit: output
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    flair fusion \\
        -g $genome \\
        -f $gtf \\
        -r $reads \\
        -b $genome_chim_bam \\
        -o ${prefix} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        flair: \$(flair --version | sed 's/flair //')
    END_VERSIONS
    """
}
