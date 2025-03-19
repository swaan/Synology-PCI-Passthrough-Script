#!/bin/bash
# PCI Passthrough Hook Script
# - VENDOR and PRODUCT: From host 'lspci -nn' (e.g., "8086:56a6" for Intel Arc A310)
# - VM_NAME: From VMM UI (e.g., "debian")

VENDOR="8086"
PRODUCT="56a6"
VM_NAME="debian"
LOG_PATH="/var/log/virsh_attach_results.log"  # Set to "" to disable logging
MAX_WAIT=300
CHECK_INTERVAL=10

XML_TEMPLATE=$(cat << 'EOF'
<hostdev mode='subsystem' type='pci' managed='yes'>
    <source>
        <address domain='[DOMAIN]' bus='[BUS]' slot='[SLOT]' function='[FUNC]'/>
    </source>
</hostdev>
EOF
)

log() {
    [ -n "$LOG_PATH" ] && echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_PATH"
}

[ -n "$LOG_PATH" ] && echo "Starting PCI passthrough for VM $VM_NAME" > "$LOG_PATH"

# Wait for VFIO modules to be available
VFIO_WAIT=0
while [ $VFIO_WAIT -lt $MAX_WAIT ]; do
    if lsmod | grep -q vfio_pci && ls /dev/vfio/ >/dev/null 2>&1; then
        log "VFIO modules loaded"
        break
    fi
    [ -n "$LOG_PATH" ] && log "Waiting for VFIO... ($VFIO_WAIT/$MAX_WAIT)"
    sleep $CHECK_INTERVAL
    VFIO_WAIT=$((VFIO_WAIT + CHECK_INTERVAL))
done

if ! ls /dev/vfio/ >/dev/null 2>&1; then
    log "Error: VFIO not available after $MAX_WAIT seconds"
    exit 1
fi

echo "$VENDOR $PRODUCT" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || log "Warning: Failed to bind $VENDOR:$PRODUCT to vfio-pci"

# Wait for VM to be running
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    VM_LINE=$(/usr/local/bin/virsh list --all --title | grep "$VM_NAME")
    VM_ID=$(echo "$VM_LINE" | awk '{print $1}')
    VM_UUID=$(echo "$VM_LINE" | awk '{print $2}')
    if [ -n "$VM_ID" ] && /usr/local/bin/virsh domstate "$VM_ID" | grep -q "running"; then
        log "Found VM $VM_NAME with UUID $VM_UUID and ID $VM_ID"
        break
    fi
    [ -n "$LOG_PATH" ] && log "Waiting for VM $VM_NAME... ($ELAPSED/$MAX_WAIT)"
    sleep $CHECK_INTERVAL
    ELAPSED=$((ELAPSED + CHECK_INTERVAL))
done

if [ -n "$VM_ID" ]; then
    ADDRESS=$(lspci | grep "$VENDOR:$PRODUCT" | awk '{print $1}')
    if [ -n "$ADDRESS" ]; then
        log "Processing PCI device at $ADDRESS"
        DOMAIN="0x0000"
        BUS=$(printf "0x%02x" "$(echo "$ADDRESS" | cut -d':' -f1 | sed 's/^0*//;s/^$/0/')")
        SLOT=$(printf "0x%02x" "$(echo "$ADDRESS" | cut -d':' -f2 | cut -d'.' -f1 | sed 's/^0*//;s/^$/0/')")
        FUNC=$(printf "0x%x" "$(echo "$ADDRESS" | cut -d'.' -f2 | sed 's/^0*//;s/^$/0/')")

        TEMP_XML="/tmp/passthrough_$ADDRESS.xml"
        echo "$XML_TEMPLATE" | sed -e "s/\[DOMAIN\]/$DOMAIN/" \
                                   -e "s/\[BUS\]/$BUS/" \
                                   -e "s/\[SLOT\]/$SLOT/" \
                                   -e "s/\[FUNC\]/$FUNC/" > "$TEMP_XML"

        [ -n "$LOG_PATH" ] && cat "$TEMP_XML" >> "$LOG_PATH"
        /usr/local/bin/virsh attach-device "$VM_ID" "$TEMP_XML" --current 2>>"$LOG_PATH" && log "PCI device attached successfully"
        rm -f "$TEMP_XML"

        [ -n "$LOG_PATH" ] && {
            echo "----- results ------" >> "$LOG_PATH"
            /usr/local/bin/virsh qemu-monitor-command "$VM_ID" --hmp "info pci" >> "$LOG_PATH"
        }
    else
        log "Error: PCI device $VENDOR:$PRODUCT not found"
    fi
else
    log "Error: VM $VM_NAME not running after $MAX_WAIT seconds"
    exit 1
fi