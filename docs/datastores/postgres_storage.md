# Postgres Datastore

As an alternative to the file-based datastore, the Postgres-backed datastore is designed to be safer to run concurrently. It alsos takes advantage of Postgres caching, providing better performance than the file-based datastore.

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

The name `etl` is arbitrary; you can name the database whatever.