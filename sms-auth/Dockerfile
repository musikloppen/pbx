FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
	perl \
	cpanminus \
	make \
	ca-certificates \
	libdbd-mysql-perl \
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
	&& rm -rf /var/lib/apt/lists/*

RUN cpanm -n Net::SMTP

WORKDIR /var/www

COPY app.psgi /var/www/app.psgi
COPY SMSAuth.pm /var/www/SMSAuth.pm
COPY www /var/www

EXPOSE 5000

CMD ["starman", "--listen", "0.0.0.0:5000", "--workers", "4", "-I.", "app.psgi"]
