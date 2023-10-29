all: build up

build:
	docker-compose build

up:
	docker network create pbx
	docker-compose up -d

log:
	docker-compose logs -f

down:
	docker-compose down
	docker network rm pbx

sh:
	docker exec -it pbx /bin/bash

cli:
	docker exec -it pbx /usr/sbin/asterisk -rvvv

setup:
	docker exec -it db /pbx_setup.sh
	
clean_db:
	rm -fr db_data/*
