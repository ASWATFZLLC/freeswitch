# syntax=docker/dockerfile:1
#
# FreeSWITCH "banshee" — Ziwo custom build (v1.11.1.1) — multi-arch (arm64 + amd64).
#
# Builds FreeSWITCH from THIS source tree (so the custom mod_verto / mod_callcenter
# code is included) plus the upstream dependency libraries that v1.11.1 expects.
# The Ziwo lib forks (spandsp/sofia-sip/libks/signalwire-c) were verified to be
# version-pinned mirrors of upstream with no functional patches, so upstream is used.
#
# Build (natively on the target arch — fast on Apple Silicon / Graviton):
#   docker build -f docker/arm64/Dockerfile -t ziwo-freeswitch:1.11.1.1 .
#
# Drop ZRTP if it fails to compile on arm64 (libzrtp has known ARM issues):
#   docker build -f docker/arm64/Dockerfile --build-arg ENABLE_ZRTP=false -t ziwo-freeswitch:1.11.1.1 .
#
# Run (Linux host — full media): docker run --network host ziwo-freeswitch:1.11.1.1
# Run (Mac dev — signaling only, no host net): publish ports, RTP will not flow well.

ARG BASE=ubuntu:22.04

############################
# Stage 1: builder
############################
FROM ${BASE} AS builder

ARG PREFIX=/usr/local/banshee
ARG ENABLE_ZRTP=true
ARG MAKE_JOBS=
# libks/signalwire-c track upstream HEAD (what signalwire builds v1.11 against);
# sofia pinned to current stable; spandsp uses its 'packages' branch HEAD.
ARG LIBKS_REF=master
ARG SIGNALWIRE_C_REF=master
ARG SOFIA_REF=v1.13.17
ARG SPANDSP_REF=
# Lua is built from source (not in Ubuntu repos at 5.5).
ARG LUA_VERSION=5.5.0

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# Build toolchain + dependency -dev packages for the banshee module set.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates git wget curl pkg-config \
      build-essential automake autoconf libtool libtool-bin cmake yasm uuid-dev \
      libssl-dev zlib1g-dev libjpeg-dev libsqlite3-dev libcurl4-openssl-dev \
      libpcre2-dev libspeex-dev libspeexdsp-dev libldns-dev libedit-dev libtiff-dev \
      libopus-dev libsndfile1-dev libpq-dev \
      libreadline-dev \
      libmpg123-dev libshout3-dev libvorbis-dev libmp3lame-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# --- Dependency libraries (upstream versions for v1.11.1) ---
# libks (websocket/crypto layer used by signalwire-c, verto, rtc)
RUN git clone https://github.com/signalwire/libks.git \
    && cd libks && git checkout ${LIBKS_REF} \
    && cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release . \
    && make ${MAKE_JOBS:+-j${MAKE_JOBS}} && make install

# signalwire-c
RUN git clone https://github.com/signalwire/signalwire-c.git \
    && cd signalwire-c && git checkout ${SIGNALWIRE_C_REF} \
    && PKG_CONFIG_PATH=/usr/lib/pkgconfig cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release . \
    && make ${MAKE_JOBS:+-j${MAKE_JOBS}} && make install

# sofia-sip (mod_sofia)
RUN git clone https://github.com/freeswitch/sofia-sip.git \
    && cd sofia-sip && git checkout ${SOFIA_REF} \
    && ./autogen.sh && ./configure --prefix=/usr \
    && make ${MAKE_JOBS:+-j${MAKE_JOBS}} && make install

# spandsp (mod_spandsp) — 'packages' branch is what FreeSWITCH builds against
RUN git clone --branch packages https://github.com/freeswitch/spandsp.git \
    && cd spandsp && { [ -n "${SPANDSP_REF}" ] && git checkout ${SPANDSP_REF} || true; } \
    && ./bootstrap.sh && ./configure --prefix=/usr \
    && make ${MAKE_JOBS:+-j${MAKE_JOBS}} && make install \
    && ldconfig

