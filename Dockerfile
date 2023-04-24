FROM ubuntu:20.04

ARG RUSTC_VERSION=nightly-2022-11-14
ARG PROFILE=release
ARG RUSTFLAGS
# Workaround for https://github.com/rust-lang/cargo/issues/10583
ENV CARGO_NET_GIT_FETCH_WITH_CLI=true
# Incremental compilation here isn't helpful
ENV CARGO_INCREMENTAL=0

RUN \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        protobuf-compiler \
        curl \
        git \
        llvm \
        clang \
        cmake \
        make && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain $RUSTC_VERSION

RUN /root/.cargo/bin/rustup target add wasm32-unknown-unknown

# Download Frontier repo
WORKDIR /code
COPY . .

RUN git submodule init && \
    git submodule update && \
    /root/.cargo/bin/cargo build \
        --locked \
        --profile $PROFILE \
        --bin frontier-template-node \
        --target $(uname -p)-unknown-linux-gnu && \
    mv target/*/*/frontier-template-node frontier-template-node && \
    rm -rf target

FROM ubuntu:20.04

RUN \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

HEALTHCHECK CMD curl \
                  -H "Content-Type: application/json" \
                  -d '{ "id": 1, "jsonrpc": "2.0", "method": "system_health", "params": [] }' \
                  -f "http://localhost:9933"

COPY --from=0 /code/frontier-template-node /frontier-node

RUN mkdir /var/frontier && chown nobody:nogroup /var/frontier

VOLUME /var/frontier

USER nobody:nogroup

ENTRYPOINT ["/frontier-node"]
CMD [ "--dev" ]
