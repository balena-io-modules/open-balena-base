FROM debian:jessie

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm

COPY src/01_nodoc /etc/dpkg/dpkg.cfg.d/
COPY src/01_buildconfig /etc/apt/apt.conf.d/

RUN apt-get update \
	&& apt-get dist-upgrade \
	&& apt-get install \
		apt-transport-https \
		build-essential \
		ca-certificates \
		curl \
		dbus \
		git \
		htop \
		iptables \
		less \
		libpq-dev \
		libsqlite3-dev \
		jq \
		nano \
		netcat \
		ifupdown \
		openssh-client \
		openssh-server \
		openvpn \
		parted \
		python \
		python-dev \
		rsyslog \
		rsyslog-gnutls \
		vim \
		wget \
	&& rm -rf /var/lib/apt/lists/*

ENV NODE_VERSION 4.1.2
ENV NPM_VERSION 2.14.3

RUN curl -SL "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.gz" | tar xz -C /usr/local --strip-components=1 \
	&& npm install -g npm@"$NPM_VERSION" \
	&& npm cache clear \
	&& rm -rf /tmp/*

ENV CONFD_VERSION 0.10.0

RUN wget -O /usr/local/bin/confd https://github.com/kelseyhightower/confd/releases/download/v${CONFD_VERSION}/confd-${CONFD_VERSION}-linux-amd64 \
	&& chmod a+x /usr/local/bin/confd \
	&& ln -s /usr/src/app/config/confd /etc/confd

RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# systemd configuration

ENV container lxc

# We never want these to run in a container
RUN systemctl mask \
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
	graphical.target

RUN systemctl disable ssh.service

COPY src/confd.service /etc/systemd/system/
COPY src/journald.conf /etc/systemd/
COPY src/rsyslog.conf /etc/
COPY src/logentries.all.crt /opt/ssl/
COPY src/dbus-no-oom-adjust.conf /etc/systemd/system/dbus.service.d/dbus-no-oom-adjust.conf

VOLUME ["/sys/fs/cgroup"]
VOLUME ["/run"]
VOLUME ["/run/lock"]

CMD env > /etc/docker.env; exec /sbin/init
