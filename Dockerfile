ARG BASE_IMAGE=debian:bookworm

ARG SETUP_BASE_IMAGE=${BASE_IMAGE}
ARG BUILD_BASE_IMAGE=setup-env
ARG PRODUCTION_BASE_IMAGE=${BASE_IMAGE}

# setup of dune dependencies
FROM ${SETUP_BASE_IMAGE} AS setup-env

RUN rm -f /etc/apt/apt.conf.d/docker-gzip-indexes \
  && rm -rf /var/lib/apt/lists/*
RUN export DEBIAN_FRONTEND=noninteractive; \
  apt-get update && apt-get dist-upgrade --no-install-recommends --yes \
  && apt-get install --no-install-recommends --yes \
  binutils \
  build-essential \
  ca-certificates \
  cmake \
  curl \
  dpkg \
  dpkg-dev \
  file \
  gcovr \
  git \
  git-lfs \
  libgtest-dev \
  ninja-build \
  pkg-config \
  python3 \
  python3-pip \
  python3-venv \
  nodejs \
  npm \
  && apt-get clean

RUN useradd --no-log-init -u 50000 --home /duneci duneci
WORKDIR /duneci/modules

RUN git clone https://github.com/emscripten-core/emsdk.git
RUN git clone --branch bugfix/1341 https://github.com/soilros/oneTBB.git

SHELL ["/bin/bash", "-c"]
ENV EMSDK_VERSION=3.1.51
RUN ./emsdk/emsdk install ${EMSDK_VERSION}
RUN ./emsdk/emsdk activate ${EMSDK_VERSION}
ENV EMSDK_QUIET=1

ENV TERM=xterm-256color
ENV CMAKE_CXX_COMPILER=emcc
ENV CMAKE_C_COMPILER=emcc
ENV CMAKE_GENERATOR=Ninja
ENV CMAKE_TOOLCHAIN_FILE=/duneci/modules/emsdk/upstream/emscripten/cmake/Modules/Platform/Emscripten.cmake
ENV CMAKE_CROSSCOMPILING_EMULATOR=/duneci/modules/emsdk/node/16.20.0_64bit/bin/node
ENV DEFAULT_CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=em++ -DCMAKE_C_COMPILER=emcc -DBUILD_SHARED_LIBS=OFF -DCMAKE_CROSSCOMPILING_EMULATOR=${CMAKE_CROSSCOMPILING_EMULATOR} -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}"

# COPY --chown=duneci oneTBB oneTBB
RUN mkdir oneTBB/build \
    && source /duneci/modules/emsdk/emsdk_env.sh \
    && cmake oneTBB -B oneTBB/build -G Ninja -DCMAKE_CXX_FLAGS='-fexceptions -pthread' -DTBB_DISABLE_HWLOC_AUTOMATIC_SEARCH=ON $DEFAULT_CMAKE_FLAGS -DTBB_EXAMPLES=OFF -DTBB_TEST=OFF -DCMAKE_EXE_LINKER_FLAGS='-sEXPORTED_RUNTIME_METHODS=ccall,cwrap,FS -sALLOW_MEMORY_GROWTH -sEXPORT_ES6=1 -sMODULARIZE -sEXPORT_NAME=wasm -sENVIRONMENT=web,worker -fexceptions -pthread -sPTHREAD_POOL_SIZE=4'
RUN cmake --build oneTBB/build
RUN cmake --install oneTBB/build
ENV TBB_DIR=/duneci/modules/emsdk/upstream/emscripten/cache/sysroot

# build and install dune-copasi from the setup-env
FROM ${BUILD_BASE_IMAGE} AS build-env

WORKDIR /duneci/modules/multi
COPY --chown=duneci cpp .

WORKDIR /duneci/modules/multi/build

RUN source /duneci/modules/emsdk/emsdk_env.sh \
      && cmake -DCMAKE_PREFIX_PATH=/duneci/modules/emsdk/upstream/emscripten/cache/sysroot DCMAKE_CXX_FLAGS='-fexceptions -pthread' $DEFAULT_CMAKE_FLAGS -DCMAKE_EXE_LINKER_FLAGS='-sEXPORTED_RUNTIME_METHODS=ccall,cwrap,FS -sALLOW_MEMORY_GROWTH -sEXPORT_ES6=1 -sMODULARIZE -sEXPORT_NAME=wasm -sENVIRONMENT=web,worker -fexceptions -pthread -sPTHREAD_POOL_SIZE=8' ..
RUN source /duneci/modules/emsdk/emsdk_env.sh && cmake --build . --verbose

FROM python:latest AS server

WORKDIR /app

COPY web/* ./
COPY --from=build-env /duneci/modules/multi/build/multi.* ./

EXPOSE 8080
CMD python -m http.server -d /app 8080
