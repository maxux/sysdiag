#!/bin/sh
sysdiagroot="$1"
of="sysdiag.md"

if [ "${sysdiagroot}" == "" ]; then
    echo "[-] missing sysdiag result directory"
    exit 1
fi

if [ ! -f "${sysdiagroot}/sys/date" ]; then
    echo "[-] sysdiag result directory seems invalid"
    exit 1
fi

toc() {
    subheader "Table Of Contents"

    echo "1. [System](#system)" >> $of
    echo "2. [Hardware](#hardware)" >> $of
    echo "3. [Network](#network)" >> $of
    echo "4. [Network Namespaces](#network-namespaces)" >> $of
    echo "5. [Zero-OS](#zero-os)" >> $of
    echo "6. [System Logs](#system-logs)" >> $of
    echo "" >> $of
}

header() {
    echo "# $1" >> $of
    echo "" >> $of
}

subheader() {
    echo "## $1" >> $of
    echo "" >> $of
}

subsubheader() {
    echo "### $1" >> $of
    echo "" >> $of
}

blockcode() {
    subsubheader "$2"

    echo '```' >> $of
    cat ${sysdiagroot}/$1 >> $of
    echo '```' >> $of
}

blockjson() {
    subsubheader "$2"

    echo '```json' >> $of
    cat ${sysdiagroot}/$1 | jq >> $of
    echo '```' >> $of
}

blockssh() {
    cut -b 11- ${sysdiagroot}/zos/ssh > "${sysdiagroot}/.ssh"
    blockcode .ssh "SSH Sessions"
    rm -f ${sysdiagroot}/.ssh
}

blockmem() {
    grep -E '^Mem|^Swap|^Buffers' ${sysdiagroot}/sys/meminfo > "${sysdiagroot}/.meminfo"
    blockcode .meminfo "System Memory"
    rm -f ${sysdiagroot}/.meminfo
}

blockcmdline() {
    subsubheader "Kernel Command Line"

    for arg in $(cat ${sysdiagroot}/sys/cmdline); do
        echo " * \`$arg\`" >> $of
    done

    echo "" >> $of
}

netns() {
    for ns in ${sysdiagroot}/net/ns/*; do
        echo " * \`$(basename $ns)\`" >> $of
    done
    echo "" >> $of

    for ns in ${sysdiagroot}/net/ns/*; do
        echo "" >> $of
        echo "**$(basename $ns)**" >> $of
        echo '```' >> $of
        cat $ns/ipv4-address-br >> $of
        echo '```' >> $of
        echo '```' >> $of
        cat $ns/ipv4-route >> $of
        echo '```' >> $of

        echo '```' >> $of
        cat $ns/ipv6-address-br >> $of
        echo '```' >> $of
        echo '```' >> $of
        cat $ns/ipv6-route >> $of
        echo '```' >> $of
        echo "" >> $of
    done
}

summary() {
    : > $of

    header "System Diagnostic"

    toc

    subheader "System"

    blockcode sys/date "System Date"
    blockcode sys/uname "Host System"
    blockcode sys/uptime "Uptime"
    blockcmdline
    blockcode sys/w "Opened Session"

    subheader "Hardware"

    blockcode hard/lspci "PCI Devices"
    blockcode disk/lsblk "Block Devices"
    blockcode hard/lscpu "CPU"
    blockmem

    subheader "Network"

    blockcode net/ipv4-address "IPv4 Addresses"
    blockcode net/ipv4-route "IPv4 Routes"

    blockcode net/ipv4-address "IPv6 Addresses"
    blockcode net/ipv6-route "IPv6 Routes"

    blockcode net/rules "Routing Rules"

    subheader "Network Namespaces"
    netns

    subheader "Zero-OS"

    blockcode zos/nodeid "Node ID"
    blockcode zos/reservations-list "Reservations"
    blockcode zos/networkd-list "Networks"
    blockcode zos/versions "Running Versions"
    blockcode zos/cache-usage "Cache Usage"
    blockcode zos/flist-running-name "Running Target"
    blockjson zos/flist-running "Running Files"
    blockcode zos/zinit "Services"

    subheader "System Logs"

    blockssh
    blockcode sys/last "Last Logins"
}

summary
