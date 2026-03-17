# KVM/libvirt Common Patterns

Commands below target a standard libvirt+QEMU/KVM installation. Connection URI defaults
to `qemu:///system` (root-level VMs). Use `qemu:///session` for unprivileged user VMs.

---

## 1. VM Creation with virt-install

### From ISO (interactive install)

```bash
virt-install \
  --name debian12 \
  --memory 2048 \
  --vcpus 2 \
  --disk size=20,format=qcow2,bus=virtio \
  --cdrom /var/lib/libvirt/images/debian-12.iso \
  --osinfo debian12 \
  --network network=default,model=virtio \
  --graphics vnc,listen=0.0.0.0 \
  --boot cdrom,hd
```

After the OS installs, the VM reboots from disk automatically. Remove `--boot cdrom,hd` or
reorder to `hd,cdrom` if the VM keeps booting from ISO.

### From network install (kickstart/preseed)

```bash
virt-install \
  --name fedora-server \
  --memory 4096 \
  --vcpus 4 \
  --disk size=40,format=qcow2 \
  --location https://download.fedoraproject.org/pub/fedora/linux/releases/41/Everything/x86_64/os/ \
  --osinfo fedora41 \
  --network network=default \
  --extra-args "inst.ks=https://example.com/kickstart.ks console=ttyS0" \
  --graphics none \
  --console pty,target.type=serial
```

The `--graphics none` + `--console` flags give you a text-mode serial console, useful for
headless servers and automation.

### Import existing disk image

```bash
virt-install \
  --import \
  --name myvm \
  --memory 1024 \
  --vcpus 1 \
  --disk /var/lib/libvirt/images/myvm.qcow2 \
  --osinfo debian12 \
  --network network=default
```

### Cloud image with cloud-init

```bash
# 1. Download a cloud image.
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img \
  -O /var/lib/libvirt/images/ubuntu-noble-base.img

# 2. Create a copy (keep the base pristine for future clones).
cp /var/lib/libvirt/images/ubuntu-noble-base.img \
   /var/lib/libvirt/images/ubuntu-ci.qcow2
qemu-img resize /var/lib/libvirt/images/ubuntu-ci.qcow2 20G

# 3. Launch with cloud-init. Generates a random root password and prints it.
virt-install \
  --import \
  --name ubuntu-ci \
  --memory 2048 \
  --vcpus 2 \
  --disk /var/lib/libvirt/images/ubuntu-ci.qcow2 \
  --osinfo ubuntunoble \
  --network network=default \
  --cloud-init root-password-generate=on,disable=on \
  --graphics none
```

The `disable=on` flag removes cloud-init from subsequent boots so it does not reset config.

### PXE boot

```bash
virt-install \
  --name pxe-client \
  --memory 2048 \
  --vcpus 2 \
  --disk size=20 \
  --pxe \
  --network network=default \
  --osinfo generic \
  --boot network,hd
```

### UEFI boot

```bash
virt-install \
  --name uefi-vm \
  --memory 4096 \
  --vcpus 2 \
  --disk size=30,format=qcow2 \
  --cdrom /var/lib/libvirt/images/ubuntu-24.04.iso \
  --osinfo ubuntu24.04 \
  --boot uefi \
  --machine q35 \
  --network network=default
```

Requires OVMF firmware package: `apt install ovmf` (Debian/Ubuntu) or `dnf install edk2-ovmf` (Fedora/RHEL).

---

## 2. Bridge Networking Setup

The default NAT network (`virbr0`) works for outbound access. For VMs that need to be
reachable from the LAN, create a Linux bridge attached to the host's physical interface.

### Using nmcli (NetworkManager)

```bash
# Create the bridge.
nmcli connection add type bridge ifname br0 con-name br0 \
  ipv4.method manual ipv4.addresses 192.168.1.10/24 ipv4.gateway 192.168.1.1 \
  ipv4.dns "1.1.1.1,8.8.8.8"

# Attach the physical interface as a bridge slave.
nmcli connection add type bridge-slave ifname eno1 master br0

# Bring up the bridge (this will disrupt the physical interface momentarily).
nmcli connection up br0

# Verify.
ip addr show br0
bridge link show
```

