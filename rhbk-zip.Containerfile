# Rootless Podman: build from this directory: podman build -f rhbk-zip.Containerfile .
# COPY --chown uses numeric UID/GID (185:0 = jboss:root in UBI OpenJDK); rootless Podman cannot resolve "jboss" in --chown.

FROM registry.redhat.io/ubi9/openjdk-21:1.23 AS builder

COPY --chown=185:0 rhbk-26.4.10/ /opt/keycloak/

USER 185

# Enable health and metrics support
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Configure a database vendor
ENV KC_DB=postgres

WORKDIR /opt/keycloak
# for demonstration purposes only, please make sure to use proper certificates in production instead
RUN /opt/keycloak/bin/kc.sh build

FROM registry.redhat.io/ubi9/openjdk-21:1.23
COPY --chown=185:0 --from=builder /opt/keycloak/ /opt/keycloak/

USER 185
WORKDIR /opt/keycloak

# change these values to point to a running postgres instance
ENTRYPOINT ["/opt/keycloak/bin/kc.sh","start-dev"]
