# Docker Instructions

A `Dockerfile` is included in this repository for deploying this tool via [Docker][]. This may be preferable to setting up a Ruby installation on a server, or to permit running this tool in a container-only workflow.

There is currently no official Docker image on Docker Hub. Please build a Docker image from source instead to ensure the latest changes and updates are included.

## Building the Image

```terminal
$ docker build -t data-transloader:latest .
```

## Running a Container

To test that the container runs:

```terminal
$ docker run -it --rm data-transloader:latest
```

This should print the "help" information for the tool. We use `--rm` to delete the container after running, as it is an ephemeral one-time run.

To run the tool in actual usage, a Docker volume should be used to store the data and metadata. ([A bind mount][binds] to the host filesystem may also be used.)

```terminal
$ docker volume create etl-data
```

The tool can then be ran with the usual parameters; be sure to mount the volume so that the metadata is re-used.

```terminal
$ docker run -it --rm \
    --mount source=etl-data,target=/srv/data \
    data-transloader:latest \
    get metadata --provider environment_canada \
    --station_id CXCM \
    --database_url file:///srv/data

$ docker run -it --rm \
    --mount source=etl-data,target=/srv/data \
    data-transloader:latest \
    get observations \
    --provider environment_canada \
    --station_id CXCM \
    --database_url file:///srv/data
```

For more detailed usage, please see the detailed instructions for each data provider:

* [docs/ENVIRONMENT_CANADA.md](docs/ENVIRONMENT_CANADA.md)
* [docs/DATA_GARRISON.md](docs/DATA_GARRISON.md)
* [docs/CAMPBELL_SCIENTIFIC.md](docs/CAMPBELL_SCIENTIFIC.md)

The instructions there can be modified into the `docker run` form.

[binds]: https://docs.docker.com/storage/bind-mounts/
[Docker]: https://docs.docker.com/get-started/
