# Running in Docker

```
# from the examples folder
docker build -t <my_docker_org>/otel-collector-snowflake .

# Running with the inbuilt collector config file, supplying config via env vars
docker run --rm -it \
    -e SNOWFLAKE_USERNAME='<my_username>' \
    -e SNOWFLAKE_PASSWORD='<a_very_secure_password>' \
    -e SNOWFLAKE_INSTANCE='my_snowflake_instance.us-east-1' \
    -e SNOWFLAKE_DATABASE='analytics' \
    -e SNOWFLAKE_SCHEMA='prod' \
    -e SNOWFLAKE_WAREHOUSE='DEV' \
    -e SNOWFLAKE_ROLE='TRANSFORMER' \
    -e HONEYCOMB_API_KEY='a_very_secure_token' \
    -e HONEYCOMB_DATASET='dbt_runs' \
    <my_docker_org>/otel-collector-snowflake

# OR, run with your own custom collector config
docker run --rm -it \
    --mount type=bind,source=otel-collector-config.yaml,target=/otel-collector-config.yaml \
    <my_docker_org>/otel-collector-snowflake
```

# Running in Kubernetes
```
# use helm to deploy, first install helm on your local machine

# create a k8s namespace for this
kubectl create namespace dataops
kubectl create secret generic otelcol-snowflake \
  --from-literal=snowflake_username=$SNOWFLAKE_USERNAME \
  --from-literal=snowflake_password=$SNOWFLAKE_PASSWORD \
  --from-literal=snowflake_instance=$SNOWFLAKE_INSTANCE \
  --from-literal=snowflake_database=$SNOWFLAKE_DATABASE \
  --from-literal=snowflake_schema=$SNOWFLAKE_SCHEMA \
  --from-literal=snowflake_warehouse=$SNOWFLAKE_WAREHOUSE \
  --from-literal=snowflake_role=$SNOWFLAKE_ROLE \
  --from-literal=honeycomb_api_key=$HONEYCOMB_API_KEY \
  --from-literal=honeycomb_dataset=$HONEYCOMB_DATASET \
  --namespace=dataops

# setup steps
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

# deploy it
helm install otel-collector-snowflake open-telemetry/opentelemetry-collector \
  --namespace dataops \
  --values helm-values.yaml
```
