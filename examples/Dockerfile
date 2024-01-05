FROM golang:1.21-alpine as build

WORKDIR /workdir
COPY collector-builder-config.yaml /workdir/collector-builder-config.yaml
RUN apk update && apk add --no-cache curl
RUN curl -L -o ocb "https://github.com/open-telemetry/opentelemetry-collector/releases/download/cmd%2Fbuilder%2Fv0.91.0/ocb_0.91.0_linux_$(go version |  cut -d'/' -f 2)" && chmod +x ocb
RUN ./ocb --config collector-builder-config.yaml

FROM cgr.dev/chainguard/static:latest
COPY --from=build --chmod=755 /workdir/otelcol-snowflake /
COPY otel-collector-config.yaml /
EXPOSE 4317/tcp 4318/tcp 13133/tcp

CMD ["/otelcol-snowflake", "--config=/otel-collector-config.yaml"]
