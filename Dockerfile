# PHP 7.1, Apache 2.4.25, Debian 9
# check apache version: apachectl -V
# SqlServer Driver: 17 - Compativel com Debian 9 e PHP 7
# check os version: cat /etc/os-release or cat /proc/version
FROM php:7.1-apache

ENV ACCEPT_EULA=Y

# Microsoft SQL Server Prerequisites
RUN apt-get update \
 && apt-get install -y nano gnupg \
 && curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
 && curl https://packages.microsoft.com/config/debian/9/prod.list \
     > /etc/apt/sources.list.d/mssql-release.list \
 && apt-get install -y --no-install-recommends \
     locales \
     apt-transport-https \
 && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
 && locale-gen \
 && apt-get update \
 && apt-get -y --no-install-recommends install \
     msodbcsql17 \
     unixodbc-dev \
     libldap2-dev \
     libxml2-dev \
     libmcrypt-dev \
     libzip-dev \
     zip \
     git \
 && rm -rf /var/lib/apt/lists/* \
 && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
 && docker-php-ext-configure mcrypt --with-mcrypt \
 && docker-php-ext-configure zip --with-libzip

RUN docker-php-ext-install ldap mbstring mysqli soap pdo pdo_mysql mcrypt zip \
 && pecl install sqlsrv pdo_sqlsrv xdebug \
 && docker-php-ext-enable sqlsrv pdo_sqlsrv xdebug

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
 && php -r "if (hash_file('SHA384', 'composer-setup.php') === '48e3236262b34d30969dca3c37281b3b4bbe3221bda826ac6a9a62d6444cdb0dcd0615698a5cbe587c3f0fe57a54d8f5') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" \
 && php composer-setup.php --install-dir=/usr/local/bin --filename=composer \
 && php -r "unlink('composer-setup.php');"

RUN a2enmod alias rewrite ssl headers

RUN adduser docker --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password \
 && usermod -aG sudo docker
 # && echo "docker:teste123" | chpasswd

# WORKDIR /var/www
