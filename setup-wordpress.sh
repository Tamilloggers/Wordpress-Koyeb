#!/bin/bash
set -eo pipefail

WP_CONFIG="/var/www/html/wp-config.php"
WP_CONFIG_SAMPLE="/usr/src/wordpress/wp-config-sample.php"

# Wait for WordPress files to be available
while [ ! -f "$WP_CONFIG_SAMPLE" ]; do
    echo "Waiting for WordPress files to be copied..."
    sleep 2
done

# Configure wp-config.php if it doesn't exist
if [ ! -f "$WP_CONFIG" ]; then
    echo "Initializing wp-config.php..."
    cp "$WP_CONFIG_SAMPLE" "$WP_CONFIG"

    # Parse host and port
    DB_HOST="${WORDPRESS_DB_HOST%:*}"
    DB_PORT="${WORDPRESS_DB_HOST#*:}"

    # Apply configuration
    sed -i "s/database_name_here/$WORDPRESS_DB_NAME/g" "$WP_CONFIG"
    sed -i "s/username_here/$WORDPRESS_DB_USER/g" "$WP_CONFIG"
    sed -i "s/password_here/$WORDPRESS_DB_PASSWORD/g" "$WP_CONFIG"
    sed -i "s/localhost/$DB_HOST/g" "$WP_CONFIG"

    # Add custom configuration
    cat >> "$WP_CONFIG" << 'EOWPCONFIG'

// Aiven MySQL Configuration
define('DB_PORT', '$DB_PORT');
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL | MYSQLI_CLIENT_SSL_VERIFY_SERVER_CERT);
define('MYSQL_SSL_CA', '/etc/mysql-ssl/ca.pem');
define('WP_DEBUG', ${WORDPRESS_DEBUG:-false});

// Security Keys
EOWPCONFIG

    # Generate security salts
    curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> "$WP_CONFIG"

    # Set permissions
    chown www-data:www-data "$WP_CONFIG"
    chmod 640 "$WP_CONFIG"
    echo "wp-config.php configured successfully."
fi

exec "$@"