### Using netplan (Ubuntu 18.04+)

Create `/etc/netplan/01-bridge.yaml`:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eno1:
      dhcp4: false
  bridges:
    br0:
      interfaces: [eno1]
      addresses: [192.168.1.10/24]
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]
      parameters:
        stp: false
        forward-delay: 0
```

```bash
netplan apply
```

### Using /etc/network/interfaces (Debian)

```
auto eno1
iface eno1 inet manual

auto br0
iface br0 inet static
    address 192.168.1.10/24
    gateway 192.168.1.1
    dns-nameservers 1.1.1.1 8.8.8.8
    bridge_ports eno1
    bridge_stp off
    bridge_fd 0
```

```bash
systemctl restart networking
```

### Connect a VM to the bridge

```bash
# At creation time:
virt-install ... --network bridge=br0,model=virtio

# For an existing VM (edit XML):
virsh edit <domain>
# Change <interface type='network'> to:
#   <interface type='bridge'>
#     <source bridge='br0'/>
#     <model type='virtio'/>
#   </interface>
```

---

## 3. Custom Virtual Network (Isolated or Routed)

### Isolated network (VMs talk to each other and host only)

Create `isolated-net.xml`:

```xml
<network>
  <name>isolated</name>
  <bridge name='virbr1' stp='on' delay='0'/>
  <ip address='10.10.10.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='10.10.10.100' end='10.10.10.200'/>
    </dhcp>
  </ip>
</network>
```

```bash
virsh net-define isolated-net.xml
virsh net-start isolated
virsh net-autostart isolated
```

### Routed network (no NAT; requires external route to subnet)

```xml
<network>
  <name>routed</name>
  <forward mode='route' dev='eno1'/>
  <bridge name='virbr2' stp='on' delay='0'/>
  <ip address='10.20.30.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='10.20.30.100' end='10.20.30.200'/>
    </dhcp>
  </ip>
</network>
```

The upstream router must have a static route: `10.20.30.0/24 via <host-ip>`.

---

## 4. Storage Pool Creation

### Directory pool

```bash
mkdir -p /data/vms
virsh pool-define-as vmpool dir --target /data/vms
virsh pool-build vmpool
virsh pool-start vmpool
virsh pool-autostart vmpool

# Create a volume in the pool.
virsh vol-create-as vmpool myvm.qcow2 20G --format qcow2
```

### NFS pool

```bash
virsh pool-define-as nfs-images netfs \
  --source-host 192.168.1.100 \
  --source-path /exports/libvirt \
  --target /var/lib/libvirt/nfs-images

virsh pool-build nfs-images
virsh pool-start nfs-images
virsh pool-autostart nfs-images
```

### LVM pool (use an existing volume group)

```bash
virsh pool-define-as lvm-pool logical \
  --source-name vg_vms \
  --target /dev/vg_vms

virsh pool-start lvm-pool
virsh pool-autostart lvm-pool

# Create a 50G logical volume.
virsh vol-create-as lvm-pool lv-myvm 50G
```

### iSCSI pool

```bash
virsh pool-define-as iscsi-pool iscsi \
  --source-host 192.168.1.200 \
  --source-dev iqn.2024-01.com.example:storage.lun1 \
  --target /dev/disk/by-path

virsh pool-start iscsi-pool
virsh pool-autostart iscsi-pool
```

---

## 5. Snapshot Workflow

### Full snapshot (RAM + disk)

```bash
# Take a snapshot of a running VM (includes memory state).
virsh snapshot-create-as myvm snap-before-upgrade \
  --description "Before apt upgrade on 2026-03-14"

# List snapshots.
virsh snapshot-list myvm

# Something went wrong; revert.
virsh snapshot-revert myvm snap-before-upgrade --running

# Clean up old snapshot.
virsh snapshot-delete myvm snap-before-upgrade
```

### Disk-only snapshot (external; for backup integration)

```bash
# Quiesce the filesystem for consistency (requires QEMU guest agent).
virsh snapshot-create-as myvm backup-snap \
  --disk-only --quiesce --atomic

