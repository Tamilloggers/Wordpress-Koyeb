#!/bin/bash
set -e

WP_CONFIG=/var/www/html/wp-config.php

# Set Apache ServerName (if not already set)
if ! grep -q "ServerName ${APACHE_SERVERNAME}" /etc/apache2/apache2.conf; then
    echo "ServerName ${APACHE_SERVERNAME}" >> /etc/apache2/apache2.conf
fi

# Configure wp-config.php if it doesn't exist
if [ ! -f "$WP_CONFIG" ]; then
    echo "Generating wp-config.php..."
    cp /var/www/html/wp-config-sample.php "$WP_CONFIG"

    # Database configuration
    sed -i "s/database_name_here/$WORDPRESS_DB_NAME/g" "$WP_CONFIG"
    sed -i "s/username_here/$WORDPRESS_DB_USER/g" "$WP_CONFIG"
    sed -i "s/password_here/$WORDPRESS_DB_PASSWORD/g" "$WP_CONFIG"
    sed -i "s/localhost/$WORDPRESS_DB_HOST/g" "$WP_CONFIG"

    # Security keys
    for KEY in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
        sed -i "s/put your unique phrase here/$(pwgen -1 -s 64)/" "$WP_CONFIG"
    done

    # Debug mode
    sed -i "s/define( 'WP_DEBUG', false );/define( 'WP_DEBUG', ${WP_DEBUG:-false} );/" "$WP_CONFIG"

    # Optional URL settings
    if [ -n "$WP_HOME" ]; then
        echo "define('WP_HOME', '$WP_HOME');" >> "$WP_CONFIG"
        echo "define('WP_SITEURL', '$WP_HOME');" >> "$WP_CONFIG"
    fi

    # File permissions
    chown www-data:www-data "$WP_CONFIG"
    chmod 644 "$WP_CONFIG"
fi

# Start Apache
exec "$@"
