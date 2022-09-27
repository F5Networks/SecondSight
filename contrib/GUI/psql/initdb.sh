#!/bin/bash

# init DB	- cat psql-init.sql | psql -U postgres
# update schema	- cat psql-schema.sql | psql -U secondsight secondsight
# set data	- cat psql-data.sql | psql -U secondsight secondsight
# backup DB	- pg_dump -CsU secondsight secondsight > backup.sql
# restore DB	- cat backup.sql | psql -U postgres

export PGPASSWORD=admin
DBCHECK=`psql -U postgres -h postgres -Atc "SELECT count(datname) FROM pg_catalog.pg_database WHERE datname='secondsight'"`

if [ $DBCHECK = 0 ]
then
	echo "Second Sight database not found: initializing..."
	cat psql-init.sql | psql -U postgres -h postgres
	cat psql-schema.sql | psql -U secondsight -h postgres secondsight
	cat psql-data.sql | psql -U secondsight -h postgres secondsight
else
	echo "Second Sight database found: checking and updating schema..."
	cat psql-schema.sql | psql -U secondsight -h postgres secondsight
fi
