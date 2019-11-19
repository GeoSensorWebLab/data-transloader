# Editing Metadata

This tool currently stores metadata for stations in JSON files on disk. After downloading the base set of metadata for a station, you may manually edit the JSON files to fix missing data such as the longitude/latitude or time zone offset.

Alternatively, you can use the `transload` tool to edit the top-level metadata items.

Example:

```terminal
$ ruby transload set metadata \
    --provider data_garrison \
    --station_id 300234063588720 \
    --user_id 300234063581640 \
    --cache datastore/weather \
    --key latitude \
    --value 68.5948
```

Running this command will edit the metadata store for the given station, setting the value of "key", then returning the change as JSON:

```json
{
  "latitude": 68.5948
}
```

Only one key can be edited at a time, but the command can be ran multiple times to edit different keys.

**Please Note:** If the value *can* be coerced into a float by Ruby, it will be. This is done so that the values sent to SensorThings API will be floats instead of strings, if applicable.

If the metadata file for the station does not yet exist, it will be initialized with a blank set of metadata and then the given key's value will be set. This is not recommended as the next `get metadata` command will by default not overwrite the metadata with the full set of metadata that is needed to upload to SensorThings API.

## Editing Sub-Keys

The above method works for editing the first-level keys (e.g. `name`, `description`), but does not for keys within objects (e.g. `properties`). To edit sub-keys, use the `--key` option multiple times:

```
$ ruby transload set metadata \
    --provider data_garrison \
    --station_id 300234063588720 \
    --user_id 300234063581640 \
    --cache datastore/weather \
    --key properties \
    --key operation_interval \
    --value "April through September"
```

This will set the `operation_interval` key inside the `properties` object to the value `April through September`. Keys are processed in order. If a key does not exist, then it will be created. If there are multiple keys, the leading keys will become objects and the final key will have the value.
