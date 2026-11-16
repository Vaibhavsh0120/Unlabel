#!/bin/sh
# Apply to the Oracle host after verifying the HTTPS dashboard and SSH access.
set -eu

action=${1:-apply}
case "$action" in apply|remove) ;; *) printf '%s\n' 'Use apply or remove.' >&2; exit 2 ;; esac
interface=$(ip -o route show default | awk 'NR == 1 {for (i = 1; i < NF; i++) if ($i == "dev") {print $(i + 1); break}}')
[ -n "$interface" ] || { printf '%s\n' 'Default network interface unavailable.' >&2; exit 1; }

rule() {
    executable=$1
    chain=$2
    shift 2
    if "$executable" -w 10 -C "$chain" "$@" 2>/dev/null; then
        if [ "$action" = remove ]; then "$executable" -w 10 -D "$chain" "$@"; fi
    elif [ "$action" = apply ]; then
        "$executable" -w 10 -I "$chain" 1 "$@"
    fi
}

for firewall in iptables ip6tables; do
    command -v "$firewall" >/dev/null 2>&1 || continue
    rule "$firewall" INPUT -i "$interface" -p tcp -m multiport --dports 6001,6002,8000,8080 \
        -m comment --comment unlabel-coolify-direct-admin -j DROP
    if "$firewall" -w 10 -C FORWARD -j DOCKER-USER 2>/dev/null; then
        for port in 6001 6002 8000 8080; do
            rule "$firewall" DOCKER-USER -i "$interface" -p tcp -m conntrack \
                --ctdir ORIGINAL --ctorigdstport "$port" \
                -m comment --comment unlabel-coolify-direct-admin -j DROP
        done
    fi
done
