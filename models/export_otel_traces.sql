-- noqa: disable=ST06,RF04,RF05
{{ config(
    materialized='view',
    post_hook="{{ create_otel_deps() }}"
) }}

with

invocations as (
    select
        *,
        md5(command_invocation_id) as trace_parent_id,
        get(invocation_args, 'invocation_command') as invocation_command,
        get(invocation_args, 'project_dir') as project_dir
    from {{ ref('fct_dbt__invocations') }}
),

model_executions as (
    select * from {{ ref('fct_dbt__model_executions') }}
),

child_spans as (
    select
        invocations.command_invocation_id,
        invocations.trace_parent_id,
        invocations.dbt_version,
        invocations.project_name,
        invocations.run_started_at,
        invocations.dbt_command,
        invocations.full_refresh_flag,
        invocations.target_profile_name,
        invocations.target_name,
        invocations.target_schema,
        invocations.target_threads,
        invocations.dbt_cloud_project_id,
        invocations.dbt_cloud_job_id,
        invocations.dbt_cloud_run_id,
        invocations.dbt_cloud_run_reason_category,
        invocations.dbt_cloud_run_reason,
        invocations.env_vars,
        invocations.dbt_vars,
        invocations.invocation_args,
        invocations.dbt_custom_envs,
        model_executions.model_execution_id,
        model_executions.node_id,
        model_executions.was_full_refresh,
        model_executions.thread_id,
        model_executions.status,
        -- workaround for skipped models so they don't have a null timestamp, coalesce to run_started_at if null
        coalesce(model_executions.compile_started_at, model_executions.run_started_at) as compile_started_at,
        coalesce(model_executions.query_completed_at, model_executions.run_started_at) as query_completed_at,
        (model_executions.total_node_runtime * 1000) as total_node_runtime, -- convert seconds into milliseconds
        model_executions.rows_affected,
        model_executions.materialization as db_materialization,
        model_executions.schema as db_schema,
        model_executions.name,
        model_executions.alias,
        model_executions.message,
        case model_executions.status
            when 'success' then 0
            else 1
        end as status_code
    from model_executions
    inner join invocations on
        model_executions.command_invocation_id = invocations.command_invocation_id
        and model_executions.run_started_at = invocations.run_started_at
),

root_span_gen as (
    select
        command_invocation_id,
        min(run_started_at) as run_start,
        max(query_completed_at) as run_ended_at,
        min(status_code) as status_code,
        -- sum(total_node_runtime) as aggregate_runtime,
        timestampdiff(millisecond, run_start, run_ended_at) as total_node_runtime
    from child_spans
    group by command_invocation_id
),

root_spans as (
    select
        invocations.command_invocation_id,
        '' as trace_parent_id, -- root spans by definition have no parent_id
        invocations.dbt_version,
        invocations.project_name,
        invocations.run_started_at,
        invocations.dbt_command,
        invocations.full_refresh_flag,
        invocations.target_profile_name,
        invocations.target_name,
        invocations.target_schema,
        invocations.target_threads,
        invocations.dbt_cloud_project_id,
        invocations.dbt_cloud_job_id,
        invocations.dbt_cloud_run_id,
        invocations.dbt_cloud_run_reason_category,
        invocations.dbt_cloud_run_reason,
        invocations.env_vars,
        invocations.dbt_vars,
        invocations.invocation_args,
        invocations.dbt_custom_envs,
        md5(invocations.command_invocation_id) as model_execution_id, -- create a surrogate span_id for the root span
        'root' as node_id,
        invocations.full_refresh_flag as was_full_refresh,
        '' as thread_id,
        '' as status,
        invocations.run_started_at as compile_started_at, -- use run_started_at as a "timestamp" for otel
        root_span_gen.run_ended_at as query_completed_at,
        root_span_gen.total_node_runtime,
        0 as rows_affected,
        '' as db_materialization,
        '' as db_schema,
        'root' as name,
        'root' as alias,
        '' as message,
        root_span_gen.status_code

    from root_span_gen
    inner join invocations on root_span_gen.command_invocation_id = invocations.command_invocation_id
),

combined as (
    select * from root_spans
    union all
    select * from child_spans
),

final as (
    select
        command_invocation_id as "trace.trace_id",
        model_execution_id as "trace.span_id",
        trace_parent_id as "trace.parent_id",
        date_part(epoch_nanosecond, compile_started_at) as "timestamp",
        total_node_runtime as "duration_ms",
        dbt_version as "dbt.version",
        project_name as "dbt.project_name",
        run_started_at::timestamp_ntz as "dbt.run_started_at",
        dbt_command as "dbt.command",
        full_refresh_flag as "dbt.full_refresh_flag",
        target_profile_name as "dbt.target_profile_name",
        target_name as "dbt.target_name",
        target_schema as "dbt.target_schema",
        target_threads as "dbt.target_threads",
        coalesce(dbt_cloud_project_id, '') as "dbt.cloud.project_id",
        coalesce(dbt_cloud_job_id, '') as "dbt.cloud.job_id",
        coalesce(dbt_cloud_run_id, '') as "dbt.cloud.run_id",
        coalesce(dbt_cloud_run_reason_category, '') as "dbt.cloud.run_reason_category",
        coalesce(dbt_cloud_run_reason, '') as "dbt.cloud.run_reason",
        coalesce(env_vars, parse_json('{}')) as "dbt.env_vars",
        coalesce(dbt_vars, parse_json('{}')) as "dbt.vars",
        coalesce(invocation_args, parse_json('{}')) as "dbt.invocation_args",
        coalesce(dbt_custom_envs, parse_json('{}')) as "dbt.custom_envs",
        node_id as "dbt.model.node_id",
        was_full_refresh as "dbt.model.was_full_refresh",
        thread_id as "dbt.model.thread_id",
        status as "dbt.model.status",
        query_completed_at as "dbt.model.query_completed_at",
        coalesce(rows_affected::int, 0) as "dbt.model.rows_affected",
        db_materialization as "dbt.model.materialization",
        db_schema as "dbt.model.schema",
        name as "name",
        alias as "dbt.model.alias",
        message as "message",
        status_code as "status_code"

    from combined
)

select * from final
