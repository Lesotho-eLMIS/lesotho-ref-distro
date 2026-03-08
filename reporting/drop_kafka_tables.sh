#!/bin/bash
PGPASSWORD='postgres' psql -U postgres -d open_lmis_reporting -c "
DO \$\$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE tablename LIKE 'kafka%') LOOP
        EXECUTE 'DROP TABLE ' || r.tablename || ' CASCADE;';
    END LOOP;
END \$\$;
"
