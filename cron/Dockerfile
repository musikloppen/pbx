FROM debian:bookworm

LABEL maintainer="Kristoffer Ek <stoffer@skulp.net>"

USER root

# Install cron, perl, and MySQL DBI modules
RUN apt-get update && apt-get install -y --no-install-recommends \
	cron \
	perl \
	libdbi-perl \
	libdbd-mariadb-perl \
	&& rm -rf /var/lib/apt/lists/*

COPY crontab /etc/crontab
COPY clean_logs.pl /usr/local/bin/clean_logs.pl
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN chmod 0644 /etc/crontab && \
	chmod +x /usr/local/bin/clean_logs.pl /docker-entrypoint.sh && \
	touch /var/log/cron.log

ENTRYPOINT ["/docker-entrypoint.sh"]
