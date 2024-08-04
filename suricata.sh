#! /usr/bin/bash

set -e

fix_perms() {
    if [[ "${PGID}" ]]; then
        groupmod -o -g "${PGID}" suricata
    fi

    if [[ "${PUID}" ]]; then
        usermod -o -u "${PUID}" suricata
    fi

    chown -R suricata:suricata /etc/suricata
    chown -R suricata:suricata /var/lib/suricata
    chown -R suricata:suricata /var/log/suricata
    chown -R suricata:suricata /var/run/suricata
}

for src in /etc/suricata.dist/*; do
    filename=$(basename ${src})
    dst="/etc/suricata/${filename}"
    if ! test -e "${dst}"; then
        echo "Creating ${dst}."
        cp -a "${src}" "${dst}"
    fi
done

touch /var/log/suricata/fast.log
ln -s /var/log/suricata/fast.log /app/fast.log

touch /var/log/suricata/suricata.log
ln -s /var/log/suricata/suricata.log /app/suricata.log

touch /var/log/suricata/stats.log
ln -s /var/log/suricata/stats.log /app/stats.log

touch /var/log/suricata/eve.json
ln -s /var/log/suricata/eve.json /app/eve.json

/app/trafr -s | /usr/bin/suricata -c /etc/suricata/suricata.yaml -r /dev/stdin  

