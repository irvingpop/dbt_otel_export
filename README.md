## dbt_otel_export
This project is built on the `dbt_artifacts` package for dbt.  It takes the output of `dbt_artifacts` and prepares it for consumption by the OpenTelemetry Collector's sqlqueryreceiver

### Using it

1. Add the package to your current dbt project's `packages.yml` file:

    ```yaml
    packages:
      - git: "https://github.com/irvingpop/dbt_otel_export.git"
        revision: v1.1.2
    ```

2. Run `dbt deps` to install the package

3. Add an on-run-end hook to your `dbt_project.yml`

    ```yml
    # during the development cycle
    on-run-end:
      - "{{ dbt_artifacts.upload_results(results) }}"

    # later, when in production
    on-run-end:
      - "{% if target.name == 'prod' %}{{ dbt_artifacts.upload_results(results) }}{% endif %}"
    ```

3. Run the initial setup for dbt_artifacts
    ```
    dbt run --select dbt_artifacts
    ```

4. Do a `dbt run` as normal

5. Download the latest OpenTelemetry Collector Contrib binary (`otelcol-contrib`) for your platform from: https://github.com/open-telemetry/opentelemetry-collector-releases/releases/tag/v0.91.0

6. Write out the provided [otel-collector-config.yaml](/examples/otel-collector-config.yaml) file, updating your `datasource` line (Snowflake example provided) and `otlp` endpoint (Honeycomb example provided) as needed:


7. Run the OpenTelemetry Collector service:
    ```bash
    SNOWFLAKE_USERNAME='<my_username>' \
      SNOWFLAKE_PASSWORD='<a_very_secure_password>' \
      SNOWFLAKE_INSTANCE='my_snowflake_instance.us-east-1' \
      SNOWFLAKE_DATABASE='analytics' \
      SNOWFLAKE_SCHEMA='prod' \
      SNOWFLAKE_WAREHOUSE='DEV' \
      SNOWFLAKE_ROLE='TRANSFORMER' \
      HONEYCOMB_API_KEY='a_very_secure_token' \
      HONEYCOMB_DATASET='dbt_runs' \
      ./otelcol-contrib --config examples/otel-collector-config.yaml
    ```

8. Now you should have traces available to view!  Example screenshots from Honeycomb:

![Honeycomb trace viewer](/examples/images/hny_trace_view.png)
![Honeycomb concurrency query](/examples/images/hny_concurrency.png)
![Honeycomb heatmap](/examples/images/hny_heatmap.png)

## For more information

- The dbt_artifacts package: https://github.com/brooklyn-data/dbt_artifacts
- The OpenTelemetry Collector: https://opentelemetry.io/docs/collector/
- The collector's sqlquery receiver: https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/sqlqueryreceiver

## Troubleshooting, etc

random stuff to try:
- `select * from export_otel_traces order by "timestamp" asc` should show stuff after at least one dbt run. If not, maybe `on-run-end` hook didn't fire?
- `select * from export_otel_traces_pos` should show 1 result for each time `get_latest_otel_traces()` has been called
- Run `call get_latest_otel_traces()` yourself (note, this will advance the position)
- Look at the otel collector log and/or try enabling detailed debugging

build a slim/dedicated otel collector.
1. Download otel collector builder (`ocb`) from here: https://github.com/open-telemetry/opentelemetry-collector/releases/tag/cmd%2Fbuilder%2Fv0.91.0
2. Use the provided config in [examples/collector-builder-config.yaml](/examples/collector-builder-config.yaml)
3. Run `./ocb --config examples/collector-builder-config.yaml`
