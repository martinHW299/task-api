# ---------- build stage (composer) ----------
FROM composer:2 AS vendor
WORKDIR /app

# 1) copy composer files
COPY composer.json composer.lock ./

# 2) install deps (no scripts yet, because artisan not copied)
RUN composer install \
  --no-dev --prefer-dist --no-interaction --no-progress \
  --optimize-autoloader \
  --no-scripts

# 3) now copy the full app (artisan will exist)
COPY . .

# 4) now safely run scripts that need artisan
RUN composer dump-autoload -o \
 && php artisan package:discover --ansi

# syntax=docker/dockerfile:1

FROM php:8.4-fpm-bookworm

ENV DEBIAN_FRONTEND=noninteractive

# ---------- System deps + Nginx + Supervisor + build deps ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx supervisor \
    git unzip zip curl ca-certificates \
    gnupg apt-transport-https \
    libicu-dev libzip-dev zlib1g-dev \
    unixodbc unixodbc-dev \
 && rm -rf /var/lib/apt/lists/*

# ---------- Microsoft ODBC Driver 18 ----------
RUN set -eux; \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg; \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" \
      > /etc/apt/sources.list.d/microsoft-prod.list; \
    apt-get update; \
    ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18; \
    rm -rf /var/lib/apt/lists/*

# ---------- PHP extensions ----------
RUN docker-php-ext-configure intl \
 && docker-php-ext-install -j"$(nproc)" intl zip pdo \
 && pecl install sqlsrv pdo_sqlsrv \
 && docker-php-ext-enable sqlsrv pdo_sqlsrv

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# 1) Copy composer files first (cache-friendly)
COPY composer.json composer.lock ./

# 2) Install deps WITHOUT running scripts (artisan not present yet)
RUN composer install \
    --no-dev \
    --prefer-dist \
    --no-interaction \
    --no-progress \
    --optimize-autoloader \
    --no-scripts

# 3) Now copy the full app (includes artisan)
COPY . .

# 4) Now it's safe to run artisan-related steps
# Now run scripts safely (artisan exists now)
RUN composer dump-autoload -o \
 && php artisan package:discover --ansi || true

# Permissions
RUN chown -R www-data:www-data /var/www/html \
 && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Nginx + Supervisor configs (your existing files)
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/site.conf /etc/nginx/conf.d/default.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN mkdir -p /run/nginx /var/log/supervisor

EXPOSE 80

CMD ["/usr/bin/supervisord", "-n"]