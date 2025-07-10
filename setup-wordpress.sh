#!/bin/bash
set -e

WP_CONFIG=/var/www/html/wp-config.php

# Set Apache ServerName
echo "ServerName ${APACHE_SERVERNAME}" >> /etc/apache2/apache2.conf

# Configure wp-config.php
if [ ! -f "$WP_CONFIG" ]; then
    echo "Generating wp-config.php with SSL support..."
    cp /var/www/html/wp-config-sample.php "$WP_CONFIG"

    # Parse host and port
    DB_HOST=${WORDPRESS_DB_HOST%:*}
    DB_PORT=${WORDPRESS_DB_HOST#*:}
    
    # Database configuration
    sed -i "s/database_name_here/$WORDPRESS_DB_NAME/g" "$WP_CONFIG"
    sed -i "s/username_here/$WORDPRESS_DB_USER/g" "$WP_CONFIG"
    sed -i "s/password_here/$WORDPRESS_DB_PASSWORD/g" "$WP_CONFIG"
    sed -i "s/localhost/$DB_HOST/g" "$WP_CONFIG"

    # Add custom port
    echo "define('DB_PORT', '$DB_PORT');" >> "$WP_CONFIG"

    # Add SSL configuration
    echo "// Aiven MySQL SSL Configuration" >> "$WP_CONFIG"
    echo "define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);" >> "$WP_CONFIG"
    echo "define('MYSQL_SSL_CA', '${MYSQL_SSL_CA}');" >> "$WP_CONFIG"
    echo "define('MYSQL_SSL_CERT', '${MYSQL_SSL_CERT}');" >> "$WP_CONFIG"
    echo "define('MYSQL_SSL_KEY', '${MYSQL_SSL_KEY}');" >> "$WP_CONFIG"

    # Security keys
    for KEY in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
        sed -i "s/put your unique phrase here/$(pwgen -1 -s 64)/" "$WP_CONFIG"
    done

    # Debug mode
    sed -i "s/define( 'WP_DEBUG', false );/define( 'WP_DEBUG', ${WP_DEBUG:-false} );/" "$WP_CONFIG"

    # Site URLs
    echo "define('WP_HOME', '${WP_HOME}');" >> "$WP_CONFIG"
    echo "define('WP_SITEURL', '${WP_HOME}');" >> "$WP_CONFIG"

    chown www-data:www-data "$WP_CONFIG"
    chmod 640 "$WP_CONFIG"  # More restrictive permissions for SSL
fi

# Copy SSL certificates to container
if [ -f "${MYSQL_SSL_CA}" ]; then
    mkdir -p /etc/mysql-ssl
    cp "${MYSQL_SSL_CA}" "${MYSQL_SSL_CERT}" "${MYSQL_SSL_KEY}" /etc/mysql-ssl/
    chmod 600 /etc/mysql-ssl/*
    chown -R www-data:www-data /etc/mysql-ssl
fi

exec "$@"
