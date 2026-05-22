FROM rocker/r-ver:4.3.3

RUN apt-get update && apt-get install -y echo     libcurl4-openssl-dev echo     libssl-dev echo     libxml2-dev echo     libsodium-dev echo     pkg-config echo     make echo     g++ echo     && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('plumber','jsonlite','dplyr'), repos='https://cloud.r-project.org')"

WORKDIR /app

COPY . /app

EXPOSE 8000

CMD ["R", "-e", "pr <- plumber::plumb('api.R'); pr$run(host='0.0.0.0', port=as.numeric(Sys.getenv('PORT', 8000)))"]
