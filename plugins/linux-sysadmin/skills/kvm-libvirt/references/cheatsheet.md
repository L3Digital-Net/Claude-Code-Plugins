# virsh Command Cheatsheet

Organized by category. All commands assume `virsh` prefix (e.g., `virsh list --all`).

---

## Domain Lifecycle

| Command | Purpose |
|---------|---------|
| `list --all` | List all domains (running, paused, shut off) |
| `list --title` | List running domains with their title field |
| `start <domain>` | Start a defined domain |
| `start <domain> --console` | Start and attach serial console |
| `shutdown <domain>` | Graceful ACPI shutdown |
| `shutdown <domain> --mode agent` | Shutdown via QEMU guest agent |
| `destroy <domain>` | Force power off (like pulling the plug) |
| `destroy <domain> --graceful` | Try graceful first, force if needed |
| `reboot <domain>` | Reboot via ACPI |
| `suspend <domain>` | Pause (freeze in RAM, still consumes memory) |
| `resume <domain>` | Unpause a suspended domain |
| `reset <domain>` | Hard reset (like pressing reset button) |
| `save <domain> <file>` | Save running state to file (stops VM) |
| `restore <file>` | Restore from saved state file |
| `managedsave <domain>` | Save state; auto-restores on next `start` |
| `autostart <domain>` | Start domain on host boot |
| `autostart --disable <domain>` | Disable auto-start |

## Domain Definition

| Command | Purpose |
|---------|---------|
| `define <xmlfile>` | Define a persistent domain from XML |
| `undefine <domain>` | Remove domain definition (keeps disks) |
| `undefine <domain> --remove-all-storage` | Remove definition and all disk images |
| `undefine <domain> --nvram --remove-all-storage` | Remove including UEFI NVRAM |
| `create <xmlfile>` | Create and start a transient domain |
| `edit <domain>` | Edit domain XML in $EDITOR |
| `dumpxml <domain>` | Print full domain XML |
| `dumpxml <domain> --security-info` | Include security-sensitive fields |
| `domrename <domain> <newname>` | Rename a shut-off domain |

## Domain Information

| Command | Purpose |
|---------|---------|
| `dominfo <domain>` | Summary: state, memory, vCPUs, autostart |
| `domstate <domain>` | Current state only |
| `domblklist <domain>` | List block devices (disks) |
| `domblkinfo <domain> <dev>` | Disk capacity/allocation/physical |
| `domiflist <domain>` | List network interfaces |
| `domifaddr <domain>` | Show IP addresses (requires guest agent or DHCP lease) |
| `dommemstat <domain>` | Memory statistics (balloon, RSS) |
| `vcpucount <domain>` | vCPU counts (current, max, live, config) |
| `vcpupin <domain>` | vCPU to physical CPU pinning |

## Console and Display

| Command | Purpose |
|---------|---------|
| `console <domain>` | Attach to serial console (Ctrl+] to detach) |
| `console <domain> --force` | Force-attach even if another session is connected |
| `vncdisplay <domain>` | Show VNC display address (e.g., `:0` = port 5900) |
| `domdisplay <domain>` | Full display URI (VNC or SPICE) |
| `screenshot <domain> <file>` | Capture screen to PNG file |

## CPU and Memory (Live Tuning)

| Command | Purpose |
|---------|---------|
| `setvcpus <domain> <N> --live` | Change vCPU count (within max) |
| `setvcpus <domain> <N> --config` | Change vCPU count for next boot |
| `setmem <domain> <KiB> --live` | Change balloon memory target |
| `setmaxmem <domain> <KiB> --config` | Change max memory (requires restart) |
| `vcpupin <domain> <vcpu> <cpulist>` | Pin vCPU to host CPUs (e.g., `0 0-3`) |
| `emulatorpin <domain> <cpulist>` | Pin emulator threads to host CPUs |
| `numatune <domain> --nodeset <nodes> --mode strict` | NUMA memory binding |

## Disk Operations

| Command | Purpose |
|---------|---------|
| `attach-disk <domain> <src> <tgt> --live` | Hot-add a disk (e.g., `vdb`) |
| `detach-disk <domain> <tgt> --live` | Hot-remove a disk |
| `blockresize <domain> <path> <size>` | Online resize of a block device |
| `blockcommit <domain> <disk> --active --pivot` | Merge snapshot overlay into base |
| `blockpull <domain> <disk>` | Flatten backing chain into active layer |
| `domblkstat <domain> <dev>` | Block device I/O statistics |

## Snapshots

