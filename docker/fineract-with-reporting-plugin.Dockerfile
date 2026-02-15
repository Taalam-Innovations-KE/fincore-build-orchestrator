ARG BASE_IMAGE=apache/fineract:latest
FROM ${BASE_IMAGE}

USER root

RUN mkdir -p /app/plugins /app/pentahoReports \
    && chown -R nobody:nogroup /app/plugins /app/pentahoReports

COPY plugin-libs/ /app/plugins/
COPY pentahoReports/Postgresql/ /app/pentahoReports/Postgresql/
COPY pentahoReports/MariaDB/ /app/pentahoReports/MariaDB/

RUN ln -s /app/pentahoReports/Postgresql /app/pentahoReports/postgresql \
    && ln -s /app/pentahoReports/MariaDB /app/pentahoReports/mariadb

ENV FINERACT_PENTAHO_REPORTS_PATH=/app/pentahoReports/Postgresql

USER nobody:nogroup
