#!/bin/sh
# Original: https://gist.github.com/lexeii/8e60e1855aa4b0a16bc7e68302bb1d3d

pciidsfile=/usr/share/misc/pci.ids.gz

if [ ! -s $pciidsfile ]; then
    busybox lspci
    exit 0
fi

pciids=$(mktemp)
zcat $pciidsfile | sed '/^#/d; /^\t\t/d' > $pciids

classes=$(mktemp)
sed -n '/^C /,$p' $pciids > $classes

busybox lspci | while read a b c id; do
    echo -n "$a"

    awk -va=${c:0:2} -vb=${c:2:2} '
    {
        if ($1 == "C" && $2 == a) class = substr($0, 5)
        if (class != "" && $1 == b) { class = substr($0, 5); exit }
    }
    END { printf("%s: ", class) }' $classes

    sed -n "/${id:0:4}/,/^[^\t]/p" $pciids | \
    awk -vh=${id:0:4} -vl=${id:5:4} -vo="$1" '
    {
        if ($1 == h)
            { m = substr($0, 7); next }
        else if ($1 == l)
            { d = substr($0, 7); exit }
    }
    END {
        if (o == "-nn") nn = " [" h ":" l "]";
        printf("%s%s%s\n", m, d, nn);
    }'
done

rm -f $pciids $classes
