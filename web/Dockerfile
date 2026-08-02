FROM debian:bookworm

# 1. Install system tools, Perl, cpanminus, and pre-compiled Debian Perl packages
RUN apt-get update && apt-get install -y --no-install-recommends \
	perl \
	cpanminus \
	gcc \
	make \
	libc6-dev \
	libdbd-mysql-perl \
	libdbd-mariadb-perl \
	libdbi-perl \
	ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# 2. Install remaining CPAN modules (DBD::mysql is already installed via apt)
RUN cpanm -n \
	Plack \
	Starman \
	CGI::Simple::Cookie \
	Math::Random::Secure \
	Net::SMTP

WORKDIR /var/www

EXPOSE 5000

CMD ["starman", "--listen", "0.0.0.0:5000", "--workers", "4", "-I.", "app.psgi"]
