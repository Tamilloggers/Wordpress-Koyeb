#!/bin/bash

# Check Apache is running
if ! pgrep apache2 >/dev/null; then
    echo "Apache is not running"
    exit 1
fi

# Check database connection
if mysql -h "${WORDPRESS_DB_HOST%:*}" \
         -P "${WORDPRESS_DB_HOST#*:}" \
         -u "$WORDPRESS_DB_USER" \
         -p"$WORDPRESS_DB_PASSWORD" \
         --ssl-ca=/etc/mysql-ssl/ca.pem \
         --connect-timeout=5 \
         --execute="SELECT 1;" >/dev/null 2>&1; then
    exit 0
else
    echo "Database connection failed"
    exit 1
fi
