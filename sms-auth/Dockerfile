FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
	perl \
	cpanminus \
	make \
	ca-certificates \
	libdbd-mariadb-perl \
	libdbi-perl \
	libplack-perl \
	libplack-app-proxy-perl \
	liblwp-protocol-https-perl \
	libio-socket-ssl-perl \
	starman \
	libcgi-simple-perl \
	libmath-random-secure-perl \
	libjson-pp-perl \
	libemail-mime-perl \
	libnumber-phone-perl \
	&& rm -rf /var/lib/apt/lists/*

RUN cpanm -n Net::SMTP

# Copy shared library into standard Perl @INC search directory
COPY ./lib/My /usr/share/perl5/My

WORKDIR /var/www

# Copy sms-auth service files
COPY ./sms-auth/SMSAuth.pm /var/www/SMSAuth.pm
COPY ./sms-auth/app.psgi /var/www/app.psgi
COPY ./sms-auth/www /var/www/www

EXPOSE 5000

CMD ["starman", "--listen", "0.0.0.0:5000", "--workers", "4", "-I.", "app.psgi"]
