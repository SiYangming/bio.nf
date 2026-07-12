include { CRESIL_VISUALIZE } from './main.nf'

workflow {
    CRESIL_VISUALIZE(
        channel.of([ ['id':'test'], file(params.identify) ]),
        params.eccdna_id
    )
    CRESIL_VISUALIZE.out.circos_config.view()
}
