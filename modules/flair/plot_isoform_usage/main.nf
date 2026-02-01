process FLAIR_PLOTISOFORMUSAGE {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/flair:3.0.0b1--pyhdfd78af_0' :
        'docker.1ms.run/brookslab/flair:3.0.0' }"

    input:
    tuple val(meta), path(bed), path(counts_matrix)
    val gene_name

    output:
    tuple val(meta), path("*.png"), emit: png, optional: true
    tuple val(meta), path("*.pdf"), emit: pdf, optional: true
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    plot_isoform_usage \\
        $bed \\
        $counts_matrix \\
        $gene_name \\
        -o ${prefix} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        flair: \$(flair --version | sed 's/flair //')
    END_VERSIONS
    """
}
