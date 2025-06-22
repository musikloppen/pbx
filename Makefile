all: build up

build:
	docker compose build

up:
	docker compose up -d

log:
	docker compose logs -f

down:
	docker compose down

sh:
	docker exec -it pbx /bin/bash

cli:
	docker exec -it pbx /usr/sbin/asterisk -rvvv

setup:
	docker exec -it pbx-db /pbx_setup.sh
	
clean_db:
	rm -fr db_data/*
