FROM golang:1.19-alpine AS golang

ENV V2RAY_PLUGIN_VERSION v5.1.0
ENV GO111MODULE on

# Build v2ray-plugin
RUN apk add --no-cache git build-base \
    && mkdir -p /go/src/github.com/teddysun \
    && cd /go/src/github.com/teddysun \
    && git clone https://github.com/teddysun/v2ray-plugin.git \
    && cd v2ray-plugin \
    && git checkout "$V2RAY_PLUGIN_VERSION" \
    && go get -d \
    && go build

FROM alpine:3.17

LABEL maintainer="Acris Liu <acrisliu@gmail.com>"

ENV SHADOWSOCKS_LIBEV_VERSION v3.3.5

# Build shadowsocks-libev
RUN set -ex \
    # Install dependencies
    && apk add --no-cache --virtual .build-deps \
               autoconf \
               automake \
               build-base \
               libev-dev \
               libtool \
               linux-headers \
               udns-dev \
               libsodium-dev \
               mbedtls-dev \
               pcre-dev \
               tar \
               udns-dev \
               c-ares-dev \
               git \
    # Build shadowsocks-libev
    && mkdir -p /tmp/build-shadowsocks-libev \
    && cd /tmp/build-shadowsocks-libev \
    && git clone https://github.com/shadowsocks/shadowsocks-libev.git \
    && cd shadowsocks-libev \
    && git checkout "$SHADOWSOCKS_LIBEV_VERSION" \
    && git submodule update --init --recursive \
    && ./autogen.sh \
    && ./configure --disable-documentation \
    && make install \
    && ssRunDeps="$( \
        scanelf --needed --nobanner /usr/local/bin/ss-server \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache --virtual .ss-rundeps privoxy $ssRunDeps \
    && cd / \
    && rm -rf /tmp/build-shadowsocks-libev \
    # Delete dependencies
    && apk del .build-deps

# Copy v2ray-plugin
COPY --from=golang /go/src/github.com/teddysun/v2ray-plugin/v2ray-plugin /usr/local/bin
# Copy privoxy config
COPY ./privoxy.config /etc/privoxy/config

# Shadowsocks environment variables
ENV SERVER_HOST ChangeMe!!!
ENV SERVER_PORT 8388
ENV LOCAL_PORT 1080
ENV PASSWORD ChangeMe!!!
ENV METHOD chacha20-ietf-poly1305
ENV TIMEOUT 86400
ENV DNS_ADDRS 1.1.1.1,1.0.0.1,2606:4700:4700::1111,2606:4700:4700::1001
ENV ARGS -u

EXPOSE $LOCAL_PORT/tcp $LOCAL_PORT/udp

# Start shadowsocks-libev local
CMD ["sh", "-c", "privoxy /etc/privoxy/config && ss-local -s $SERVER_HOST -p $SERVER_PORT -k $PASSWORD -m $METHOD -t $TIMEOUT -b 0.0.0.0 -l 8388 --reuse-port --no-delay $ARGS"]
