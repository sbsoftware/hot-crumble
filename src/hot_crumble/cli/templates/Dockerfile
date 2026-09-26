FROM crystallang/crystal:1.20

RUN apt-get update && apt-get install -y --no-install-recommends libsqlite3-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . .

RUN shards install
