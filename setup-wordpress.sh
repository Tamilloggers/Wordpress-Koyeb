#!/bin/bash
set -e

WP_CONFIG=/var/www/html/wp-config.php
SSL_DIR=/etc/mysql-ssl

# Ensure SSL directory exists
mkdir -p "$SSL_DIR" && chmod 750 "$SSL_DIR" && chown www-data:www-data "$SSL_DIR"

# Always refresh CA certificate (in case it changed)
if [ -f "${MYSQL_SSL_CA}" ]; then
  cp "${MYSQL_SSL_CA}" "$SSL_DIR/ca.pem"
  chmod 600 "$SSL_DIR/ca.pem"
  chown www-data:www-data "$SSL_DIR/ca.pem"
fi

# Reset config if forced or missing
if [ "${RESET_WP_CONFIG}" = "true" ] || [ ! -f "$WP_CONFIG" ]; then
  echo "Initializing or resetting wp-config.php..."
  [ -f "$WP_CONFIG" ] && rm -f "$WP_CONFIG"
  
  cp /var/www/html/wp-config-sample.php "$WP_CONFIG"

  # Parse host:port
  DB_HOST="${WORDPRESS_DB_HOST%:*}"
  DB_PORT="${WORDPRESS_DB_HOST#*:}"

  # Apply configuration
  sed -i "s/database_name_here/$WORDPRESS_DB_NAME/g" "$WP_CONFIG"
  sed -i "s/username_here/$WORDPRESS_DB_USER/g" "$WP_CONFIG"
  sed -i "s/password_here/$WORDPRESS_DB_PASSWORD/g" "$WP_CONFIG"
  sed -i "s/localhost/$DB_HOST/g" "$WP_CONFIG"

  # Add custom configurations
  cat >> "$WP_CONFIG" << EOF
  
// Custom Configuration
define('DB_PORT', '$DB_PORT');
define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);
define('MYSQL_SSL_CA', '$SSL_DIR/ca.pem');

// Security Keys
EOF

  # Generate salts
  curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> "$WP_CONFIG"

  # Debug settings
  echo "define('WP_DEBUG', ${WP_DEBUG:-false});" >> "$WP_CONFIG"
  [ -n "$WP_HOME" ] && echo "define('WP_HOME', '$WP_HOME');" >> "$WP_CONFIG"
  [ -n "$WP_HOME" ] && echo "define('WP_SITEURL', '$WP_HOME');" >> "$WP_CONFIG"

  # Set permissions
  chown www-data:www-data "$WP_CONFIG"
  chmod 640 "$WP_CONFIG"
  echo "wp-config.php has been configured."
else
  echo "Using existing wp-config.php (set RESET_WP_CONFIG=true to regenerate)"
fi

exec "$@"
