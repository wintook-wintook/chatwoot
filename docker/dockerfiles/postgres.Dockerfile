FROM postgres:12

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      build-essential \
      postgresql-server-dev-12 \
      git \
      ca-certificates \
 && git clone --depth 1 --branch v0.5.1 https://github.com/pgvector/pgvector.git /tmp/pgvector \
 && cd /tmp/pgvector \
 && make \
 && make install \
 && rm -rf /tmp/pgvector \
 && apt-get remove -y build-essential postgresql-server-dev-12 git \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*
