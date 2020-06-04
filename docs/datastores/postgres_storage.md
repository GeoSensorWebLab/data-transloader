# Postgres Datastore

As an alternative to the file-based datastore, the Postgres-backed datastore is designed to be safer to run concurrently. Performance for writing records is a bit slower than the file-based store, although this can be aleviated by using more threads (see below).

Before the Postgres Datastore can be used, the database must be created and initialized. In the following example, a new database named `etl` is created, then loaded with the table and indexes from the `db/schema.sql` file.

```
$ psql postgres -c 'CREATE DATABASE etl;'
$ psql etl -f db/schema.sql
```

The datastore can then be used by specifying `postgresql://` for the `--database_url` option in the command line interface, like so:

```
$ transload get metadata \
    --provider environment_canada \
    --station_id CXCM \
    --database_url postgresql://localhost:5432/etl
```

This "URL" follows the [PostgreSQL connection string format](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING).

The name `etl` is arbitrary; you can name the database whatever you want.

## Threading

The library can take advantage of threads to issue more simultaneous connections to PostgreSQL. This is a noticeable speed boost especially with larger datasets being loaded into the data store. The number of threads can be changed by using the `NUM_THREADS` environment variable.

```
$ NUM_THREADS=8 transload get observations \
    --provider environment_canada \
    --station_id CXCM \
    --database_url postgresql://localhost:5432/etl
```

Alternatively:

```
$ export NUM_THREADS=8
$ transload get observations \
    --provider environment_canada \
    --station_id CXCM \
    --database_url postgresql://localhost:5432/etl
```

If you specify less than 2 threads, then threading will be disabled.

The recommended number of threads will depend on the machine running the ETL as well as the number of workers in PostgreSQL. "8" seems to be a usable number from my limited testing.
