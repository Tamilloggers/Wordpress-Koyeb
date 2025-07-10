FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV WORDPRESS_VERSION=6.5.3

RUN apt-get update && apt-get install -y \
    apache2 \
    curl \
    unzip \
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
    && rm -rf /var/lib/apt/lists/*

RUN curl -o /tmp/wordpress.zip https://wordpress.org/wordpress-${WORDPRESS_VERSION}.zip && \
    unzip /tmp/wordpress.zip -d /tmp && \
    mv /tmp/wordpress/* /var/www/html && \
    rm -f /var/www/html/index.html && \
    rm -rf /tmp/*

RUN chown -R www-data:www-data /var/www/html && \
    chmod -R 755 /var/www/html

RUN a2enmod rewrite

RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf

RUN echo '<Directory /var/www/html/>\n\
    AllowOverride All\n\
</Directory>' >> /etc/apache2/apache2.conf

EXPOSE 80

CMD ["apachectl", "-D", "FOREGROUND"]
