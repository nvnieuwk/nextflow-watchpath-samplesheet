include { WATCHPATH_HANDLING } from './subworkflows/watchpath_handling'

workflow  {

    WATCHPATH_HANDLING(
        params.input,
        params.watchdir,
        "assets/schema_input.json"
    )

    WATCHPATH_HANDLING.out.samplesheet.view()

}