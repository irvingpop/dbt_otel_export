{% macro create_otel_deps() %}

-- creates a table to store the last position of the previous call to get_latest_otel_traces()
CREATE TRANSIENT TABLE {{ target.schema }}.export_otel_traces_pos IF NOT EXISTS (
	last_pos NUMBER(38,0),
  updated_at timestamp_ntz(9)
);

CREATE OR REPLACE PROCEDURE {{ target.schema }}.get_latest_otel_traces()
  RETURNS TABLE ("trace.trace_id" VARCHAR, "trace.span_id" VARCHAR, "trace.parent_id" VARCHAR, "timestamp" NUMBER, "duration_ms" FLOAT, "dbt.version" VARCHAR, "dbt.project_name" VARCHAR, "dbt.run_started_at" TIMESTAMP_NTZ, "dbt.command" VARCHAR, "dbt.full_refresh_flag" BOOLEAN, "dbt.target_profile_name" VARCHAR, "dbt.target_name" VARCHAR, "dbt.target_schema" VARCHAR, "dbt.target_threads" NUMBER, "dbt.cloud.project_id" VARCHAR, "dbt.cloud.job_id" VARCHAR, "dbt.cloud.run_id" VARCHAR, "dbt.cloud.run_reason_category" VARCHAR, "dbt.cloud.run_reason" VARCHAR, "dbt.env_vars" OBJECT, "dbt.vars" OBJECT, "dbt.invocation_args" OBJECT, "dbt.custom_envs" OBJECT, "dbt.model.node_id" VARCHAR, "dbt.model.was_full_refresh" BOOLEAN, "dbt.model.thread_id" VARCHAR, "dbt.model.status" VARCHAR, "dbt.model.query_completed_at" TIMESTAMP_NTZ, "dbt.model.rows_affected" NUMBER, "dbt.model.materialization" VARCHAR, "dbt.model.schema" VARCHAR, "name" VARCHAR, "dbt.model.alias" VARCHAR, "message" VARCHAR, "status_code" NUMBER)
  LANGUAGE SQL
  AS
$$
DECLARE
  last_pos NUMBER;
  max_ts NUMBER;
  results RESULTSET;
BEGIN
  last_pos := (select max(last_pos) from export_otel_traces_pos);
  max_ts := (select max("timestamp") from export_otel_traces);

  results := (select * from export_otel_traces where "timestamp" > coalesce(:last_pos, 0));

  insert into export_otel_traces_pos (last_pos, updated_at) values (coalesce(:max_ts, 0), current_timestamp());

  RETURN TABLE(results);
END;
$$;

{% endmacro %}
