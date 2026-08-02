FROM debian:bookworm

# 1. Install system tools, Perl, build toolchain (make), and Debian Perl packages
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
	&& rm -rf /var/lib/apt/lists/*

# 2. Install Net::SMTP via cpanm
RUN cpanm -n Net::SMTP

WORKDIR /var/www

EXPOSE 5000

CMD ["starman", "--listen", "0.0.0.0:5000", "--workers", "4", "-I.", "app.psgi"]
