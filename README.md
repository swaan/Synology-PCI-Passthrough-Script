# Synology VM PCI Passthrough Script

Based on https://github.com/sramshaw/pci_coral_on_synology this simplified script is intented to pass PCI devices (like a GPU in the PCI-E socket) from the Synology host to a VM running in the Virtual Machine Manager. It will wait for I/O virtualization (VFIO) modules to be loaded & sets it up for the device if needed. It looks for the VM and attaches the device with `virsh` when ready.

## Installation

1. Make sure your VM is set to Autostart
2. Set the correct parameters in the script for PCI vendor ID, device ID and VM name
3. Place the script where you like on your NAS and launch it with the Task Scheduler (Control Panel) as a Triggered Script that runs at Boot-up.
4. Reboot the NAS or run it with bash.