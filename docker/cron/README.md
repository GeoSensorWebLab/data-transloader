# Arctic Sensor Web Data Transloader Cron Job

The Docker image runs `cron` as PID 1 and regularly executes the following script. Provider specific command line options should be supplied as the Docker command.

```shell
ruby transload get metadata ... ${COMMAND} # optional
ruby transload put metadata ... ${COMMAND}
ruby transload get observations ... ${COMMAND}
ruby transload put observations ... ${COMMAND}
```

Example invocation:

```sh
docker run -d -e STA_URL="..." -e SCHEDULE="@hourly" -e MOVING_WINDOW="1 day" \
    data-transloader-job:latest --provider environment_canada --station_id CWCF
```

## Building

The build has to be done in the root directory of this repository:

```
docker build -t data-transloader-job:latest -f docker/cron/Dockerfile .
```

## Environment Variables

| Environment Variable | Description                                                                                                             | Default Value |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------- |
| `SCHEDULE`           | A valid cron time specification (see [here][man5crontab])                                                               | `@daily`      |
| `DATA_DIR`           | The directory to store data. Defaults to the volume `/data`.                                                            | `/data`       |
| `MOVING WINDOW`      | The moving time window of observations to push to th STA, supplied to [`date -d`][man1date] as `"${MOVING_WINDOW} ago"` | `2 days`      |
| `STA_URL`            | The URL of SensorThings API to push metadata and observations                                                           | ``            |
| `OVERWRITE_METADATA` | Whether `get metadata` should be executed with each `cron` invocation.                                                  | `false`       |

[man1date]: https://man7.org/linux/man-pages/man1/date.1.html
[man5crontab]: https://man7.org/linux/man-pages/man5/crontab.5.html
