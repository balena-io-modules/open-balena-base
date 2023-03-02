FROM debian:bullseye

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

COPY src/01_nodoc /etc/dpkg/dpkg.cfg.d/
COPY src/01_buildconfig /etc/apt/apt.conf.d/

#hadolint ignore=DL3008
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
		apt-transport-https \
		build-essential \
		ca-certificates \
		curl \
		dbus \
		dirmngr \
		git \
		gnupg \
		htop \
		ifupdown \
		init \
		iptables \
		iptraf-ng \
		jq \
		less \
		libnss-mdns \
		libpq-dev \
		libsqlite3-dev \
		nano \
		net-tools \
		netcat \
		openssh-client \
		openssh-server \
		openvpn \
		python \
		python-dev \
		python3 \
		python3-dev \
		rsyslog \
		rsyslog-gnutls \
		strace \
		systemd \
		vim \
		wget \
	&& rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH

ENV NODE_VERSION 18.14.2
ENV NPM_VERSION 9.6.0

RUN if [ "${TARGETARCH}" = "amd64" ] ; \
	then \
		NODE_URL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" ; \
	else \
		NODE_URL="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-${TARGETARCH}.tar.gz" ; \
	fi && \
	curl -fsSL "${NODE_URL}" | tar xz -C /usr/local --strip-components=1 --no-same-owner \
	&& npm install -g npm@"$NPM_VERSION" \
	&& rm -rf /root/.npm/_cacache \
	&& npm cache clear --force \
	&& rm -rf /tmp/*

# Confd binary installation.
ENV CONFD_VERSION 0.16.0
RUN curl -fsSL -o /usr/local/bin/confd "https://github.com/kelseyhightower/confd/releases/download/v${CONFD_VERSION}/confd-${CONFD_VERSION}-linux-${TARGETARCH}" \
	&& chmod a+x /usr/local/bin/confd

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Remove default nproc limit for Avahi for it to work in-container
RUN sed -i "s/rlimit-nproc=3//" /etc/avahi/avahi-daemon.conf

# systemd configuration
ENV container lxc

# We want to use the multi-user.target not graphical.target
RUN systemctl set-default multi-user.target \
	# We never want these to run in a container
	&& systemctl mask \
		apt-daily.timer \
		apt-daily-upgrade.timer \
		dev-hugepages.mount \
		dev-mqueue.mount \
		sys-fs-fuse-connections.mount \
		sys-kernel-config.mount \
		sys-kernel-debug.mount \
		display-manager.service \
		getty@.service \
		systemd-logind.service \
		systemd-remount-fs.service \
		getty.target \
		graphical.target \
	&& systemctl disable ssh.service

COPY src/confd.service src/certs-watch.* /etc/systemd/system/
COPY src/configure-balena.sh /usr/sbin/
COPY src/journald.conf /etc/systemd/
COPY src/rsyslog.conf src/nsswitch.conf /etc/
COPY src/dbus-no-oom-adjust.conf /etc/systemd/system/dbus.service.d/
COPY src/entry.sh /usr/bin/
COPY src/htoprc /root/.config/htop/
COPY src/mdns.allow /etc/mdns.allow

RUN systemctl enable certs-watch.path

VOLUME ["/sys/fs/cgroup"]
VOLUME ["/run"]
VOLUME ["/run/lock"]

CMD ["/usr/bin/entry.sh"]
