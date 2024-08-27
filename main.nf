include { samplesheetToList } from 'plugin/nf-schema'

workflow  {

    watchdir = params.watchdir

    // A map with entries for every row that expects to be watched
    def watch_lines = [:]

    // Initialize a filename for the DONE file
    def watch_id = UUID.randomUUID().toString()
    def done_file = file("${params.watchdir}/DONE-${watch_id}")

    // A list containing all expected files
    def expected_files = [done_file.name]

    // Initialize ch_samplesheet to keep the linter happy
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
            return row
        }

    Channel.fromList(samplesheet).set { ch_samplesheet_all }

    if (watchdir) {

        watchdir_path = file(params.watchdir)
        if (!watchdir_path.exists()) {
            // Create the watchdir if it doesn't exist (this is a failsafe)
            watchdir_path.mkdir()
        }

        // Watch the watchdir for the expected files
        Channel.watchPath("${watchdir}**{${expected_files.join(',')}}", "create,modify")
            .until { file ->
                def file_name = file.name
                if (file_name == done_file.name) {
                    // Delete the done file when it's been detected and stop watching
                    done_file.delete()
                    return true
                }
                return false
            }
            .map { file ->
                // Try to find a matching ID in watch_lines
                def id = find_id(file.name, watch_lines)
                if (id == "") {
                    error("Could not find id for file '${file.name}' in the samplesheet.")
                }
                // Replace the matching watch entry with the file
                watch_lines[id] = watch_lines[id].collect { line_entry ->
                    line_entry == "watch:${file.name}" as String ? file : line_entry
                }
                return watch_lines[id]
            }
            .filter { entry ->
                def found_all_files = false
                if (!entry.any { elem -> elem.toString().startsWith("watch:") }) {
                    // Remove the entry from watch_files when all files for the current entry have been found
                    watch_lines.remove(entry[0].id)
                    found_all_files = true
                }
                if (watch_lines.size() == 0) {
                    // Create the DONE file when all files have been found
                    done_file.text = ""
                }
                // Pass through all entries where all files have been found
                return found_all_files
            }
            // Mix with all entries that didn't contain any watched files
            .mix(ch_samplesheet_all.filter { entry -> !entry.any { elem -> elem.toString().startsWith("watch:") }})
            .set { ch_samplesheet }

    } else {
        ch_samplesheet = ch_samplesheet_all
    }

    ch_samplesheet.view()

}

// Find the ID of a file in a map with sample IDs as keys
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
