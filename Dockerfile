FROM microsoft/mssql-tools as mssql
FROM php:7.1-zts-alpine3.8
# persistent / runtime deps
ENV PHPIZE_DEPS \
    autoconf \
    cmake \
    file \
    g++ \
    gcc \
    libc-dev \
    pcre-dev \
    make \
    git \
    pkgconf \
    re2c \
    # for GD
    freetype-dev \
    libpng-dev  \
    libjpeg-turbo-dev
RUN apk add --no-cache --virtual .persistent-deps \
    # for intl extension
    icu-dev \
    # for postgres
    postgresql-dev \
    # for soap
    libxml2-dev \
    # for amqp
    libressl-dev \
    # for GD
    freetype \
    libpng \
    libjpeg-turbo
RUN set -xe \
    # workaround for rabbitmq linking issue
    && ln -s /usr/lib /usr/local/lib64 \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
    && docker-php-ext-configure gd \
        --with-gd \
        --with-freetype-dir=/usr/include/ \
        --with-png-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-configure bcmath --enable-bcmath \
    && docker-php-ext-configure intl --enable-intl \
    && docker-php-ext-configure pcntl --enable-pcntl \
    && docker-php-ext-configure mysqli --with-mysqli \
    && docker-php-ext-configure pdo_mysql --with-pdo-mysql \
    && docker-php-ext-configure pdo_pgsql --with-pgsql \
    && docker-php-ext-configure mbstring --enable-mbstring \
    && docker-php-ext-configure soap --enable-soap \
    && docker-php-ext-install -j$(nproc) \
        gd \
        bcmath \
        intl \
        pcntl \
        mysqli \
        pdo_mysql \
        pdo_pgsql \
        mbstring \
        soap \
        iconv
# Copy configuration
COPY config/php7.ini /usr/local/etc/php/conf.d/
ENV RABBITMQ_VERSION v0.9.0
RUN git clone --branch ${RABBITMQ_VERSION} https://github.com/alanxz/rabbitmq-c.git /tmp/rabbitmq \
        && cd /tmp/rabbitmq \
        && mkdir build && cd build \
        && cmake .. \
        && cmake --build . --target install
ENV PHP_AMQP_VERSION v1.9.3
RUN git clone --branch ${PHP_AMQP_VERSION} https://github.com/pdezwart/php-amqp.git /tmp/php-amqp \
        && cd /tmp/php-amqp \
        && phpize  \
        && ./configure  \
        && make  \
        && make install
# Copy configuration
COPY config/amqp.ini /usr/local/etc/php/conf.d/
ENV PHP_MONGO_VERSION 1.5.3
RUN git clone --branch ${PHP_MONGO_VERSION} https://github.com/mongodb/mongo-php-driver /tmp/php-mongo \
        && cd /tmp/php-mongo \
        && git submodule sync && git submodule update --init \
        && phpize  \
        && ./configure  \
        && make  \
        && make install \
        && make test
COPY config/mongodb.ini /usr/local/etc/php/conf.d/
ENV PHP_REDIS_VERSION 4.2.0
RUN git clone --branch ${PHP_REDIS_VERSION} https://github.com/phpredis/phpredis /tmp/phpredis \
        && cd /tmp/phpredis \
        && phpize  \
        && ./configure  \
        && make  \
        && make install \
        && make test
# Copy configuration
COPY config/redis.ini /usr/local/etc/php/conf.d/
ENV PHP_PROTOBUF_VERSION v0.12.3
RUN git clone --branch ${PHP_PROTOBUF_VERSION} https://github.com/allegro/php-protobuf /tmp/phpprotobuf \
        && cd /tmp/phpprotobuf \
        && phpize  \
        && ./configure  \
        && make  \
        && make install \
        && make test
# Copy configuration
COPY config/protobuf.ini /usr/local/etc/php/conf.d/
RUN pecl install swoole
COPY config/swoole.ini /usr/local/etc/php/conf.d/
ENV PHP_PTHREADS_VERSION master
RUN git clone --branch ${PHP_PTHREADS_VERSION} https://github.com/krakjoe/pthreads.git /tmp/php-pthreads \
         && cd /tmp/php-pthreads \
         && git reset --hard 2fd526627e5606e8d7d4eb6a6339d98b5c2bfcec \
         && phpize  \
         && ./configure  \
         && make  \
         && make install \
         && make test
COPY config/pthreads.ini /usr/local/etc/php/conf.d/
RUN apk del .build-deps \
    && rm -rf /tmp/* \
    && rm -rf /app \
    && mkdir /app
COPY config/php-cli.ini /usr/local/etc/php/php.ini
VOLUME ["/app"]
WORKDIR /app

########### START Composer Instalation ###################

# Environmental Variables
ENV COMPOSER_HOME /root/composer
ENV COMPOSER_VERSION master
ENV COMPOSER_ALLOW_SUPERUSER 1
RUN set -xe \
    && apk add --no-cache --virtual .persistent-deps \
        zlib-dev \
        libzip-dev \
        git \
        unzip \
    && docker-php-ext-install \
        zip \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer global require hirak/prestissimo
# Set up the command arguments
CMD ["-"]
ENTRYPOINT ["composer", "--ansi"]

########### END Composer Instalation ###################

########### START sqlsrv Instalation ###################

COPY --from=mssql /opt/microsoft/ /opt/microsoft/
COPY --from=mssql /opt/mssql-tools/ /opt/mssql-tools/
COPY --from=mssql /usr/lib/libmsodbcsql-13.so /usr/lib/libmsodbcsql-13.so

RUN set -xe \
    && apk add --no-cache --virtual .persistent-deps \
        freetds \
        unixodbc \
    && apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        unixodbc-dev \
        freetds-dev \
        libstdc++ \
        gcc \
        g++ \
    && docker-php-source extract \
    && docker-php-ext-install pdo_dblib \
    && pecl install \
        sqlsrv \
        pdo_sqlsrv \
    && docker-php-ext-enable --ini-name 30-sqlsrv.ini sqlsrv \
    && docker-php-ext-enable --ini-name 35-pdo_sqlsrv.ini pdo_sqlsrv \
    && docker-php-source delete \
    && apk del .build-deps
    
    ########### END sqlsrv Instalation ###################
