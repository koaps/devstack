FROM quay.io/influxdb/influxdb:v2.0.4

WORKDIR /app
COPY entrypoint.sh ./
RUN chmod u+x entrypoint.sh

VOLUME /home/rancher
ENTRYPOINT ["/app/entrypoint.sh"]
