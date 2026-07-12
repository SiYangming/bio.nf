process CRESIL_VISUALIZE {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/cresil:1.2.0--hdfd78af_0' :
        'quay.io/bioinfortools/cresil:1.2.1' }"

    input:
    tuple val(meta), path(identify_table)
    tuple val(meta2), path(gene_annot)
    tuple val(meta3), path(cpg_annot)
    tuple val(meta4), path(repeat_annot)
    tuple val(meta5), path(variant_annot)
    val(eccdna_id)

    output:
    tuple val(meta), path("${prefix}_for_Circos"), emit: circos_config
    tuple val("${task.process}"), val('cresil'), eval("cresil --version | sed 's/cresil //'"), topic: versions, emit: versions_cresil

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p cresil_gAnnotation
    cp ${gene_annot} cresil_gAnnotation/gene.annotate.txt
    cp ${cpg_annot} cresil_gAnnotation/CpG.annotate.txt
    cp ${repeat_annot} cresil_gAnnotation/repeat.annotate.txt
    cp ${variant_annot} cresil_gAnnotation/variant.annotate.txt

    cresil visualize \\
        -t ${task.cpus} \\
        -identify ${identify_table} \\
        -c ${eccdna_id} \\
        $args

    mv for_Circos ${prefix}_for_Circos
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}_for_Circos
    touch ${prefix}_for_Circos/circos.conf
    """
}
