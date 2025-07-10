#!/bin/bash
set -eo pipefail

WP_CONFIG=/var/www/html/wp-config.php
SSL_DIR=/etc/mysql-ssl

# Initialize SSL directory
mkdir -p "$SSL_DIR"
chown www-data:www-data "$SSL_DIR"
chmod 750 "$SSL_DIR"

# Load CA certificate if provided
if [ -n "$MYSQL_SSL_CA" ]; then
    cp "$MYSQL_SSL_CA" "$SSL_DIR/ca.pem"
    chmod 600 "$SSL_DIR/ca.pem"
    chown www-data:www-data "$SSL_DIR/ca.pem"
fi

# Configure wp-config.php if missing or reset requested
if [ "${RESET_WP_CONFIG}" = "true" ] || [ ! -f "$WP_CONFIG" ]; then
    echo "Initializing wp-config.php..."
    [ -f "$WP_CONFIG" ] && rm -f "$WP_CONFIG"
    cp /var/www/html/wp-config-sample.php "$WP_CONFIG"

    # Parse host and port
    DB_HOST="${WORDPRESS_DB_HOST%:*}"
    DB_PORT="${WORDPRESS_DB_HOST#*:}"

    # Apply basic configuration
    sed -i "s/database_name_here/$WORDPRESS_DB_NAME/g" "$WP_CONFIG"
    sed -i "s/username_here/$WORDPRESS_DB_USER/g" "$WP_CONFIG"
    sed -i "s/password_here/$WORDPRESS_DB_PASSWORD/g" "$WP_CONFIG"
    sed -i "s/localhost/$DB_HOST/g" "$WP_CONFIG"

    # Add custom configuration
    cat >> "$WP_CONFIG" << 'EOWPCONFIG'

// Custom Configuration for Aiven MySQL
define('DB_PORT', '${DB_PORT}');
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL | MYSQLI_CLIENT_SSL_VERIFY_SERVER_CERT);
define('MYSQL_SSL_CA', '/etc/mysql-ssl/ca.pem');
define('DB_SSL', true);

// Security Keys
EOWPCONFIG

    # Generate security salts
    curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> "$WP_CONFIG"

    # Debug settings
    echo "define('WP_DEBUG', ${WP_DEBUG:-false});" >> "$WP_CONFIG"
    [ -n "$WP_HOME" ] && echo "define('WP_HOME', '$WP_HOME');" >> "$WP_CONFIG"
    [ -n "$WP_HOME" ] && echo "define('WP_SITEURL', '$WP_HOME');" >> "$WP_CONFIG"

    # Final permissions
    chown www-data:www-data "$WP_CONFIG"
    chmod 640 "$WP_CONFIG"
    echo "wp-config.php configured successfully."
fi

# Verify database connection
echo "Verifying database connection..."
if ! mysql -h "${WORDPRESS_DB_HOST%:*}" \
           -P "${WORDPRESS_DB_HOST#*:}" \
           -u "$WORDPRESS_DB_USER" \
           -p"$WORDPRESS_DB_PASSWORD" \
           --ssl-ca="$SSL_DIR/ca.pem" \
           --connect-timeout=10 \
           --execute="SELECT 1;" >/dev/null 2>&1; then
    echo "ERROR: Database connection failed!" >&2
    echo "Attempting to display error details..." >&2
    mysql -h "${WORDPRESS_DB_HOST%:*}" \
          -P "${WORDPRESS_DB_HOST#*:}" \
          -u "$WORDPRESS_DB_USER" \
          -p"$WORDPRESS_DB_PASSWORD" \
          --ssl-ca="$SSL_DIR/ca.pem" \
          --connect-timeout=5 \
          --execute="SELECT 1;" || true
    exit 1
fi

exec "$@"
