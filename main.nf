include { samplesheetToList } from 'plugin/nf-schema'

workflow  {

    watchdir = params.watchdir

    // A list containing all expected files to be watched for
    def watch_lines = [:]

    def watch_id = UUID.randomUUID().toString()
    def done_file = file("${params.watchdir}/DONE-${watch_id}")
    def expected_files = [done_file.name]
    ch_samplesheet = Channel.empty()

    // Determine which files to watch for
    def samplesheet = samplesheetToList("samplesheet.csv", "schema_input.json")
        // Do some calculations and manipulations here
        .collect { row ->
            def is_watch = false
            row = row.collect { input ->
                input_name = input instanceof Path ? input.name : input as String
                if (input_name.startsWith("watch:")) {
                    is_watch = true
                    expected_files.add(input_name.replace("watch:", ""))
                    return input_name
                }
                return input
            }
            if (is_watch) {
                watch_lines[row[0].id] = row
            }
            def new_meta = row[0] + [is_watch:is_watch]
            return row
        }

    def ready = false
    Channel.fromList(samplesheet)
        .map { row ->
            if (!ready) {
                log.info("Pipeline ready! You can start the simulation script: `bash simulate_outdir.sh`")
                ready = true
            }
            // do some channel manipulation here
            return row
        }
        .tap { ch_samplesheet_all }

    if (watchdir) {

        watchdir_path = file(params.watchdir)
        if (!watchdir_path.exists()) {
            // Create the watchdir if it doesn't exist (this is a failsafe)
            watchdir_path.mkdir()
        }

        // Watch the preprocessing outdir for cram and crai files
        Channel.watchPath("${watchdir}**{${expected_files.join(',')}}", "create,modify")
            .until { file ->
                // Stop when all files have been found
                def file_name = file.name
                if (expected_files.contains(file_name)) {
                    expected_files.removeElement(file_name)
                } 
                if (file_name == done_file.name) {
                    done_file.delete()
                }
                return file_name == done_file.name
            }
            .map { file ->
                def id = find_id(file.name, watch_lines)
                if (id == "") {
                    error("Could not find id for file '${file.name}' in the samplesheet.")
                }
                watch_lines[id] = watch_lines[id].collect { line_entry ->
                    line_entry == "watch:${file.name}" as String ? file : line_entry
                }
                return watch_lines[id]
            }
            .filter { entry ->
                def found_all_files = false
                if (!entry.any { elem -> elem.toString().startsWith("watch:") }) {
                    watch_lines.remove(entry[0].id)
                    found_all_files = true
                }
                if (watch_lines.size() == 0) {
                    done_file.text = ""
                }
                return found_all_files
            }
            .mix(ch_samplesheet_all.filter { entry -> !entry.any { elem -> elem.toString().startsWith("watch:") }})
            .set { ch_samplesheet }

    } else {
        ch_samplesheet = ch_samplesheet_all
    }

    ch_samplesheet.view()

}

def find_id(file_name, file_map) {
    def lastDotIndex = file_name.lastIndexOf(".")
    if (lastDotIndex == -1) {
        return ""
    }
    def id = file_name.substring(0, lastDotIndex)
    if (file_map.containsKey(id)) {
        return id
    }
    return find_id(id, file_map)
}
