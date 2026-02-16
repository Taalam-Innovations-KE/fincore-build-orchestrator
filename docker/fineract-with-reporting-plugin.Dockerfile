ARG BASE_IMAGE=apache/fineract:latest
FROM ${BASE_IMAGE}

USER root

RUN set -eux; \
    if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache fontconfig ttf-dejavu ttf-liberation; \
      if apk search -qe msttcorefonts-installer >/dev/null 2>&1; then \
        apk add --no-cache msttcorefonts-installer; \
        update-ms-fonts; \
      fi; \
    elif command -v apt-get >/dev/null 2>&1; then \
      apt-get update; \
      apt-get install -y --no-install-recommends fontconfig fonts-dejavu-core fonts-liberation fonts-noto-core; \
      rm -rf /var/lib/apt/lists/*; \
    else \
      echo "Unsupported base image: no apk or apt-get found" >&2; \
      exit 1; \
    fi; \
    fc-cache -f -v

RUN mkdir -p /app/plugins /app/pentahoReports \
    && chown -R nobody:nogroup /app/plugins /app/pentahoReports

COPY plugin-libs/ /app/plugins/
COPY pentahoReports/Postgresql/ /app/pentahoReports/Postgresql/
COPY pentahoReports/MariaDB/ /app/pentahoReports/MariaDB/

RUN ln -s /app/pentahoReports/Postgresql /app/pentahoReports/postgresql \
    && ln -s /app/pentahoReports/MariaDB /app/pentahoReports/mariadb

ENV FINERACT_PENTAHO_REPORTS_PATH=/app/pentahoReports/Postgresql

USER root
