# syntax=docker/dockerfile:1

ARG UNBOUND_VERSION=1.16.2
ARG LDNS_VERSION=1.8.3
ARG XX_VERSION=1.1.1
ARG ALPINE_VERSION=3.16

FROM --platform=$BUILDPLATFORM tonistiigi/xx:${XX_VERSION} AS xx

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS base
COPY --from=xx / /
RUN apk --update --no-cache add binutils clang curl file make pkgconf tar tree xz

FROM base AS base-build
ENV XX_CC_PREFER_LINKER=ld
ARG TARGETPLATFORM
RUN xx-apk --no-cache add gcc g++ expat-dev libevent-dev libcap libpcap-dev openssl-dev perl
RUN xx-clang --setup-target-triple

FROM base AS unbound-src
WORKDIR /src/unbound
ARG UNBOUND_VERSION
RUN curl -sSL "https://unbound.net/downloads/unbound-${UNBOUND_VERSION}.tar.gz" | tar xz --strip 1

FROM base AS ldns-src
WORKDIR /src/ldns
ARG LDNS_VERSION
RUN curl -sSL "https://nlnetlabs.nl/downloads/ldns/ldns-${LDNS_VERSION}.tar.gz" | tar xz --strip 1

FROM base-build AS unbound-build
COPY --from=unbound-src /src/unbound /src/unbound
WORKDIR /src/unbound
RUN set -x ; CC=xx-clang CXX=xx-clang++ ./configure \
  --host=$(xx-clang --print-target-triple) \
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
  --with-pthreads \
  --with-libexpat=$(xx-info sysroot)/usr \
  --with-libevent=$(xx-info sysroot)/usr \
  --with-ssl=$(xx-info sysroot)/usr
RUN <<EOT
set -ex
make DESTDIR=/out install
make DESTDIR=/out unbound-event-install
install -Dm755 contrib/update-anchor.sh /out/usr/share/unbound/update-anchor.sh
tree /out
xx-verify /out/usr/sbin/unbound
xx-verify /out/usr/sbin/unbound-anchor
xx-verify /out/usr/sbin/unbound-checkconf
xx-verify /out/usr/sbin/unbound-control
xx-verify /out/usr/sbin/unbound-host
file /out/usr/sbin/unbound
file /out/usr/sbin/unbound-anchor
file /out/usr/sbin/unbound-checkconf
file /out/usr/sbin/unbound-control
file /out/usr/sbin/unbound-host
EOT

FROM base-build AS ldns-build
COPY --from=ldns-src /src/ldns /src/ldns
WORKDIR /src/ldns
RUN set -x ; CC=xx-clang CXX=xx-clang++ CPPFLAGS=-I/src/ldns/ldns ./configure \
  --host=$(xx-clang --print-target-triple) \
  --prefix=/usr \
  --sysconfdir=/etc \
  --mandir=/usr/share/man \
  --infodir=/usr/share/info \
  --localstatedir=/var \
  --disable-gost \
  --disable-rpath \
  --disable-shared \
  --with-drill \
  --with-ssl=$(xx-info sysroot)/usr \
  --with-trust-anchor=/var/run/unbound/root.key
RUN <<EOT
set -ex
make DESTDIR=/out install
tree /out
xx-verify /out/usr/bin/drill
file /out/usr/bin/drill
EOT

FROM alpine:${ALPINE_VERSION}
COPY --from=unbound-build /out /
COPY --from=ldns-build /out /

RUN apk --update --no-cache add \
    ca-certificates \
    dns-root-hints \
    dnssec-root \
    expat \
    libevent \
    libpcap \
    openssl \
    shadow \
  && mkdir -p /run/unbound \
  && unbound -V \
  && unbound-anchor -v || true \
  && ldns-config --version \
  && rm -rf /tmp/* /var/www/*

COPY rootfs /

RUN mkdir -p /config \
  && addgroup -g 1500 unbound \
  && adduser -D -H -u 1500 -G unbound -s /bin/sh unbound \
  && chown -R unbound. /etc/unbound /run/unbound \
  && rm -rf /tmp/*

USER unbound

EXPOSE 5053/tcp
EXPOSE 5053/udp
VOLUME [ "/config" ]

ENTRYPOINT [ "unbound" ]
CMD [ "-d", "-c", "/etc/unbound/unbound.conf" ]

HEALTHCHECK --interval=30s --timeout=10s \
  CMD drill -p 5053 unbound.net @127.0.0.1
