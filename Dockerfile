FROM rocker/r-ver:4.3.3

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgit2-dev \
    libzstd-dev \
    liblz4-dev \
    cmake \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('plumber','jsonlite','dplyr','readr','duckdb','DBI','arrow'), repos='https://cloud.r-project.org')"

WORKDIR /app
COPY . /app

EXPOSE 8000

CMD ["R", "-e", "pr <- plumber::plumb('api.R'); pr$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 8000)))"]