| Command | Purpose |
|---------|---------|
| `snapshot-create-as <domain> <name>` | Create named snapshot |
| `snapshot-create-as <domain> <name> --disk-only` | Disk-only snapshot (no RAM state) |
| `snapshot-create-as <domain> <name> --quiesce` | Quiesce filesystem via guest agent |
| `snapshot-list <domain>` | List all snapshots |
| `snapshot-list <domain> --tree` | Tree view of snapshot hierarchy |
| `snapshot-info <domain> <snap>` | Snapshot metadata |
| `snapshot-revert <domain> <snap>` | Revert to snapshot |
| `snapshot-revert <domain> <snap> --running` | Revert and start the domain |
| `snapshot-delete <domain> <snap>` | Delete a snapshot |
| `snapshot-delete <domain> <snap> --children` | Delete snapshot and all children |
| `snapshot-current <domain>` | Show current snapshot |

## Virtual Networking

| Command | Purpose |
|---------|---------|
| `net-list --all` | List all virtual networks |
| `net-info <net>` | Network details (bridge name, autostart) |
| `net-dumpxml <net>` | Full network XML |
| `net-start <net>` | Activate a network |
| `net-destroy <net>` | Deactivate a network (stop) |
| `net-autostart <net>` | Enable auto-start on host boot |
| `net-define <xmlfile>` | Define a new network from XML |
| `net-undefine <net>` | Remove network definition |
| `net-edit <net>` | Edit network XML in $EDITOR |
| `net-update <net> add ip-dhcp-host ...` | Live-update DHCP reservations |
| `net-dhcp-leases <net>` | Show current DHCP leases |

## Storage Pools

| Command | Purpose |
|---------|---------|
| `pool-list --all` | List all storage pools |
| `pool-info <pool>` | Pool capacity/allocation/available |
| `pool-dumpxml <pool>` | Full pool XML |
| `pool-define-as <name> dir --target <path>` | Define a directory pool |
| `pool-define-as <name> netfs --source-host <ip> --source-path <export> --target <mnt>` | Define NFS pool |
| `pool-build <pool>` | Create target directory/mount |
| `pool-start <pool>` | Activate pool |
| `pool-autostart <pool>` | Enable auto-start |
| `pool-destroy <pool>` | Deactivate pool |
| `pool-delete <pool>` | Delete pool storage on disk |
| `pool-undefine <pool>` | Remove pool definition |
| `pool-refresh <pool>` | Rescan pool for new volumes |

## Storage Volumes

| Command | Purpose |
|---------|---------|
| `vol-list <pool>` | List volumes in a pool |
| `vol-info <vol> --pool <pool>` | Volume size and allocation |
| `vol-create-as <pool> <name> <size> --format qcow2` | Create a volume |
| `vol-clone <vol> <newvol> --pool <pool>` | Clone a volume |
| `vol-resize <vol> <size> --pool <pool>` | Resize a volume |
| `vol-delete <vol> --pool <pool>` | Delete a volume |
| `vol-dumpxml <vol> --pool <pool>` | Volume XML metadata |

## Migration

| Command | Purpose |
|---------|---------|
| `migrate --live <domain> <desturi>` | Live migration (managed direct) |
| `migrate --live --p2p <domain> <desturi>` | Peer-to-peer (survives client disconnect) |
| `migrate --live --p2p --tunnelled <domain> <desturi>` | Tunneled through libvirt (single port) |
| `migrate --live --p2p --copy-storage-all <domain> <desturi>` | Migrate with non-shared disk images |
| `migrate --live --p2p --postcopy <domain> <desturi>` | Post-copy migration (lower downtime) |
| `migrate --offline <domain> <desturi>` | Transfer domain definition only |
| `migrate --live --p2p --auto-converge <domain> <desturi>` | Auto-throttle vCPU to help convergence |
| `migrate-setspeed <domain> <bandwidth>` | Set migration bandwidth limit (MiB/s) |

## Host Information

| Command | Purpose |
|---------|---------|
| `nodeinfo` | Host CPU model, sockets, cores, memory |
| `nodememstats` | Host memory statistics |
| `nodecpustats --percent` | Host CPU utilization |
| `capabilities` | Full host/hypervisor capabilities XML |
| `sysinfo` | SMBIOS/DMI system information |
| `hostname` | Hypervisor hostname |
| `uri` | Current connection URI |
| `version` | libvirt and hypervisor versions |

## QEMU Guest Agent

| Command | Purpose |
|---------|---------|
| `qemu-agent-command <domain> '{"execute":"guest-info"}'` | Test agent connectivity |
| `domifaddr <domain> --source agent` | Get IPs via guest agent |
| `domfsinfo <domain>` | Mounted filesystems in guest |
| `domfstrim <domain>` | TRIM/discard unused blocks |
| `domtime <domain>` | Guest clock |
