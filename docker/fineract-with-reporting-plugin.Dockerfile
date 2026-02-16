ARG BASE_IMAGE=apache/fineract:latest
FROM ${BASE_IMAGE}

USER root

# Install fonts required for Pentaho PDF report generation
RUN apt-get update && apt-get install -y --no-install-recommends \
    fontconfig \
    fonts-dejavu-core \
    fonts-liberation \
    && fc-cache -f -v \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app/plugins /app/pentahoReports \
    && chown -R nobody:nogroup /app/plugins /app/pentahoReports

COPY plugin-libs/ /app/plugins/
COPY pentahoReports/Postgresql/ /app/pentahoReports/Postgresql/
COPY pentahoReports/MariaDB/ /app/pentahoReports/MariaDB/

RUN ln -s /app/pentahoReports/Postgresql /app/pentahoReports/postgresql \
    && ln -s /app/pentahoReports/MariaDB /app/pentahoReports/mariadb

ENV FINERACT_PENTAHO_REPORTS_PATH=/app/pentahoReports/Postgresql

USER root
