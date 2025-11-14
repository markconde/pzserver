# syntax=docker/dockerfile:1

########################################################################
# Project Zomboid Dedicated Server (SteamCMD, RCON, env-driven config)
########################################################################

ARG BASE_IMAGE=ubuntu:24.04
ARG RCON_IMAGE=outdead/rcon:0.10.2
ARG USER=steam

########################
# Stage 1: rcon binary #
########################
FROM ${RCON_IMAGE} AS rcon

#############################
# Stage 2: SteamCMD builder #
#############################
FROM ${BASE_IMAGE} AS steamcmd-builder

# Enable 32-bit arch and install build-time deps for SteamCMD
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      wget \
      libsdl2-2.0-0:i386 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/steamcmd

# Download and unpack SteamCMD into /tmp/steamcmd
RUN wget -O steamcmd_linux.tar.gz "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" \
 && tar -xzf steamcmd_linux.tar.gz \
 && rm steamcmd_linux.tar.gz

################################
# Stage 3: Final PZ server image
################################
FROM ${BASE_IMAGE} AS pz-runtime

ARG USER

ENV USER="${USER}"
ENV HOME="/home/${USER}"
ENV STEAMDIR="${HOME}/.local/steamcmd"
ENV PATH="${STEAMDIR}:${PATH}"

LABEL maintainer="mark@mrkcnd.com" \
      org.opencontainers.image.title="Project Zomboid Dedicated Server" \
      org.opencontainers.image.source="https://github.com/markconde/pzserver" \
      org.opencontainers.image.authors="Mark Conde" \
      zomboid.role="pz-dedicated-server"

USER root

# Copy rcon client from rcon stage
COPY --from=rcon /rcon /usr/bin/rcon

# Enable 32-bit arch and install runtime deps
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates \
      lib32stdc++6 \
      libsdl2-2.0-0:i386 \
      musl \
      python3-minimal \
      iputils-ping \
      tzdata \
      procps \
 && rm -rf /var/lib/apt/lists/*

# Create non-root steam user (if it doesn't already exist)
RUN if id -u "${USER}" >/dev/null 2>&1; then \
      echo "User ${USER} already exists, reusing it."; \
    else \
      useradd --create-home --home-dir "${HOME}" "${USER}"; \
    fi

# Copy SteamCMD from builder into steam's home
COPY --from=steamcmd-builder --chown=${USER}:${USER} /tmp/steamcmd/ "${STEAMDIR}"

# Set up Steam client symlink
RUN mkdir -p "${HOME}/.steam/sdk64" \
 && ln -sf "${HOME}/linux64/steamclient.so" "${HOME}/.steam/sdk64/steamclient.so"

# Copy scripts (run_server.sh, edit_server_config.py, healthcheck.sh) from ./src
COPY --chown=${USER}:${USER} src/ "${HOME}/"
RUN chmod +x "${HOME}/run_server.sh" "${HOME}/healthcheck.sh"

WORKDIR "${HOME}"
USER ${USER}

EXPOSE 16261/udp 16262-16272/udp
VOLUME ["${HOME}/Zomboid"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD /home/steam/healthcheck.sh || exit 1

ENTRYPOINT ["/bin/bash", "/home/steam/run_server.sh"]
