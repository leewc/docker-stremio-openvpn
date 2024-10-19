FROM stremio/server:v4.20.11
# latest: stremio/server:v4.20.11 - Sometimes there's a race condition with new versions https://github.com/Stremio/server-docker/issues/37

# v5.0.0-beta.8
ARG STREMIO_WEB_RELEASE_VERSION=latest 

VOLUME ["/config/.stremio-server"]

# Install dependencies and Stremio-Web
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash \
    git \
    jq \
    openvpn \
    dumb-init \ 
    dnsutils \ 
    iputils-ping \
    ufw \
    curl \
    # wget \ --> already done in base dockerfile
    unzip \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    # groupmod -g 1000 users && \ --> already exists in base dockerfile
    useradd -u 911 -U -d /config -s /bin/false abc && \
    usermod -G users abc && \
    curl -L "https://github.com/stremio/stremio-web/releases/${STREMIO_WEB_RELEASE_VERSION}/download/stremio-web.zip" -o stremio-web.zip && \
    unzip stremio-web.zip && \
    mv build ui && \
    rm stremio-web.zip

# Add configuration and scripts
ADD openvpn /etc/openvpn/
ADD scripts /etc/scripts/
ADD stremio /etc/stremio/

ENV OPENVPN_USERNAME=**None** \
    OPENVPN_PASSWORD=**None** \
    OPENVPN_PROVIDER=**None** \
    OPENVPN_OPTS= \
    GLOBAL_APPLY_PERMISSIONS=true \
    CREATE_TUN_DEVICE=true \
    ENABLE_UFW=false \
    UFW_ALLOW_GW_NET=false \
    UFW_EXTRA_PORTS= \
    UFW_DISABLE_IPTABLES_REJECT=false \
    PUID= \
    PGID= \
    PEER_DNS=true \
    PEER_DNS_PIN_ROUTES=true \
    DROP_DEFAULT_ROUTE= \
    LOG_TO_STDOUT=false \
    HEALTH_CHECK_HOST=google.com \
    SELFHEAL=false

# Expose port for stremio - http and https - already done in stremio-server: https://github.com/Stremio/server-docker/blob/main/Dockerfile
# EXPOSE 11470
# EXPOSE 12470

# Kick start openVPN, which kicks off tunnel up, which starts server via tunnelUp/Down
# override entrypoint of original docker image
ENTRYPOINT ["dumb-init", "/etc/openvpn/start.sh"]

# TODO for UI either python3 -m http.server 8080 inside /build or npx http-server build/
