include { samplesheetToList } from 'plugin/nf-schema'

workflow  {

    watchdir = file(params.watchdir)
    if (!watchdir.exists()) {
        // Create the watchdir if it doesn't exist (this is a failsafe)
        watchdir.mkdir()
    }

    // A list containing all expected files to be watched for
    def expected_files = []

    // Determine which files to watch for
    def samplesheet = samplesheetToList("samplesheet.csv", "schema_input.json")
        .collect { meta, cram, crai ->
            if (cram == "watch") {
                expected_files.add("${meta.sample}.cram" as String)
            }
            else {
                cram = file(cram, checkIfExists:true)
            }
            if (crai == "watch") {
                expected_files.add("${meta.sample}.cram.crai" as String)
            }
            else {
                crai = file(crai, checkIfExists:true)
            }
            return [ meta, cram, crai ]
        }

    // Clone the list to filter on later
    def watch_files = expected_files.clone()

    // Watch the preprocessing outdir for cram and crai files
    Channel.watchPath("${params.watchdir}/*/*.{cram,crai}", "create,modify")
        .until { file ->
            // Stop when all files have been found
            def file_name = file.name
            if (expected_files.contains(file_name)) {
                expected_files.removeElement(file_name)
                return false
            }
            return expected_files.size() == 0
        }
        .filter { file ->
            // Filter out additional files that were not expected
            return watch_files.contains(file.name)
        }
        .map { file ->
            [file.baseName.replace(".cram", ""), file]
        }
        .groupTuple(size:2) // Group cram and crai files
        .map { id, files ->
            def cram
            def crai
            files.each { it ->
                if (it.name.endsWith(".cram")) { cram = it }
                else { crai = it }
            }
            [ id, cram, crai ]
        }
        .set { ch_watch }

    def ready = false

    Channel.fromList(samplesheet)
        .map { meta, cram, crai ->
            if (!ready) {
                log.info("Pipeline ready! You can start the simulation script: `bash simulate_outdir.sh`")
                ready = true
            }
            // do some channel manipulation here
            [ meta, cram, crai ]
        }
        .tap { ch_samplesheet_all }

    ch_samplesheet_all
        .filter { meta, cram, crai ->
            // Only get watch lines from the samplesheet
            return cram == "watch" || crai == "watch"
        }
        .map { meta, cram, crai ->
            // Return everything except for the cram and crai here
            return [ meta.id, meta ]
        }
        .join(ch_watch, failOnMismatch:true, failOnDuplicate:true) // Merge with the watched files
        .map { id, meta, cram, crai ->
            [ meta, cram, crai ]
        }
        .set { ch_watch_meta }

    ch_samplesheet_all
        .filter { meta, cram, crai ->
            // Only get the non-watch lines from the samplesheet
            return cram != "watch" && crai != "watch"
        }
        .mix(ch_watch_meta) // Mix the watch channel into the samplesheet channel
        .set { ch_samplesheet }

    ch_samplesheet.view()

}
