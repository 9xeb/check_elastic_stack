#!/bin/bash

# icinga2
ICINGA2_ERROR_LOG=/var/log/icinga2/error.log
/usr/lib/icinga2/prepare-dirs /etc/default/icinga2
/usr/sbin/icinga2 daemon --close-stdio -e ${ICINGA2_ERROR_LOG} &

# icinga2 redis
sudo -u icingadb-redis /usr/bin/icingadb-redis-server /usr/share/icingadb-redis/icingadb-redis-systemd.conf &

# # Wait for any process to exit
wait -n
# # Exit with status of process that exited first
exit $?