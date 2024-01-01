{% macro create_otel_deps() %}

-- creates a table to store the last position of the previous call to get_latest_otel_traces()
CREATE TRANSIENT TABLE {{ target.schema }}.export_otel_traces_pos IF NOT EXISTS (
	last_pos NUMBER(38,0),
  updated_at timestamp_ntz(9)
);

CREATE OR REPLACE PROCEDURE {{ target.schema }}.get_latest_otel_traces()
  RETURNS TABLE ("trace.trace_id" VARCHAR, "trace.span_id" VARCHAR, "trace.parent_id" VARCHAR, "timestamp" NUMBER, "duration_ms" FLOAT, "dbt.version" VARCHAR, "dbt.project_name" VARCHAR, "dbt.run_started_at" TIMESTAMP_NTZ, "dbt.command" VARCHAR, "dbt.full_refresh_flag" BOOLEAN, "dbt.target_profile_name" VARCHAR, "dbt.target_name" VARCHAR, "dbt.target_schema" VARCHAR, "dbt.target_threads" NUMBER, "dbt.cloud.project_id" VARCHAR, "dbt.cloud.job_id" VARCHAR, "dbt.cloud.run_id" VARCHAR, "dbt.cloud.run_reason_category" VARCHAR, "dbt.cloud.run_reason" VARCHAR, "dbt.env_vars" OBJECT, "dbt.vars" OBJECT, "dbt.invocation_args" OBJECT, "dbt.custom_envs" OBJECT, "dbt.model.node_id" VARCHAR, "dbt.model.was_full_refresh" BOOLEAN, "dbt.model.thread_id" VARCHAR, "dbt.model.status" VARCHAR, "dbt.model.query_completed_at" TIMESTAMP_NTZ, "dbt.model.rows_affected" NUMBER, "dbt.model.materialization" VARCHAR, "dbt.model.schema" VARCHAR, "name" VARCHAR, "dbt.model.alias" VARCHAR, "message" VARCHAR, "status_code" NUMBER)
  LANGUAGE PYTHON
  RUNTIME_VERSION = '3.11'
  PACKAGES = ('snowflake-snowpark-python')
  HANDLER = 'main'
  AS
$$
from snowflake.snowpark.functions import col
from datetime import datetime

def main(session):
    # first, get the last timestamp position from the _pos table
    pos_table = session.table('export_otel_traces_pos')
    last_pos = pos_table.select_expr('max(last_pos)').collect()[0][0]
    if last_pos is None:
        last_pos = 0

    # return any new contents from the traces table
    results_df = session.table('export_otel_traces').filter(col('"timestamp"') > last_pos)

    max_ts = session.table('export_otel_traces').select_expr('max("timestamp")').collect()[0][0]
    if last_pos is None:
        last_pos = 0

    # finally, update the _pos table with a new record
    ct = datetime.now()
    pos_df = session.create_dataframe([[max_ts, ct]], schema=session.table('export_otel_traces_pos').schema)
    pos_df.write.mode("append").save_as_table('export_otel_traces_pos')

    return results_df
$$;

{% endmacro %}
