#!/bin/bash

# init DB	- cat psql-init.sql | psql -U postgres
# backup DB	- pg_dump -CsU secondsight secondsight > backup.sql
# restore DB	- cat backup.sql | psql -U postgres

DBCHECK=`PGPASSWORD=admin psql -U postgres -h postgres -Atc "SELECT count(datname) FROM pg_catalog.pg_database WHERE datname='secondsight'"`

if [ $DBCHECK = 0 ]
then
	echo "Second Sight database not found, initializing..."
	export PGPASSWORD=admin
	cat psql-init.sql | psql -U postgres -h postgres
else
	echo "Second Sight database found"
fi

