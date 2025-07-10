FROM wordpress:php8.2-apache

# Set Apache configuration
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    echo "DirectoryIndex index.php index.html" >> /etc/apache2/apache2.conf && \
    sed -i '/<Directory \/var\/www\/html>/,/<\/Directory>/ s/Options Indexes FollowSymLinks/Options FollowSymLinks/' /etc/apache2/apache2.conf

# Verify WordPress files exist
RUN ls -la /usr/src/wordpress/ # Debug file existence

# Copy WordPress files properly (only if not using official image's mechanism)
COPY --from=wordpress:php8.2-apache /usr/src/wordpress/ /var/www/html/


# Install MySQL client for health checks
RUN apt-get update && apt-get install -y mariadb-client && rm -rf /var/lib/apt/lists/*

# Configure SSL directory
RUN mkdir -p /etc/mysql-ssl && \
    chown www-data:www-data /etc/mysql-ssl && \
    chmod 750 /etc/mysql-ssl

# Copy configuration files
COPY setup-wordpress.sh healthcheck.sh /usr/local/bin/
COPY aiven-ca.pem /etc/mysql-ssl/
RUN chmod +x /usr/local/bin/*.sh && \
    chmod 600 /etc/mysql-ssl/aiven-ca.pem && \
    chown www-data:www-data /etc/mysql-ssl/aiven-ca.pem

# Health check configuration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["setup-wordpress.sh"]
CMD ["apache2-foreground"]
