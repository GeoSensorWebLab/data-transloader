#!/bin/bash
# Deletes all observations cached in Postgres on the "etl" database.
# This is used to quickly reset a single table for testing the loading
# observations step ("get observations").
set -e

psql etl -c "TRUNCATE observations;"
