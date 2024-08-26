# WatchPath with a samplesheet

This POC repository is used to try out `.watchPath` to easily link pipelines. The `nf-schema` plugin is used in this POC but not necessary for the implementation, it just makes it a lot easier.

The samplesheet consist of three columns:
- `sample`: The name of the sample of that row
- `cram`: The path to the CRAM file, The pipeline will watch for a file called `<sample>.cram` when this value is set to `watch`
- `crai`: The path to the CRAM index file, The pipeline will watch for a file called `<sample>.cram.crai` when this value is set to `watch`

You'll need to know what files to watch for before this because all unexpected files will be skipped over. 
The watching will automatically stop when all files have been found.

## Try it yourself

Execute following command to try out this POC (Run these in separate terminals):

1. Start the nextflow pipeline:

```
nextflow run main.nf
```

2. Wait until the pipeline has fully started. Then execute the following command to simulate the populating of an output directory from another pipeline

```
bash simulate_outdir.sh
```