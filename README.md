## Build details

docker-compose up --build

To initialize db (only do it first time!):

docker exec -it db /pbx_setup.sh

docker cp mysql_backup.sql.bz2 db:/tmp/

docker exec -it db /nabovarme_import.sh
