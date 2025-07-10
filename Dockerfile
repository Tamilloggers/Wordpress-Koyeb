FROM wordpress:php8.2-apache

# Install dependencies
RUN apt-get update && apt-get install -y \
    mariadb-client \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create SSL directory
RUN mkdir -p /etc/mysql-ssl && \
    chown www-data:www-data /etc/mysql-ssl && \
    chmod 750 /etc/mysql-ssl

# Copy scripts and CA cert
COPY setup-wordpress.sh healthcheck.sh /usr/local/bin/
COPY aiven-ca.pem /etc/mysql-ssl/ca.pem
RUN chmod +x /usr/local/bin/*.sh && \
    chmod 600 /etc/mysql-ssl/ca.pem && \
    chown www-data:www-data /etc/mysql-ssl/ca.pem

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["setup-wordpress.sh"]
CMD ["apache2-foreground"]
