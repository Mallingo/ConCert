FROM aucobra/concert:deps-coq-8.11-2

LABEL maintainer="The COBRA Team"

# some extra packages
RUN sudo apt update && sudo apt install libcurl4-gnutls-dev libsodium-dev build-essential -y

# install liquidity 2.1-beta12
RUN ["/bin/bash", "--login", "-c", "set -x \
   && eval $(opam env --switch=${COMPILER_EDGE} --set-switch) \
   && cd ~ \
   && git clone https://github.com/OCamlPro/liquidity \
   && cd liquidity \
   && git checkout 3578de34cf751f54b9e4c001a95625d2041b2962 \
   && make clone-dune-network \
   && make build-deps && make && make install" ]

# install Rust and cargo-concordium

RUN curl https://sh.rustup.rs -sSf | bash -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN rustup target add wasm32-unknown-unknown \
   && curl -L -O https://distribution.concordium.software/tools/linux/cargo-concordium_1.0.0 \
   && sudo chmod +x cargo-concordium_1.0.0 \
   && sudo cp cargo-concordium_1.0.0 /usr/local/bin/cargo-concordium

# install LIGO v0.38.1
RUN curl -L -O https://gitlab.com/ligolang/ligo/-/jobs/2217283618/artifacts/raw/ligo && sudo chmod +x ./ligo && sudo cp ./ligo /usr/local/bin

# install Elm 0.19.1

RUN curl -L -o elm.gz https://github.com/elm/compiler/releases/download/0.19.1/binary-for-linux-64-bit.gz \
    && gunzip elm.gz \
    && sudo chmod +x elm \
    && sudo mv elm /usr/local/bin/ \
    && sudo apt install npm -y \
    && sudo npm install -g elm-test

# configuring git to use https

RUN git config --global url."https://github.com/".insteadOf git@github.com: && git config --global url."https://".insteadOf git://

ENV CARGO_NET_GIT_FETCH_WITH_CLI=true