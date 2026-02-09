FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    pkg-config \
    patchelf \
    zlib1g-dev \
    xz-utils \
    bzip2 \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY . /src
WORKDIR /src

RUN chmod +x scripts/*.sh

# Build and copy artifacts to /out/ for easy extraction
CMD scripts/build.sh && mkdir -p /out && cp dist/* /out/
