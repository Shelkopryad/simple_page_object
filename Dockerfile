FROM ruby:3.3.1

LABEL maintainer="Lndail"
LABEL description="Ruby test automation container"
LABEL ruby.version="3.3.1"

ENV DEBIAN_FRONTEND=noninteractive
ENV BUNDLER_VERSION=2.5.10

RUN apt-get update -qq && \
    apt-get install -yq --no-install-recommends \
        build-essential \
        libcurl4-openssl-dev \
        libpq-dev \
        libxml2-dev \
        libxslt1-dev \
        zlib1g-dev \
        less \
        ssh-client \
        shared-mime-info \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN gem install bundler -v $BUNDLER_VERSION --no-document && \
    gem cleanup

WORKDIR /app

COPY Gemfile Gemfile.lock /app/

RUN bundle install --jobs 4 --retry 3

COPY config/ /app/config/
COPY lib/ /app/lib/
COPY helpers/ /app/helpers/
COPY spec_helper.rb /app/

RUN mkdir -p /app/reports/allure-results /app/reports/screenshots /app/downloads

CMD ["/bin/bash"]
