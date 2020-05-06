#!/bin/bash
reportroot="/tmp"
reportid="$(date +%Y%m%d-%H%M)"
reportdir="${reportroot}/sysdiag-${reportid}"
lspcibin="$(dirname $0)/lspci-emul-opt.sh"

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

cleanup() {
    rm -rf "${reportdir}"
}

processes() {
    ps aux | grep -v ' \[' > "${proc}/ps"
    ps -eo pid,etime,args | grep -v ' \[' > "${proc}/uptime"
}

disks() {
    lsscsi > "${disk}/lsscsi"
    lsblk -f > "${disk}/lsblk"
    blkid > "${disk}/blkid"
    df -ha &> "${disk}/df"
    cat /proc/mounts > "${disk}/mounts"
}

kernel() {
    cat /proc/cmdline > "${sys}/cmdline"
    dmesg -f kern > "${sys}/dmesg"
    uname -a > "${sys}/uname"
    cat /proc/version > "${sys}/version"
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
        ip netns exec $ns ip -4 -br address > "${net}/ns/$ns/ipv4-address-br"
        ip netns exec $ns ip -4 route > "${net}/ns/$ns/ipv4-route"
        ip netns exec $ns ip -6 address > "${net}/ns/$ns/ipv6-address"
        ip netns exec $ns ip -6 -br address > "${net}/ns/$ns/ipv6-address-br"
        ip netns exec $ns ip -6 route > "${net}/ns/$ns/ipv6-route"
    done
}

hardware() {
    lscpu > "${hard}/lscpu"
    dmidecode &> "${hard}/dmidecode"

    sh $lspcibin > "${hard}/lspci"
}

zeroos() {
    zinit > "${zos}/zinit"

    grep 'sshd: Accepted' /var/cache/log/system.log > "${zos}/ssh"
    cat /root/.ssh/authorized_keys > "${zos}/sshkeys"

    identityd -id > "${zos}/nodeid"

    modules="capacityd contd flistd identityd internet networkd provisiond storaged vmd zui"
    for module in $modules; do
        echo "$($module -v) [$module]" >> "${zos}/versions"
    done

    echo "$(cat /tmp/flist.name)" > "${zos}/flist-running-name"
    cat /tmp/bins.info > "${zos}/binaries-flist"
    cat /tmp/flist.info > "${zos}/flist-running"

    du -shc /var/cache/modules/* > "${zos}/cache-usage"
    ls -alh /var/cache/modules/networkd/ > "${zos}/networkd-list"
    ls -alh /var/cache/modules/provisiond/reservations/ > "${zos}/reservations-list"
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
    tar -czf ${reportroot}/sysdiag-${reportid}.tar.gz -C ${reportroot} sysdiag-${reportid}

    echo "[+]"
    echo "[+] report ready: ${reportroot}/sysdiag-${reportid}.tar.gz"
    echo "[+]"

    cleanup
}

main
