#
# uIota Dockerfile
#
# The resulting image will contain everything needed to build uIota FW.
#
# Setup: (only needed once per Dockerfile change)
# 1. install docker, add yourself to docker group, enable docker, relogin
# 2. # docker build -t uiota-build .
#
# Usage:
# 3. cd to MeterLoggerWeb root
# 4. # docker run -t -i -p 8080:80 meterloggerweb:latest


FROM debian:buster

MAINTAINER Kristoffer Ek <stoffer@skulp.net>

RUN "echo" "deb http://http.us.debian.org/debian buster non-free" >> /etc/apt/sources.list

RUN apt-get update && apt-get install -y \
	aptitude \
	bash \
	autoconf \
	automake \
	bison \
	cpanplus \
	flex \
	g++ \
	gawk \
	gcc \
	make \
	sed \
	libdbd-mysql-perl \
	libdbi-perl \
	libnet-smtp-server-perl \
	default-mysql-client \
	git \
	inetutils-telnet \
	joe \
	make \
	sudo \
	screen \
	rsync \
	software-properties-common \
	procps \
	lsof \
	tzdata \
	openvpn \
	asterisk

USER root

COPY ./sip.conf /etc/asterisk/sip.conf
COPY ./extensions.conf /etc/asterisk/extensions.conf
COPY ./rtp.conf /etc/asterisk/rtp.conf
COPY ./indications.conf /etc/asterisk/indications.conf
COPY ./allowed_caller_id.pl /var/lib/asterisk/allowed_caller_id.pl
COPY ./smstools_send.pl /var/lib/asterisk/smstools_send.pl
COPY ./notify_user.pl /var/lib/asterisk/notify_user.pl
COPY ./pullert1.call /var/lib/asterisk/pullert1.call
COPY ./pullert2.call /var/lib/asterisk/pullert2.call
COPY ./press_one_or_two.gsm /usr/share/asterisk/sounds/custom/press_one_or_two.gsm
COPY ./pullert1.gsm /usr/share/asterisk/sounds/custom/pullert1.gsm
COPY ./pullert2.gsm /usr/share/asterisk/sounds/custom/pullert2.gsm
COPY ./openvpn /etc/openvpn
COPY ./docker-entrypoint.sh /docker-entrypoint.sh

RUN chown asterisk:asterisk /etc/asterisk/sip.conf
RUN chown asterisk:asterisk /etc/asterisk/extensions.conf
RUN chown asterisk:asterisk /etc/asterisk/rtp.conf
RUN chown asterisk:asterisk /etc/asterisk/indications.conf
RUN chown asterisk:asterisk /var/lib/asterisk/allowed_caller_id.pl
RUN chown asterisk:asterisk /var/lib/asterisk/smstools_send.pl
RUN chown asterisk:asterisk /var/lib/asterisk/notify_user.pl
RUN chown asterisk:asterisk /var/lib/asterisk/pullert1.call
RUN chown asterisk:asterisk /var/lib/asterisk/pullert2.call
RUN chown asterisk:asterisk /usr/share/asterisk/sounds/custom/press_one_or_two.gsm
RUN chown asterisk:asterisk /usr/share/asterisk/sounds/custom/pullert1.gsm
RUN chown asterisk:asterisk /usr/share/asterisk/sounds/custom/pullert2.gsm


CMD /docker-entrypoint.sh