# Lua ${LUA_VERSION} from source (built with -fPIC so it static-links into mod_lua.so).
# Installed to /usr; a generic 'lua.pc' is provided so FreeSWITCH's configure
# (which probes pkg-config names luajit/lua5.3/.../lua) finds it via the 'lua' entry.
RUN curl -fsSL "https://www.lua.org/ftp/lua-${LUA_VERSION}.tar.gz" -o /usr/src/lua.tar.gz \
    && cd /usr/src && tar xzf lua.tar.gz && cd "lua-${LUA_VERSION}" \
    && make MYCFLAGS="-fPIC" linux \
    && make install INSTALL_TOP=/usr \
    && printf 'prefix=/usr\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\n\nName: Lua\nDescription: Lua language engine\nVersion: %s\nLibs: -L${libdir} -llua -lm -ldl\nCflags: -I${includedir}\n' "${LUA_VERSION}" > /usr/lib/pkgconfig/lua.pc \
    && pkg-config --modversion lua

# --- FreeSWITCH (this source tree, with Ziwo custom code) ---
COPY . /usr/src/freeswitch
WORKDIR /usr/src/freeswitch

# Use the banshee module set
COPY docker/arm64/modules.conf /usr/src/freeswitch/modules.conf

RUN if [ "${ENABLE_ZRTP}" = "true" ]; then ZRTP=--enable-zrtp; else ZRTP=; fi \
    && ./bootstrap.sh -j \
    && PKG_CONFIG_PATH=/usr/lib/pkgconfig ./configure \
         --prefix=${PREFIX} \
         --enable-core-pgsql-support \
         ${ZRTP}
RUN make ${MAKE_JOBS:+-j${MAKE_JOBS}} && make install

# The stock vanilla autoload config references many modules we didn't compile.
# Generate a clean modules.conf.xml listing only our built module set (avoids
# load-time CRIT errors), and bind the event socket to IPv4 loopback so that
# fs_cli / HEALTHCHECK work inside the container.
RUN set -e; cd ${PREFIX}/etc/freeswitch/autoload_configs \
    && mods="$(grep -vE '^[[:space:]]*(#|$)' /usr/src/freeswitch/modules.conf | sed 's|.*/||')" \
    && { echo '<configuration name="modules.conf" description="Modules">'; \
         echo '  <modules>'; \
         for m in $mods; do echo "    <load module=\"$m\"/>"; done; \
         echo '  </modules>'; \
         echo '</configuration>'; } > modules.conf.xml \
    && sed -i 's|<param name="listen-ip" value="[^"]*"/>|<param name="listen-ip" value="127.0.0.1"/>|' event_socket.conf.xml

############################
# Stage 2: runtime
############################
FROM ${BASE} AS runtime

ARG PREFIX=/usr/local/banshee
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# Runtime shared libraries only (no -dev, no toolchain)
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      libssl3 zlib1g libjpeg-turbo8 libsqlite3-0 libcurl4 \
      libpcre2-8-0 libspeex1 libspeexdsp1 libldns3 libedit2 libtiff5 \
      libopus0 libsndfile1 libpq5 \
      libmpg123-0 libshout3 libvorbis0a libmp3lame0 \
      gosu \
    && rm -rf /var/lib/apt/lists/*

# Match production: user banshee, group aswat
RUN groupadd -r aswat && useradd -r -g aswat -d ${PREFIX} -s /usr/sbin/nologin banshee

# Copy the built FreeSWITCH and the deps we installed into /usr (libks, sofia, spandsp, signalwire-c)
COPY --from=builder ${PREFIX} ${PREFIX}
COPY --from=builder /usr/lib/libks* /usr/lib/libsignalwire* /usr/lib/libsofia* /usr/lib/libspandsp* /usr/lib/
COPY --from=builder /usr/lib/pkgconfig/ /usr/lib/pkgconfig/
RUN ldconfig

RUN chown -R banshee:aswat ${PREFIX}

COPY docker/arm64/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Ports (informational; use --network host for media on Linux)
EXPOSE 8021/tcp
EXPOSE 5060/tcp 5060/udp 5080/tcp 5080/udp
EXPOSE 5061/tcp 5081/tcp
EXPOSE 5066/tcp 7443/tcp
EXPOSE 16384-32768/udp

VOLUME ["/usr/local/banshee/etc/freeswitch", "/usr/local/banshee/var", "/tmp"]

HEALTHCHECK --interval=15s --timeout=5s --start-period=30s \
  CMD ${PREFIX}/bin/fs_cli -x status | grep -q ^UP || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["freeswitch"]
