# File-based Datastore

This ETL library and tool requires intermediary storage when transforming data from different sources. This allows the tool to break the ETL into different steps that can be scheduled separately.

The first datastore is a flat-file database of JSON files on disk. This can be used by specifying `file://` for the `--database_url` option in the command line interface, like so:

```
$ transload get metadata \
    --provider environment_canada \
    --station_id CXCM \
    --database_url file:///Volumes/ramdisk/datastore/weather
```

Or when using a relative file path:

```
$ transload get metadata \
    --provider environment_canada \
    --station_id CXCM \
    --database_url file://./datastore/weather
```

**Note:** The file-based datastore **is not** thread-safe. If you run multiple ETL processes at the same time *for the same station*, then it is possible they may try to write to the same file at the same time and cause undefined behaviour.

When using a scheduler for the Data Transloader, make sure not to allow concurrent executions of a job that has a unique station.
