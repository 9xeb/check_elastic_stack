# https://icinga.com/docs/icinga-2/latest/doc/02-installation/01-Debian/
FROM debian:stable

RUN apt update && apt -y install apt-transport-https wget && \
    wget -O icinga-archive-keyring.deb "https://packages.icinga.com/icinga-archive-keyring_latest+debian$(. /etc/os-release; echo "$VERSION_ID").deb" && \
    apt -y install ./icinga-archive-keyring.deb; \
    DIST=$(awk -F"[)(]+" '/VERSION=/ {print $2}' /etc/os-release); \
    echo "deb [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/debian icinga-${DIST} main" > \
    /etc/apt/sources.list.d/${DIST}-icinga.list; \
    echo "deb-src [signed-by=/usr/share/keyrings/icinga-archive-keyring.gpg] https://packages.icinga.com/debian icinga-${DIST} main" >> \
    /etc/apt/sources.list.d/${DIST}-icinga.list; \
    apt update && apt -y install icinga2 && apt-get clean autoclean
