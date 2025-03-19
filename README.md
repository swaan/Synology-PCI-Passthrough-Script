# Synology VM PCI Passthrough Script

Based on https://github.com/sramshaw/pci_coral_on_synology this simplified script is for passing PCI devices (like a GPU in the PCI-E socket) from the Synology host to a VM running in the Virtual Machine Manager. It will wait for I/O virtualization (VFIO) modules to be loaded & sets it up for the device if needed. It waits until the VM is **running** and attaches the device with `virsh`. My goal was to change the VM configuration and add hardware passthrough to it but I couldn't make it work so I figured attaching it while running is the next best option.

## Installation

1. Make sure your VM is set to Autostart
2. Set the correct parameters in the script for PCI vendor ID, device ID and VM name
3. Place the script where you like on your NAS and launch it with the Task Scheduler (Control Panel) as a Triggered Script that runs at Boot-up.
4. Reboot the NAS or run it with bash.