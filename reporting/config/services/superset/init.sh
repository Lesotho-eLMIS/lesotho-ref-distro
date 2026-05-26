#!/bin/bash

set -e

: ${SUPERSET_ADMIN_USERNAME:?"Need to set SUPERSET_ADMIN_USERNAME"}
: ${SUPERSET_ADMIN_PASSWORD:?"Need to set SUPERSET_ADMIN_PASSWORD"}
: ${SUPERSET_VERSION:?"Need to set SUPERSET_VERSION"}
: ${APP_DIR:?"Need to set APP_DIR"}

CONFIG_DIR="/etc/superset"

# Custom code
if [ -d "$CONFIG_DIR/app-customizations/$SUPERSET_VERSION" ]; then
  echo "Applying customizations for version $SUPERSET_VERSION"
  cp -rf $CONFIG_DIR/app-customizations/$SUPERSET_VERSION/* $APP_DIR

  # UI build if needed
  if [ -f "$APP_DIR/superset-frontend/js_build.sh" ]; then
    echo "Running JS build for customizations"
    $APP_DIR/superset-frontend/js_build.sh
  fi
else
  echo "No customizations found for version $SUPERSET_VERSION, skipping."
fi

# wait for postgres
#until PGPASSWORD=$POSTGRES_PASSWORD psql -h "db" -p "5432" -U "$POSTGRES_USER" -d "superset" -c '\q'; do
until PGPASSWORD=$POSTGRES_PASSWORD psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "open_lmis_reporting" -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 5
done

>&2 echo "Postgres is up"

# App initialization
flask fab create-admin --username ${SUPERSET_ADMIN_USERNAME} --firstname Admin --lastname Admin --email noreply --password ${SUPERSET_ADMIN_PASSWORD} &&

superset db upgrade &&
superset import-directory -o $CONFIG_DIR/import_dir &&
superset legacy-import-datasources -p $CONFIG_DIR/datasources/database.yaml &&
#superset import-datasources -p $CONFIG_DIR/datasources/exported_datasets.zip &&
#superset import-dashboards -u ${SUPERSET_ADMIN_USERNAME} -p $CONFIG_DIR/dashboards/openlmis_uat_dashboards.zip &&
superset import-dashboards -u ${SUPERSET_ADMIN_USERNAME} -p $CONFIG_DIR/dashboards/openlmis_uat_dashboards_db_on_host.zip &&
#superset import_dashboards -u ${SUPERSET_ADMIN_USERNAME} -p $CONFIG_DIR/dashboards/exported_dashboards.zip &&
#superset import_dashboards -u ${SUPERSET_ADMIN_USERNAME} -p $CONFIG_DIR/dashboards/elmis_superset_dahboards_04042025_1502.zip &&
superset init &&

gunicorn $GUNICORN_CMD_ARGS "superset.app:create_app()"