# The original disk is now a read-only backing file.
# Back up the backing file, then merge the overlay back.
virsh blockcommit myvm vda --active --pivot --verbose

# Verify the overlay is gone.
virsh domblklist myvm
```

---

## 6. Live Migration Between Hosts

### Prerequisites

1. Both hosts run libvirtd with compatible QEMU versions.
2. VM disk images are on shared storage (NFS, Ceph, GlusterFS) mounted at the same path.
3. SSH key-based auth from source to destination (for `qemu+ssh://` URI).
4. Same or compatible CPU models on both hosts (`--cpu host-model` recommended).
5. Destination firewall allows ports 16509 (libvirt) and 49152-49215 (QEMU migration).

### Basic live migration

```bash
# Peer-to-peer via SSH (simplest; no extra libvirtd config).
virsh migrate --live --p2p myvm qemu+ssh://dest-host/system

# With auto-convergence (throttles vCPUs if memory is dirtied faster than transferred).
virsh migrate --live --p2p --auto-converge myvm qemu+ssh://dest-host/system

# Tunneled (all traffic through libvirt; needs only port 16509).
virsh migrate --live --p2p --tunnelled myvm qemu+ssh://dest-host/system
```

### Migration with non-shared storage

```bash
# Copy all disks to the destination during migration.
virsh migrate --live --p2p --copy-storage-all myvm qemu+ssh://dest-host/system

# Copy only the topmost layer (requires base image pre-created on destination).
virsh migrate --live --p2p --copy-storage-inc myvm qemu+ssh://dest-host/system
```

### Post-copy migration (for large-memory VMs)

```bash
# Start migration, then switch to post-copy mode after initial precopy phase.
virsh migrate --live --p2p --postcopy --postcopy-after-precopy myvm qemu+ssh://dest-host/system
```

Post-copy transfers memory pages on-demand after the VM starts on the destination. This
reduces total downtime but makes the VM dependent on the source host until all pages
are transferred; if the source goes down, the VM crashes.

### Monitor migration progress

```bash
virsh domjobinfo myvm
# Shows: data processed, remaining, bandwidth, expected downtime.

# Set bandwidth limit (MiB/s).
virsh migrate-setspeed myvm 500
```

---

## 7. GPU Passthrough (VFIO)

### Host setup

```bash
# 1. Enable IOMMU in GRUB.
#    Intel:
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 intel_iommu=on iommu=pt"/' /etc/default/grub
#    AMD:
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amd_iommu=on iommu=pt"/' /etc/default/grub
sudo update-grub

# 2. Load VFIO modules early.
echo -e "vfio\nvfio_iommu_type1\nvfio_pci" | sudo tee /etc/modules-load.d/vfio.conf
sudo update-initramfs -u

# 3. Reboot, then verify IOMMU is active.
dmesg | grep -e DMAR -e IOMMU | head

# 4. Identify the GPU and its IOMMU group.
lspci -nn | grep -i vga
# Example: 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation ... [10de:2684]
# Also find the audio device on the same card:
lspci -nn | grep 01:00
# Example: 01:00.1 Audio device [0403]: NVIDIA Corporation ... [10de:22ba]

# 5. List all devices in the IOMMU group (must pass through ALL of them).
for d in /sys/kernel/iommu_groups/*/devices/*; do
  echo "IOMMU Group $(basename $(dirname $(dirname $d))): $(lspci -nns $(basename $d))"
done | grep "01:00"

# 6. Bind devices to vfio-pci. Blacklist competing drivers.
echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
echo "options vfio-pci ids=10de:2684,10de:22ba" | sudo tee /etc/modprobe.d/vfio.conf
sudo update-initramfs -u

# 7. Reboot and verify vfio-pci owns the device.
lspci -nnk -s 01:00.0
# Kernel driver in use: vfio-pci
```

### VM configuration

