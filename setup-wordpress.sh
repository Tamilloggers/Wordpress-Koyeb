#!/bin/bash
set -eo pipefail

# Configure Apache logging to stdout/stderr
exec > >(tee -i /proc/self/fd/1)
exec 2> >(tee -i /proc/self/fd/2 >&2)

# Path configurations
WP_ROOT="/var/www/html"
WP_CONFIG="${WP_ROOT}/wp-config.php"
WP_SOURCE="/usr/src/wordpress"
SSL_DIR="/etc/mysql-ssl"

# Ensure required directories exist
mkdir -p "$SSL_DIR"
chown www-data:www-data "$SSL_DIR"
chmod 750 "$SSL_DIR"

# Load CA certificate if provided
if [ -n "$MYSQL_SSL_CA" ]; then
    echo "Configuring SSL certificate..."
    cp "$MYSQL_SSL_CA" "$SSL_DIR/ca.pem"
    chmod 600 "$SSL_DIR/ca.pem"
    chown www-data:www-data "$SSL_DIR/ca.pem"
fi

# Verify WordPress core files exist
if [ ! -f "$WP_SOURCE/wp-config-sample.php" ]; then
    echo "ERROR: WordPress source files not found in $WP_SOURCE" >&2
    exit 1
fi

# Copy WordPress files if directory is empty
if [ ! -f "$WP_ROOT/index.php" ]; then
    echo "Initializing WordPress files..."
    cp -a "$WP_SOURCE/." "$WP_ROOT/"
    chown -R www-data:www-data "$WP_ROOT"
fi

# Configure wp-config.php if missing or reset requested
if [ "${RESET_WP_CONFIG}" = "true" ] || [ ! -f "$WP_CONFIG" ]; then
    echo "Configuring wp-config.php..."
    
    [ -f "$WP_CONFIG" ] && rm -f "$WP_CONFIG"
    cp "$WP_SOURCE/wp-config-sample.php" "$WP_CONFIG"

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

// Aiven MySQL Configuration
define('DB_PORT', '${DB_PORT}');
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL | MYSQLI_CLIENT_SSL_VERIFY_SERVER_CERT);
define('MYSQL_SSL_CA', '/etc/mysql-ssl/ca.pem');
define('WP_DEBUG', ${WORDPRESS_DEBUG:-false});

// Security Keys
EOWPCONFIG

    # Generate security salts
    echo "Generating authentication keys..."
    curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> "$WP_CONFIG"

    # Optional URL settings
    if [ -n "$WP_HOME" ]; then
        echo "Configuring site URLs..."
        echo "define('WP_HOME', '$WP_HOME');" >> "$WP_CONFIG"
        echo "define('WP_SITEURL', '$WP_HOME');" >> "$WP_CONFIG"
    fi

    # Final permissions
    chown www-data:www-data "$WP_CONFIG"
    chmod 640 "$WP_CONFIG"
fi

# Verify database connection
echo "Verifying database connection..."
max_retries=5
retry_count=0

until mysql -h "${WORDPRESS_DB_HOST%:*}" \
            -P "${WORDPRESS_DB_HOST#*:}" \
            -u "$WORDPRESS_DB_USER" \
            -p"$WORDPRESS_DB_PASSWORD" \
            --ssl-ca="$SSL_DIR/ca.pem" \
            --connect-timeout=5 \
            --execute="SELECT 1;" >/dev/null 2>&1
do
    retry_count=$((retry_count+1))
    if [ $retry_count -ge $max_retries ]; then
        echo "ERROR: Failed to connect to database after $max_retries attempts" >&2
        echo "Last error:" >&2
        mysql -h "${WORDPRESS_DB_HOST%:*}" \
              -P "${WORDPRESS_DB_HOST#*:}" \
              -u "$WORDPRESS_DB_USER" \
              -p"$WORDPRESS_DB_PASSWORD" \
              --ssl-ca="$SSL_DIR/ca.pem" \
              --connect-timeout=2 \
              --execute="SELECT 1;" || true
        exit 1
    fi
    echo "Database not ready, retrying ($retry_count/$max_retries)..."
    sleep 5
done

# Fix permissions (in case of volume mounts)
echo "Ensuring proper permissions..."
find "$WP_ROOT" -type d -exec chmod 755 {} \;
find "$WP_ROOT" -type f -exec chmod 644 {} \;
chown -R www-data:www-data "$WP_ROOT"

# Start Apache
echo "Starting Apache..."
exec apache2-foreground "$@"
