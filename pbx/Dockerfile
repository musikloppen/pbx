FROM debian:bullseye

MAINTAINER Kristoffer Ek <stoffer@skulp.net>

RUN sed -i 's/main$/main contrib non-free/' /etc/apt/sources.list && \
	sed -i 's/main$/main contrib non-free/' /etc/apt/sources.list.d/debian.sources || true

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
	libnumber-phone-perl \
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
	asterisk

USER root

# Copy shared Perl module into system @INC
COPY ./lib/My /usr/share/perl5/My

COPY ./pbx/pjsip.conf /etc/asterisk/pjsip.conf
COPY ./pbx/extensions.conf /etc/asterisk/extensions.conf
COPY ./pbx/manager.conf /etc/asterisk/manager.conf
COPY ./pbx/rtp.conf /etc/asterisk/rtp.conf
COPY ./pbx/indications.conf /etc/asterisk/indications.conf
COPY ./pbx/logger.conf /etc/asterisk/logger.conf
COPY ./pbx/modules.conf /etc/asterisk/modules.conf
COPY ./pbx/allowed_caller_id.pl /var/lib/asterisk/allowed_caller_id.pl
COPY ./pbx/log.pl /var/lib/asterisk/log.pl
COPY ./pbx/notify_user.pl /var/lib/asterisk/notify_user.pl
COPY ./pbx/gate1.call /var/lib/asterisk/gate1.call
COPY ./pbx/gate2.call /var/lib/asterisk/gate2.call

# Copy custom sound files (includes both .gsm and .wav formats)
COPY ./pbx/press_one_or_two.gsm /usr/share/asterisk/sounds/custom/press_one_or_two.gsm
COPY ./pbx/press_one_or_two.wav /usr/share/asterisk/sounds/custom/press_one_or_two.wav
COPY ./pbx/gate1.gsm /usr/share/asterisk/sounds/custom/gate1.gsm
COPY ./pbx/gate1.wav /usr/share/asterisk/sounds/custom/gate1.wav
COPY ./pbx/gate2.gsm /usr/share/asterisk/sounds/custom/gate2.gsm
COPY ./pbx/gate2.wav /usr/share/asterisk/sounds/custom/gate2.wav
COPY ./pbx/docker-entrypoint.sh /docker-entrypoint.sh

RUN chown asterisk:asterisk /etc/asterisk/pjsip.conf
RUN chown asterisk:asterisk /etc/asterisk/extensions.conf
RUN chown asterisk:asterisk /etc/asterisk/manager.conf
RUN chown asterisk:asterisk /etc/asterisk/rtp.conf
RUN chown asterisk:asterisk /etc/asterisk/indications.conf
RUN chown asterisk:asterisk /etc/asterisk/logger.conf
RUN chown asterisk:asterisk /etc/asterisk/modules.conf
RUN chown asterisk:asterisk /var/lib/asterisk/allowed_caller_id.pl
RUN chown asterisk:asterisk /var/lib/asterisk/log.pl
RUN chown asterisk:asterisk /var/lib/asterisk/notify_user.pl
RUN chown asterisk:asterisk /var/lib/asterisk/gate1.call
RUN chown asterisk:asterisk /var/lib/asterisk/gate2.call
RUN chown -R asterisk:asterisk /usr/share/asterisk/sounds/custom/

CMD /docker-entrypoint.sh
