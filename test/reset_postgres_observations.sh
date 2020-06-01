#!/bin/bash
# Deletes all observations cached in Postgres on the "etl" database.
set -e

psql etl -c "TRUNCATE observations;"
