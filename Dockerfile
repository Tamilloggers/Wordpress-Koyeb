FROM wordpress:php8.2-apache

# Set Apache ServerName and suppress startup messages
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    sed -i '/^ErrorLog/d' /etc/apache2/apache2.conf && \
    echo "ErrorLog /proc/self/fd/2" >> /etc/apache2/apache2.conf && \
    echo "CustomLog /proc/self/fd/1 combined" >> /etc/apache2/apache2.conf

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
