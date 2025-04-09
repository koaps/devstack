FROM debian:12-slim AS base

ARG node_version=23
ARG python_release=3.12
ARG python_version=3.12.9
ARG unit_version=1.34.2

ENV LD_LIBRARY_PATH=/usr/local/lib

WORKDIR /root
RUN set -x \
    && if [ -f "/tmp/libunit.a" ]; then \
        mv /tmp/libunit.a /usr/lib/$(dpkg-architecture -q DEB_HOST_MULTIARCH)/libunit.a; \
        rm -f /tmp/libunit.a; \
    fi \
    && printf '#!/bin/bash\nexport LD_LIBRARY_PATH=/usr/local/lib\n' >/etc/profile.d/ldd.sh \
    && mkdir -p /var/lib/unit/ \
    && mkdir /docker-entrypoint.d/ \
    && adduser \
         --home /home/unit \
         --disabled-password \
         --gecos "unit user" \
         --shell /bin/bash \
         --uid 1000 \
         --quiet \
         unit \
    && apt update \
    && apt-get install -y locales \
    && dpkg-reconfigure -f noninteractive locales \
    && locale-gen C.UTF-8 \
    && /usr/sbin/update-locale LANG=C.UTF-8 \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && apt install -y apt-utils build-essential ca-certificates curl git gpg golang \
       libbz2-dev libc6-dev libffi-dev libgdbm-dev libncursesw5-dev libpcre2-dev \
       libreadline-dev libsqlite3-dev libssl-dev libnss3-dev mercurial tk-dev wget zlib1g-dev \
    && curl -fsSL https://deb.nodesource.com/setup_${node_version}.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && mkdir -p /opt/node_modules\
    && npm install --prefix /opt/node_modules pnpm@latest -g \
    && npm install --prefix /opt/node_modules npm@latest -g \
    && npm install --prefix /opt/node_modules node-gyp -g \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && rm -f /requirements.apt \
    && ln -sf /dev/stdout /var/log/unit.log

RUN set -x \
    && wget https://www.python.org/ftp/python/${python_version}/Python-${python_version}.tar.xz \
    && unxz Python-${python_version}.tar.xz && tar xvf Python-${python_version}.tar \
    && cd Python-${python_version} \
    && ./configure --enable-optimizations --with-lto --enable-shared --enable-loadable-sqlite-extensions --with-ensurepip=upgrade \
    && make -j `nproc` \
    && make altinstall \
    && ln -s /usr/local/bin/python${python_release} /usr/local/bin/python3 \
    && ln -sf /usr/local/bin/pip${python_release} /usr/local/bin/pip3 \
    && ln -s /usr/local/lib/libpython${python_release}.so.1.0 /lib/x86_64-linux-gnu/. \
    && /usr/local/bin/pip3 install -U pip \
    && cd && rm -rf Python-${python_version} Python-${python_version}.tar

FROM base AS builder

RUN set -ex \
    && mkdir -p /usr/lib/unit/modules /usr/lib/unit/debug-modules \
    && git clone -b ${unit_version} https://github.com/nginx/unit \
    && cd unit \
    && NCPU="$(getconf _NPROCESSORS_ONLN)" \
    && DEB_HOST_MULTIARCH="$(dpkg-architecture -q DEB_HOST_MULTIARCH)" \
    && CC_OPT="$(DEB_BUILD_MAINT_OPTIONS="hardening=+all,-pie" DEB_CFLAGS_MAINT_APPEND="-Wp,-D_FORTIFY_SOURCE=2 -fPIC" dpkg-buildflags --get CFLAGS)" \
    && LD_OPT="$(DEB_BUILD_MAINT_OPTIONS="hardening=+all,-pie" DEB_LDFLAGS_MAINT_APPEND="-Wl,--as-needed -pie" dpkg-buildflags --get LDFLAGS)" \
    && CONFIGURE_ARGS_MODULES="--prefix=/usr \
                --state=/var/lib/unit \
                --control=unix:/var/run/control.unit.sock \
                --pid=/var/run/unit.pid \
                --log=/var/log/unit.log \
                --tmp=/var/tmp \
                --user=unit \
                --group=unit \
                --openssl \
                --libdir=/usr/lib/$DEB_HOST_MULTIARCH" \
    && CONFIGURE_ARGS="$CONFIGURE_ARGS_MODULES --njs" \
    && make -j $NCPU -C pkg/contrib .njs \
    && export PKG_CONFIG_PATH=$(pwd)/pkg/contrib/njs/build \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --ld-opt="$LD_OPT" --modulesdir=/usr/lib/unit/debug-modules --debug \
    && make -j $NCPU unitd \
    && install -pm755 build/sbin/unitd /usr/sbin/unitd-debug \
    && make clean \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --ld-opt="$LD_OPT" --modulesdir=/usr/lib/unit/modules \
    && make -j $NCPU unitd \
    && install -pm755 build/sbin/unitd /usr/sbin/unitd \
    && make clean \
    && ./configure $CONFIGURE_ARGS_MODULES --cc-opt="$CC_OPT" --modulesdir=/usr/lib/unit/debug-modules --debug \
    && ./configure nodejs --node-gyp=/opt/node_modules/npm/bin/node-gyp-bin/node-gyp \
    && ./configure python --module=python3 --config=/usr/local/bin/python${python_release}-config \
    && make -j $NCPU libunit-install node node-install python3-install \
    && make clean \
    && ./configure $CONFIGURE_ARGS_MODULES --cc-opt="$CC_OPT" --modulesdir=/usr/lib/unit/modules \
    && ./configure nodejs --node-gyp=/opt/node_modules/npm/bin/node-gyp-bin/node-gyp \
    && ./configure python --module=python3 --config=/usr/local/bin/python${python_release}-config \
    && make -j $NCPU node node-install libunit-install python3-install

FROM base

COPY --from=builder /usr/sbin/unitd /usr/sbin/unitd
COPY --from=builder /usr/sbin/unitd-debug /usr/sbin/unitd-debug
COPY --from=builder /usr/lib/unit/ /usr/lib/unit/
COPY --from=builder /usr/lib/*-linux-gnu/libunit.a /tmp/
COPY --from=builder /usr/include/nxt_* /usr/include/
COPY --from=builder /opt/node_modules/unit-http/ /opt/node_modules/unit-http/

RUN set -x \
   && mkdir -p /usr/share/unit/welcome/ \
   && wget -P /usr/share/unit/welcome/ https://raw.githubusercontent.com/nginx/unit/master/pkg/docker/welcome.html \
   && wget -P /usr/share/unit/welcome/ https://raw.githubusercontent.com/nginx/unit/master/pkg/docker/welcome.json \
   && wget -P /usr/share/unit/welcome/ https://raw.githubusercontent.com/nginx/unit/master/pkg/docker/welcome.md

STOPSIGNAL SIGTERM

VOLUME /docker-entrypoint.d/

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["unitd", "--no-daemon", "--control", "unix:/var/run/control.unit.sock"]
