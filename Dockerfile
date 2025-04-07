FROM wordpress:php8.1-apache

RUN a2enmod rewrite

WORKDIR /var/www/html
EXPOSE 80
