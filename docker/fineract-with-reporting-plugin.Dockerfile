ARG BASE_IMAGE=apache/fineract:latest
FROM ${BASE_IMAGE}

USER root

# Install fonts and font-management tools
RUN apk update && apk add --no-cache \
    fontconfig \
    ttf-dejavu \
    msttcorefonts-installer

# Update the font cache so Java can see them
RUN update-ms-fonts && fc-cache -f

RUN mkdir -p /app/plugins /app/pentahoReports \
    && chown -R nobody:nogroup /app/plugins /app/pentahoReports

COPY plugin-libs/ /app/plugins/
COPY pentahoReports/Postgresql/ /app/pentahoReports/Postgresql/
COPY pentahoReports/MariaDB/ /app/pentahoReports/MariaDB/

RUN ln -s /app/pentahoReports/Postgresql /app/pentahoReports/postgresql \
    && ln -s /app/pentahoReports/MariaDB /app/pentahoReports/mariadb

ENV FINERACT_PENTAHO_REPORTS_PATH=/app/pentahoReports/Postgresql

USER root
