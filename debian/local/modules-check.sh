#!/bin/sh
# Calibrate /etc/modules-load.d/cups-filters.conf against the .ko modules
# actually available in any installed kernel under /lib/modules.
#
# Rule (conservative): keep lp/ppdev/parport_pc only if the matching .ko
# exists in at least one installed kernel; otherwise drop the entry.
#
# Single source of logic, shared by:
#   - cups-filters.postinst           (at package install/upgrade time)
#   - /etc/kernel/postinst.d/zz-cups-filters (after kernel install/upgrade)
#   - /etc/kernel/postrm.d/zz-cups-filters  (after kernel removal)
# so the result never depends on dpkg install ordering between cups-filters
# and the kernel packages.
set -e

CONF=/etc/modules-load.d/cups-filters.conf
MODS="lp ppdev parport_pc"

# Nothing to calibrate (admin removed the conffile, or first unpack not done).
[ -f "$CONF" ] || exit 0
# No kernel tree yet (e.g. chroot package install before any kernel is
# installed): keep the shipped default configuration untouched.
[ -d /lib/modules ] || exit 0

has_ko() {
    name=$1
    for kdir in /lib/modules/*/; do
        [ -d "$kdir" ] || continue
        # lp.ko / ppdev.ko live under drivers/char,
        # parport_pc.ko under drivers/parport -- all below drivers/.
        # Match both uncompressed and compressed variants (.ko.xz/.ko.zst/.ko.gz)
        # to handle systems with CONFIG_MODULE_COMPRESS=y.
        find "${kdir}kernel/drivers" -type f \
            \( -name "${name}.ko" -o -name "${name}.ko.xz" \
               -o -name "${name}.ko.zst" -o -name "${name}.ko.gz" \) \
            2>/dev/null | grep -q . && return 0
    done
    return 1
}

for m in $MODS; do
    # Remove any existing entry (tolerate surrounding whitespace), then
    # re-append it only if a matching .ko is present. Idempotent.
    sed -i "/^[[:space:]]*${m}[[:space:]]*\$/d" "$CONF" || exit 0
    if has_ko "$m"; then
        echo "$m" >> "$CONF"
    fi
done

exit 0
