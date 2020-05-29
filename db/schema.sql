-- This schema file will generate the base database needed for the ETL
-- workflow.

drop table "stations" cascade;
drop table "observations";

-- Station model contains metadata for stations.
-- "Datastreams" and "Data Files" are stored inside `metadata`.
CREATE TABLE IF NOT EXISTS "stations" (
	id serial primary key,
	station_key text NOT NULL,
	provider_key text NOT NULL,
	name text,
	metadata jsonb
);

-- Observation model contains data and metadata needed to construct
-- SensorThings API Observation entities.
CREATE TABLE IF NOT EXISTS "observations" (
	id bigserial primary key,
	station_id bigint NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
	phenomenon_time timestamp with time zone NOT NULL,
	result text,
	property text NOT NULL,
	metadata jsonb,
	-- In SensorThings API, a Datastream (defined with station_id and
	-- property) can only have a single Observation for a single
	-- phenomenon time.
	UNIQUE (station_id, property, phenomenon_time)
);

CREATE UNIQUE INDEX observations_idx ON "observations"
	(station_id, property, phenomenon_time);
