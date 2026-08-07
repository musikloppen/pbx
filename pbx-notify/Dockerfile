FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
	perl \
	libdbi-perl \
	libdbd-mariadb-perl \
	libemail-mime-perl \
	libemail-sender-perl \
	libnumber-phone-perl \
	ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# Copy shared Perl module into system @INC
COPY ./lib/My /usr/share/perl5/My

# Copy script to container
COPY pbx-notify/notify_user.pl /usr/local/bin/notify_user.pl
RUN chmod +x /usr/local/bin/notify_user.pl

ENTRYPOINT ["/usr/local/bin/notify_user.pl"]
