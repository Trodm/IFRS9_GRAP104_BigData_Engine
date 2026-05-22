FROM rocker/r-ver:4.3.3

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
<<<<<<< HEAD
    libsodium-dev \
    pkg-config \
=======
>>>>>>> 6a9581241083486741e6607d89a1e414e9724067
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('plumber','jsonlite','dplyr'), repos='https://cloud.r-project.org')"

WORKDIR /app

COPY . /app

EXPOSE 8000

CMD ["R", "-e", "pr <- plumber::plumb('api.R'); pr$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 8000)))"]