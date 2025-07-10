#!/bin/bash

DB_HOST="${WORDPRESS_DB_HOST%:*}"
DB_PORT="${WORDPRESS_DB_HOST#*:}"

if mysql -h "$DB_HOST" -P "$DB_PORT" -u "$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" \
  --ssl-ca=/etc/mysql-ssl/ca.pem --connect-timeout=5 -e "SELECT 1;" >/dev/null 2>&1; then
  exit 0
else
  echo "Database connection failed"
  exit 1
fi
