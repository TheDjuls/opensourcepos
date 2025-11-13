# Etapa base: imagen principal con PHP y Apache
FROM php:8.2-apache AS ospos
LABEL maintainer="jekkos"

# Instala dependencias necesarias del sistema
RUN apt-get update && apt-get install -y \
    libicu-dev \
    libgd-dev \
 && a2enmod rewrite \
 && docker-php-ext-install mysqli bcmath intl gd \
 && rm -rf /var/lib/apt/lists/*

# Configura la zona horaria de PHP
RUN echo "date.timezone = \"\${PHP_TIMEZONE}\"" > /usr/local/etc/php/conf.d/timezone.ini

# Copia la app
WORKDIR /app
COPY . /app

# Configura el sitio web
RUN ln -s /app/*[^public] /var/www \
 && rm -rf /var/www/html \
 && ln -nsf /app/public /var/www/html

# Permisos correctos para carpetas de escritura
RUN chmod -R 770 /app/writable/uploads /app/writable/logs /app/writable/cache \
 && chown -R www-data:www-data /app

# -------------------
# Etapa de test
# -------------------
FROM ospos AS ospos_test

COPY --from=composer /usr/bin/composer /usr/bin/composer

RUN apt-get update && apt-get install -y libzip-dev wget git \
 && wget https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh -O /bin/wait-for-it.sh \
 && chmod +x /bin/wait-for-it.sh \
 && docker-php-ext-install zip \
 && composer install -d /app

WORKDIR /app/tests
CMD ["/app/vendor/phpunit/phpunit/phpunit", "/app/test/helpers"]

# -------------------
# Etapa de desarrollo (con Xdebug)
# -------------------
FROM ospos AS ospos_dev

# Argumentos opcionales para crear usuario (Render puede no enviarlos)
ARG USERID=1000
ARG GROUPID=1000

# Crea usuario y grupo si no existen
RUN echo "Adding user uid ${USERID} with gid ${GROUPID}" \
 && groupadd -g ${GROUPID} ospos || true \
 && useradd -m -u ${USERID} -g ${GROUPID} ospos || true

# Instala y configura Xdebug
RUN yes | pecl install xdebug \
 && echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/xdebug.ini \
 && echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/xdebug.ini \
 && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/xdebug.ini \
 && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/xdebug.ini

# Cambia al usuario no root
USER ospos

WORKDIR /app