```bash
# Create a VM with q35 machine type and UEFI (required for most GPU passthrough).
virt-install \
  --name gpu-vm \
  --memory 16384 \
  --vcpus 8 \
  --cpu host-passthrough \
  --machine q35 \
  --boot uefi \
  --disk size=100,format=qcow2,bus=virtio \
  --osinfo win11 \
  --network network=default,model=virtio \
  --graphics none \
  --hostdev 01:00.0 \
  --hostdev 01:00.1 \
  --cdrom /var/lib/libvirt/images/Win11.iso
```

Alternatively, add PCI devices to an existing VM:

```bash
virsh edit gpu-vm
# Add inside <devices>:
#   <hostdev mode='subsystem' type='pci' managed='yes'>
#     <source>
#       <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
#     </source>
#   </hostdev>
```

---

## 8. Useful qemu-img Operations

```bash
# Create a new qcow2 image.
qemu-img create -f qcow2 disk.qcow2 20G

# Create a preallocated qcow2 (better sequential I/O).
qemu-img create -f qcow2 -o preallocation=full disk.qcow2 20G

# Get image info (format, virtual size, actual size, backing file).
qemu-img info disk.qcow2

# Convert raw to qcow2.
qemu-img convert -f raw -O qcow2 disk.raw disk.qcow2

# Convert qcow2 to raw (e.g., for direct block device use).
qemu-img convert -f qcow2 -O raw disk.qcow2 disk.raw

# Resize an image (grow only; shrink requires filesystem resize first).
qemu-img resize disk.qcow2 +10G

# Create a qcow2 with a backing file (copy-on-write overlay).
qemu-img create -f qcow2 -b base.qcow2 -F qcow2 overlay.qcow2

# Check image for errors.
qemu-img check disk.qcow2

# Compact a qcow2 (reclaim sparse space).
# Inside the guest, zero free space first (fstrim or dd), then:
qemu-img convert -O qcow2 disk.qcow2 disk-compacted.qcow2
mv disk-compacted.qcow2 disk.qcow2
```

---

## 9. QEMU Guest Agent

The guest agent enables host-side commands that require guest cooperation: filesystem
freeze/thaw, consistent snapshots, IP address reporting, and guest shutdown/reboot.

### Install in guest

```bash
# Debian/Ubuntu:
apt install qemu-guest-agent
systemctl enable --now qemu-guest-agent

# RHEL/Fedora:
dnf install qemu-guest-agent
systemctl enable --now qemu-guest-agent
```

### Add the agent channel to the VM (if not already present)

```bash
virsh edit myvm
# Add inside <devices>:
#   <channel type='unix'>
#     <target type='virtio' name='org.qemu.guest_agent.0'/>
#   </channel>
```

### Use from the host

```bash
# Check agent is responding.
virsh qemu-agent-command myvm '{"execute":"guest-info"}'

# Get IP addresses.
virsh domifaddr myvm --source agent

# Freeze filesystems (for consistent backup).
virsh domfsfreeze myvm
# ... take snapshot / backup ...
virsh domfsthaw myvm

# Run a command inside the guest.
virsh qemu-agent-command myvm '{"execute":"guest-exec","arguments":{"path":"/usr/bin/uptime","capture-output":true}}'
```

---

## 10. Troubleshooting Checklist

```bash
# Is KVM available?
ls -la /dev/kvm
egrep -c '(vmx|svm)' /proc/cpuinfo

# Is libvirtd running?
systemctl status libvirtd

# Can virsh connect?
virsh uri    # should print qemu:///system

# Host capabilities and IOMMU.
virt-host-validate qemu

# VM won't start: check the QEMU log.
cat /var/log/libvirt/qemu/<vmname>.log | tail -50

# VM has no network: check the virtual network.
virsh net-list --all
virsh net-dhcp-leases default

# Check iptables/nftables rules for virbr0.
iptables -L -n -t nat | grep virbr0

# Storage pool issues.
virsh pool-list --all
virsh pool-refresh <pool>

# Stale lock on disk image.
fuser /var/lib/libvirt/images/<vmname>.qcow2
```
