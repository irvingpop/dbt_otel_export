FROM golang:1.22-alpine as build

ENV OCB_VERSION=0.99.0
ENV OCB_ARCH=arm64
ENV OCB_DOWNLOAD_URL_BASE="https://github.com/open-telemetry/opentelemetry-collector/releases/download/"
ENV OCB_DOWNLOAD_URL="${OCB_DOWNLOAD_URL_BASE}cmd%2Fbuilder%2Fv${OCB_VERSION}/ocb_${OCB_VERSION}_linux_${OCB_ARCH}"

WORKDIR /workdir
COPY collector-builder-config.yaml /workdir/collector-builder-config.yaml
RUN apk update && apk add --no-cache curl
RUN curl -L -o ocb "${OCB_DOWNLOAD_URL}" && chmod +x ocb
RUN ./ocb --config collector-builder-config.yaml

FROM cgr.dev/chainguard/static:latest
COPY --from=build --chmod=755 /workdir/otelcol-snowflake /
COPY otel-collector-config.yaml /
EXPOSE 4317/tcp 4318/tcp 13133/tcp

CMD ["/otelcol-snowflake", "--config=/otel-collector-config.yaml"]
