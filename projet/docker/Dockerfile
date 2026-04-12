FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LDAP_ORGANISATION="Example Org" \
    LDAP_DOMAIN="example.org" \
    LDAP_BASE_DN="dc=example,dc=org" \
    LDAP_ADMIN_PASSWORD="admin" \
    LDAP_TLS="false"

# slapd + clients ; NSS/PAM + nslcd/nscd pour l’objectif 4 (getent).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       slapd ldap-utils tini bash coreutils procps ca-certificates sysvinit-utils \
       libpam-ldap libnss-ldap nslcd nscd \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /container/init.d /var/lib/ldap /etc/ldap/slapd.d \
    && chown -R openldap:openldap /var/lib/ldap /etc/ldap/slapd.d

COPY --chown=openldap:openldap scripts/init_ldap.sh /container/init.d/10-init_ldap.sh
COPY --chown=openldap:openldap scripts/init_ldap_linux_integration.sh /container/init.d/20-init_ldap_linux_integration.sh
COPY --chown=openldap:openldap scripts/30-init_replication_provider.sh /container/init.d/30-init_replication_provider.sh
COPY --chown=openldap:openldap scripts/35-init_replication_consumer.sh /container/init.d/35-init_replication_consumer.sh
<<<<<<< HEAD
COPY --chown=root:root scripts/init_meta_annuaire.sh /container/init_meta_annuaire.sh
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /container/init_meta_annuaire.sh /container/init.d/10-init_ldap.sh /container/init.d/20-init_ldap_linux_integration.sh \
    /container/init.d/30-init_replication_provider.sh /container/init.d/35-init_replication_consumer.sh
=======
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /container/init.d/10-init_ldap.sh /container/init.d/20-init_ldap_linux_integration.sh \
    /container/init.d/30-init_replication_provider.sh /container/init.d/35-init_replication_consumer.sh

>>>>>>> a9ae0b6 (keycloak et replication)
EXPOSE 389

VOLUME ["/var/lib/ldap", "/etc/ldap/slapd.d"]

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]