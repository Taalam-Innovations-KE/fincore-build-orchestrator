ARG BASE_IMAGE=apache/fineract:latest
FROM ${BASE_IMAGE}

USER root

RUN mkdir -p /app/plugins /app/pentahoReports \
    && chown -R nobody:nogroup /app/plugins /app/pentahoReports

COPY plugin-libs/ /app/plugins/
COPY pentahoReports/ /app/pentahoReports/

ENV FINERACT_PENTAHO_REPORTS_PATH=/app/pentahoReports

USER nobody:nogroup
