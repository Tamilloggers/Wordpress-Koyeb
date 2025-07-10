FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV WORDPRESS_VERSION=6.5.3
ENV APACHE_SERVERNAME=localhost

# Install dependencies with SSL support
RUN apt-get update && apt-get install -y \
    apache2 \
    curl \
    unzip \
    less \
    php \
    php-mysql \
    php-curl \
    php-gd \
    php-xml \
    php-mbstring \
    php-zip \
    php-soap \
    php-intl \
    libapache2-mod-php \
    mariadb-client \
    pwgen \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Create SSL and healthcheck directories
RUN mkdir -p /etc/mysql-ssl /healthchecks && \
    chown www-data:www-data /etc/mysql-ssl && \
    chmod 750 /etc/mysql-ssl

# Install WordPress
RUN curl -o /tmp/wordpress.zip https://wordpress.org/wordpress-${WORDPRESS_VERSION}.zip && \
    unzip /tmp/wordpress.zip -d /tmp && \
    mv /tmp/wordpress/* /var/www/html && \
    rm -rf /tmp/*

# Copy scripts
COPY setup-wordpress.sh healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Configure Apache
RUN echo "ServerName ${APACHE_SERVERNAME}" >> /etc/apache2/apache2.conf && \
    a2enmod rewrite ssl && \
    echo '<Directory /var/www/html/>\n\
    AllowOverride All\n\
</Directory>' >> /etc/apache2/apache2.conf

# Set permissions
RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 750 /var/www/html

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

ENTRYPOINT ["setup-wordpress.sh"]
CMD ["apachectl", "-D", "FOREGROUND"]
