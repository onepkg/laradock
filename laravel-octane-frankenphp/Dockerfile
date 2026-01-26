FROM dunglas/frankenphp

ARG CHANGE_SOURCE=false
RUN if [ ${CHANGE_SOURCE} = true ]; then \
    # Change application source from deb.debian.org to aliyun source
    if [ -e "/etc/apt/sources.list.d/debian.sources" ]; then \
      sed -i 's/deb.debian.org/mirrors.aliyun.com/' /etc/apt/sources.list.d/debian.sources ; \
    else \
      sed -i 's/deb.debian.org/mirrors.aliyun.com/' /etc/apt/sources.list && \
      sed -i 's/security.debian.org/mirrors.aliyun.com/' /etc/apt/sources.list && \
      sed -i 's/security-cdn.debian.org/mirrors.aliyun.com/' /etc/apt/sources.list; \
    fi \
;fi

RUN set -xe; \
    apt-get update -yqq && \
    pecl channel-update pecl.php.net

RUN install-php-extensions \
    pcntl

COPY . /app

ENTRYPOINT ["php", "artisan", "octane:frankenphp"]
