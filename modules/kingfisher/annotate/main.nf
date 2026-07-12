process KINGFISHER_ANNOTATE {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/kingfisher:0.4.1--pyh7cba7a3_0' :
        'quay.io/biocontainers/kingfisher:0.4.1--pyh7cba7a3_0' }"

    input:
    tuple val(meta), val(run_id)

    output:
    tuple val(meta), path("*.csv"), emit: metadata
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    kingfisher annotate \\
        -r ${run_id} \\
        -f csv \\
        -o ${run_id}.csv \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kingfisher: \$(kingfisher --version | sed 's/kingfisher //')
    END_VERSIONS
    """

    stub:
    """
    touch ${run_id}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kingfisher: 0.4.1
    END_VERSIONS
    """
}
