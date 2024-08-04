FROM docker.io/amd64/almalinux:9 AS builder

LABEL authors vadim@grinco.eu 

ENV LOCALES en_US.UTF-8

RUN echo -e '\033[36;1m ******* INSTALL PACKAGES ******** \033[0m'; \
        dnf -y update && \
        dnf -y install epel-release dnf-plugins-core && \
        dnf config-manager --set-enabled crb

RUN dnf -y install \
        autoconf \
        automake \
        cargo \
        cbindgen \
        diffutils \
        dpdk-devel \
        elfutils-libelf-devel \
        file \
        file-devel \
        gcc \
        gcc-c++ \
        git \
        hiredis-devel \
        jansson-devel \
        jq \
        lua-devel \
        libbpf-devel \
        libtool \
        libyaml-devel \
        libnfnetlink-devel \
        libnetfilter_queue-devel \
        libnet-devel \
        libcap-ng-devel \
        libevent-devel \
        libmaxminddb-devel \
        libpcap-devel \
        libprelude-devel \
        libtool \
        lz4-devel \
        make \
        nspr-devel \
        nss-devel \
        nss-softokn-devel \
        numactl-devel \
        pcre2-devel \
        pkgconfig \
        python3-devel \
        python3-yaml \
        rust \
        which \
        zlib-devel

RUN echo -e '\033[36;1m ******* CHANGE LOCALES ******** \033[0m'; \
  locale-gen ${LOCALES}
  

RUN  echo -e '\033[36;1m ******* INSTALL SURICATA ******** \033[0m'; \
  dnf -y install https://kojipkgs.fedoraproject.org/packages/hyperscan/5.4.0/4.el9/x86_64/hyperscan-5.4.0-4.el9.x86_64.rpm https://kojipkgs.fedoraproject.org/packages/hyperscan/5.4.0/4.el9/x86_64/hyperscan-devel-5.4.0-4.el9.x86_64.rpm; 

ARG VERSION=7

WORKDIR /src

RUN  curl -OL https://www.openinfosecfoundation.org/download/suricata-${VERSION}.tar.gz; \
	tar zxf suricata-${VERSION}.tar.gz;

WORKDIR /src/suricata-${VERSION}

ARG CONFIGURE_ARGS

RUN ./configure \
        --prefix=/usr \
        --disable-shared \
        --disable-gccmarch-native \
        --enable-lua \
        --enable-nfqueue \
        --enable-hiredis \
        --enable-geoip \
        --enable-ebpf \
	--enable-dpdk \
        ${CONFIGURE_ARGS}

ARG CORES=2

RUN make -j "${CORES}"

RUN make install install-conf DESTDIR=/fakeroot

# Something about the Docker mounts won't let us copy /var/run in the
# next stage.
RUN rm -rf /fakeroot/var

FROM docker.io/almalinux/amd64:9-base AS runner

RUN \
        dnf -y update && \
        dnf -y install epel-release && \
        dnf -y install \
        cronie \
	dpdk \
        elfutils-libelf \
        file \
        findutils \
        hiredis \
        iproute \
        jansson \
        lua-libs \
        libbpf \
        libyaml \
        libnfnetlink \
        libnetfilter_queue \
        libnet \
        libcap-ng \
        libevent \
        libmaxminddb \
        libpcap \
        libprelude \
        logrotate \
        lz4 \
        net-tools \
        nss \
        nss-softokn \
        numactl \
        pcre2 \
        procps-ng \
        python3 \
        python3-yaml \
        tcpdump \
        which \
        zlib && \
        if [ "$(arch)" = "x86_64" ]; then dnf -y install https://kojipkgs.fedoraproject.org/packages/hyperscan/5.4.0/4.el9/x86_64/hyperscan-5.4.0-4.el9.x86_64.rpm; fi && \
        dnf clean all && \
        find /etc/logrotate.d -type f -not -name suricata -delete

COPY --from=builder /fakeroot /

# Create the directories that didn't get copied from the previous stage.
RUN mkdir -p /var/log/suricata /var/run/suricata /var/lib/suricata

COPY /update.yaml /etc/suricata/update.yaml
COPY /suricata.logrotate /etc/logrotate.d/suricata

RUN suricata-update update-sources && \
        suricata-update enable-source oisf/trafficid && \
        suricata-update --no-test --no-reload && \
        /usr/bin/suricata -V

RUN useradd --system --create-home suricata && \
        chown -R suricata:suricata /etc/suricata && \
        chown -R suricata:suricata /var/log/suricata && \
        chown -R suricata:suricata /var/lib/suricata && \
        chown -R suricata:suricata /var/run/suricata && \
        cp -a /etc/suricata /etc/suricata.dist && \
        chmod 600 /etc/logrotate.d/suricata

VOLUME /var/log/suricata
VOLUME /var/lib/suricata
VOLUME /var/run/suricata
VOLUME /etc/suricata

RUN echo -e '\033[36;1m ******* INSTALL TRAFR ******** \033[0m';
RUN wget http://www.mikrotik.com/download/trafr.tgz -O /tmp/trafr.tgz
RUN cd ${HOME} && tar -zvxf /tmp/trafr.tgz && rm /tmp/trafr.tgz

RUN echo -e '\033[36;1m ******* SET ENTRYPOINT ******** \033[0m'
COPY ./suricata.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

RUN /usr/bin/suricata --build-info
