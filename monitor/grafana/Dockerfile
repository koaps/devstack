FROM grafana/grafana

ARG DIR=.
USER root

RUN rm -rf /var/lib/apt/lists/*

WORKDIR /etc/grafana
ADD ${DIR}/grafana.ini /etc/grafana
COPY ${DIR}/datasources ./datasources
COPY ${DIR}/local.yml provisioning/dashboards/local.yml

COPY ${DIR}/dashboards /var/lib/grafana/dashboards

WORKDIR /app
COPY ${DIR}/entrypoint.sh ./
RUN chmod u+x entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/app/entrypoint.sh"]
