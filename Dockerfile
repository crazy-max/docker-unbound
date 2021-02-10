FROM --platform=${TARGETPLATFORM:-linux/amd64} alpine:3.12
LABEL maintainer="CrazyMax"

ENV UNBOUND_VERSION="1.13.1" \
  LDNS_VERSION="1.7.1"

RUN apk --update --no-cache add \
    ca-certificates \
    dns-root-hints \
    dnssec-root \
    expat \
    libevent \
    libpcap \
    openssl \
    shadow \
  && apk --update --no-cache add -t build-dependencies \
    build-base \
    curl \
    expat-dev \
    libevent-dev \
    linux-headers \
    libcap \
    libpcap-dev \
    openssl-dev \
    perl \
    tar \
  # unbound
  && mkdir /tmp/unbound && cd /tmp/unbound \
  && mkdir -p /run/unbound \
  && curl -sSL "https://unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz" | tar xz --strip 1 \
  && ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --mandir=/usr/share/man \
    --localstatedir=/var \
    --with-chroot-dir="" \
    --with-pidfile=/var/run/unbound/unbound.pid \
    --with-run-dir=/var/run/unbound \
    --with-username="" \
    --disable-flto \
    --disable-rpath \
    --disable-shared \
    --enable-event-api \
    --with-libevent \
    --with-pthreads \
    --with-ssl \
    || cat config.log \
  && make -j$(nproc) \
  && make install \
  && strip $(which unbound) \
  && unbound -V \
  && unbound-anchor -v || true \
  # ldns
  && mkdir /tmp/ldns && cd /tmp/ldns \
  && curl -sSL "https://nlnetlabs.nl/downloads/ldns/ldns-${LDNS_VERSION}.tar.gz" | tar xz --strip 1 \
  && ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --mandir=/usr/share/man \
    --infodir=/usr/share/info \
    --localstatedir=/var \
    --disable-gost \
    --disable-rpath \
    --disable-shared \
    --with-drill \
    --with-ssl \
    --with-trust-anchor=/var/run/unbound/root.key \
    --with-ssl \
    || cat config.log \
  && make -j$(nproc) \
  && make install \
  && strip $(which drill) \
  && ldns-config --version \
  && apk del build-dependencies \
  && rm -rf /tmp/* /var/cache/apk/* /var/www/*

COPY rootfs /

RUN mkdir -p /config \
  && addgroup -g 1500 unbound \
  && adduser -D -H -u 1500 -G unbound -s /bin/sh unbound \
  && chown -R unbound. /etc/unbound /run/unbound \
  && rm -rf /tmp/* /var/cache/apk/*

USER unbound

EXPOSE 5053/tcp
EXPOSE 5053/udp
VOLUME [ "/config" ]

ENTRYPOINT [ "unbound" ]
CMD [ "-d", "-c", "/etc/unbound/unbound.conf" ]

HEALTHCHECK --interval=30s --timeout=10s \
  CMD drill -p 5053 unbound.net @127.0.0.1
