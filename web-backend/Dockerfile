FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
	perl \
	cpanminus \
	make \
	ca-certificates \
	libplack-perl \
	libio-socket-ssl-perl \
	starman \
	libjson-pp-perl \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /var/www

# COPY files into container image
COPY app.psgi /var/www/app.psgi
COPY www /var/www/html

EXPOSE 5000

CMD ["starman", "--listen", "0.0.0.0:5000", "--workers", "4", "-I.", "app.psgi"]
