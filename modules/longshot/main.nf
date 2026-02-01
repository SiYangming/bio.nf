process LONGSHOT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/longshot:1.0.0--h8dc4d9d_3' :
        'quay.io/biocontainers/longshot:1.0.0--h8dc4d9d_3' }"

    input:
    tuple val(meta), path(bam), path(bai)
    tuple val(meta2), path(fasta), path(fai)
    val region

    output:
    tuple val(meta), path("*.vcf"), emit: vcf
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def region_arg = region ? "--region ${region}" : ""
    """
    longshot \\
        --bam $bam \\
        --ref $fasta \\
        --out ${prefix}.vcf \\
        $region_arg \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        longshot: \$(longshot --version 2>&1 | sed 's/^.*longshot //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        longshot: \$(longshot --version 2>&1 | sed 's/^.*longshot //')
    END_VERSIONS
    """
}
