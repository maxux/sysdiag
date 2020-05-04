#!/bin/bash
reportroot="/tmp"
reportid="$(date +%Y%m%d-%H%M)"
reportdir="${reportroot}/sysdiag-${reportid}"

initialize() {
    echo "[+]"
    echo "[+] initializing system diagnostic"
    echo "[+]"

    echo "[+] report directory: ${reportdir}"
    mkdir -p "${reportdir}"

    sys="${reportdir}/sys"
    mkdir -p "${sys}"

    proc="${reportdir}/proc"
    mkdir -p "${proc}"

    net="${reportdir}/net"
    mkdir -p "${net}"
    mkdir -p "${net}/ns"

    zos="${reportdir}/zos"
    mkdir -p "${zos}"

    disk="${reportdir}/disk"
    mkdir -p "${disk}"

    hard="${reportdir}/hard"
    mkdir -p "${hard}"
}

processes() {
    ps aux | grep -v ' \[' > "${proc}/ps"
}

disks() {
    lsscsi > "${disk}/lsscsi"
    lsblk -f > "${disk}/lsblk"
    blkid > "${disk}/blkid"
    df -ha &> "${disk}/df"
    cat /proc/mounts > "${disk}/mounts"
}

kernel() {
    dmesg -f kern > "${sys}/dmesg"
    uname -a > "${sys}/uname"
}

sysbase() {
    date > "${sys}/date"
    uptime > "${sys}/uptime"
    w > "${sys}/w"
    last > "${sys}/last"
    cat /proc/meminfo > "${sys}/meminfo"
}

network() {
    ip -4 address > "${net}/ipv4-address"
    ip -4 route > "${net}/ipv4-route"

    ip -6 address > "${net}/ipv6-address"
    ip -6 route > "${net}/ipv6-route"

    ip rule > "${net}/rules"

    for ns in $(ip netns | awk '{ print $1 }'); do
        mkdir -p "${net}/ns/$ns"
        ip netns exec $ns ip -4 address > "${net}/ns/$ns/ipv4-address"
        ip netns exec $ns ip -4 route > "${net}/ns/$ns/ipv4-route"
        ip netns exec $ns ip -6 address > "${net}/ns/$ns/ipv4-address"
        ip netns exec $ns ip -6 route > "${net}/ns/$ns/ipv4-route"
    done
}

hardware() {
    lscpu > "${hard}/lscpu"
    dmidecode > "${hard}/dmidecode"
    sh lspci-emul-opt.sh > "${hard}/lspci"
}

zeroos() {
    zinit > "${zos}/zinit"

    grep 'sshd: Accepted' /var/cache/log/system.log > "${zos}/ssh"
    cat /root/.ssh/authorized_keys > "${zos}/sshkeys"
}

main() {
    initialize

    echo "[+] fetching kernel informations"
    kernel

    echo "[+] fetching base system"
    sysbase

    echo "[+] fetching process list"
    processes

    echo "[+] fetching disks availables"
    disks

    echo "[+] fetching network statistics"
    network

    echo "[+] fetching hardware summary"
    hardware

    echo "[+] fetching zero-os specific informations"
    zeroos

    echo "[+] packing responses"
    tar -czf ${reportroot}/sysdiag-${reportid}.tar.gz ${reportdir}
}

main
