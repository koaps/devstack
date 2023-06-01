FROM alpine

ARG gosu_version=1.12

RUN apk update && apk add curl postgresql && \
    mkdir /initdb.d && \
    curl -o /usr/local/bin/gosu -sSL "https://github.com/tianon/gosu/releases/download/${gosu_version}/gosu-amd64" && \
    chmod +x /usr/local/bin/gosu && \
    mkdir /run/postgresql && \
    chown postgres:postgres /run/postgresql/ && \
    apk del curl && \
    rm -rf /var/cache/apk/*

ENV LANG en_US.utf8
ENV PGDATA /var/lib/postgresql/data
VOLUME /var/lib/postgresql/data

COPY initdb/ /initdb.d/
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 5432
CMD ["postgres"]
