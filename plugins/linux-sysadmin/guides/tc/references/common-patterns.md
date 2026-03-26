# tc Common Patterns

Each block is copy-paste-ready. All tc rules require root (`sudo`). Rules are not persistent
across reboots; see the persistence pattern at the end for making them survive restarts.

---

## 1. Simple Bandwidth Limit with TBF

Limits all egress traffic on an interface to a fixed rate. TBF is the simplest rate limiter.

```bash
# Limit eth0 to 10 Mbit/s
# burst: token bucket size (must be >= rate / kernel HZ; 32kbit is safe for most rates)
# latency: max time a packet can sit in the queue before being dropped
sudo tc qdisc add dev eth0 root tbf rate 10mbit burst 32kbit latency 400ms

# Verify
tc -s qdisc show dev eth0

# Remove
sudo tc qdisc del dev eth0 root
```

---

## 2. Network Latency Simulation with netem

Simulates WAN conditions for testing. Affects egress only.

```bash
# Fixed delay: 100ms
sudo tc qdisc add dev eth0 root netem delay 100ms

# Delay with jitter: 100ms +/- 20ms, normal distribution
sudo tc qdisc add dev eth0 root netem delay 100ms 20ms distribution normal

# Packet loss: 5%
sudo tc qdisc add dev eth0 root netem loss 5%

# Combined: 50ms delay + 2% loss + 0.1% corruption
sudo tc qdisc add dev eth0 root netem delay 50ms loss 2% corrupt 0.1%

# Packet duplication: 1%
sudo tc qdisc add dev eth0 root netem duplicate 1%

# Packet reordering: 25% of packets sent immediately, rest delayed 10ms
sudo tc qdisc add dev eth0 root netem delay 10ms reorder 25% 50%

# Change existing netem parameters (use 'change', not 'add')
sudo tc qdisc change dev eth0 root netem delay 200ms

# Remove
sudo tc qdisc del dev eth0 root
```

---

## 3. HTB Bandwidth Sharing with Classes

Allocates bandwidth to different traffic classes. Each class gets a guaranteed rate
and can borrow up to ceil when other classes are idle.

```bash
# 1. Root qdisc: HTB with default class 1:30 for unclassified traffic
sudo tc qdisc add dev eth0 root handle 1: htb default 30

# 2. Root class: total bandwidth cap
sudo tc class add dev eth0 parent 1: classid 1:1 htb rate 100mbit ceil 100mbit

# 3. Child classes: guaranteed rate + ceiling (borrow limit)
# High priority (e.g., SSH, VoIP): 30 Mbit guaranteed, can burst to 100 Mbit
sudo tc class add dev eth0 parent 1:1 classid 1:10 htb rate 30mbit ceil 100mbit prio 1

# Normal priority (e.g., web traffic): 50 Mbit guaranteed
sudo tc class add dev eth0 parent 1:1 classid 1:20 htb rate 50mbit ceil 100mbit prio 2

# Low priority (e.g., bulk downloads): 20 Mbit guaranteed
sudo tc class add dev eth0 parent 1:1 classid 1:30 htb rate 20mbit ceil 100mbit prio 3

# 4. Add fair queuing inside each leaf class to prevent single-flow dominance
sudo tc qdisc add dev eth0 parent 1:10 handle 10: fq_codel
sudo tc qdisc add dev eth0 parent 1:20 handle 20: fq_codel
sudo tc qdisc add dev eth0 parent 1:30 handle 30: fq_codel

# 5. Filters: classify by destination port
# SSH (port 22) -> class 1:10
sudo tc filter add dev eth0 parent 1: protocol ip prio 1 u32 \
  match ip dport 22 0xffff flowid 1:10

# HTTP/HTTPS (ports 80, 443) -> class 1:20
sudo tc filter add dev eth0 parent 1: protocol ip prio 2 u32 \
  match ip dport 80 0xffff flowid 1:20
sudo tc filter add dev eth0 parent 1: protocol ip prio 2 u32 \
  match ip dport 443 0xffff flowid 1:20

# Everything else falls to default class 1:30

# Verify the tree
tc -g class show dev eth0
tc -s class show dev eth0
```

---

## 4. Filter by Source/Destination IP

```bash
# Route traffic from 192.168.1.100 to class 1:10
sudo tc filter add dev eth0 parent 1: protocol ip prio 1 u32 \
  match ip src 192.168.1.100/32 flowid 1:10

# Route traffic to subnet 10.0.0.0/24 to class 1:20
sudo tc filter add dev eth0 parent 1: protocol ip prio 2 u32 \
  match ip dst 10.0.0.0/24 flowid 1:20

# Filter by iptables mark (requires iptables MARK target)
# First mark packets: iptables -t mangle -A OUTPUT -p tcp --dport 22 -j MARK --set-mark 1
sudo tc filter add dev eth0 parent 1: protocol ip prio 1 handle 1 fw flowid 1:10
```

---

## 5. Ingress Policing with IFB

tc only shapes egress by default. To shape or simulate conditions on ingress,
redirect incoming packets to an Intermediate Functional Block (IFB) device.

```bash
# 1. Load the ifb module and bring up ifb0
sudo modprobe ifb numifbs=1
sudo ip link set dev ifb0 up

# 2. Redirect all ingress traffic from eth0 to ifb0
sudo tc qdisc add dev eth0 handle ffff: ingress
sudo tc filter add dev eth0 parent ffff: protocol ip u32 \
  match u32 0 0 action mirred egress redirect dev ifb0

# 3. Now shape ifb0 as if it were egress (this controls incoming traffic on eth0)
# Example: add 50ms delay to incoming traffic
sudo tc qdisc add dev ifb0 root netem delay 50ms

# Or: limit incoming bandwidth to 5 Mbit/s
sudo tc qdisc add dev ifb0 root tbf rate 5mbit burst 32kbit latency 400ms

# Verify
tc -s qdisc show dev ifb0

# Cleanup
sudo tc qdisc del dev eth0 ingress
sudo tc qdisc del dev ifb0 root
sudo ip link set dev ifb0 down
```

---

## 6. Combining HTB + netem (Bandwidth + Latency)

Shape bandwidth with HTB and add latency simulation as a leaf qdisc.

```bash
# Root HTB
sudo tc qdisc add dev eth0 root handle 1: htb default 10
sudo tc class add dev eth0 parent 1: classid 1:1 htb rate 10mbit
sudo tc class add dev eth0 parent 1:1 classid 1:10 htb rate 10mbit

# Attach netem as leaf of the HTB class (simulates a slow WAN link)
sudo tc qdisc add dev eth0 parent 1:10 handle 10: netem delay 50ms 10ms loss 1%
```

---

## 7. Rate Limiting a Single Application with cgroups

Shape traffic from a specific process using cgroups and the `net_cls` controller.

```bash
# 1. Create a cgroup and assign a classid
sudo mkdir -p /sys/fs/cgroup/net_cls/limited
echo 0x00010010 | sudo tee /sys/fs/cgroup/net_cls/limited/net_cls.classid

# 2. Set up HTB with matching class
sudo tc qdisc add dev eth0 root handle 1: htb default 30
sudo tc class add dev eth0 parent 1: classid 1:1 htb rate 100mbit
sudo tc class add dev eth0 parent 1:1 classid 1:10 htb rate 1mbit ceil 1mbit

# 3. Filter by cgroup classid
sudo tc filter add dev eth0 parent 1: protocol ip prio 1 handle 1: cgroup

# 4. Run a process in the cgroup
sudo cgexec -g net_cls:limited curl -O http://example.com/largefile
```

---

## 8. Persistence Script (systemd)

Make tc rules survive reboots by creating a systemd service.

```ini
# /etc/systemd/system/tc-rules.service
[Unit]
Description=Traffic Control Rules
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/tc-rules.sh start
ExecStop=/usr/local/bin/tc-rules.sh stop

[Install]
WantedBy=multi-user.target
```

```bash
#!/bin/bash
# /usr/local/bin/tc-rules.sh
DEV=eth0

case "$1" in
  start)
    tc qdisc add dev $DEV root tbf rate 100mbit burst 32kbit latency 400ms
    ;;
  stop)
    tc qdisc del dev $DEV root 2>/dev/null
    ;;
  *)
    echo "Usage: $0 {start|stop}"
    exit 1
    ;;
esac
```

Enable with:
```bash
sudo chmod +x /usr/local/bin/tc-rules.sh
sudo systemctl daemon-reload
sudo systemctl enable --now tc-rules.service
```

---

## 9. Quick Diagnostics

```bash
# Show everything on all interfaces
tc qdisc show
tc class show dev eth0
tc filter show dev eth0

# Statistics (packets sent, dropped, overlimits)
tc -s qdisc show dev eth0
tc -s class show dev eth0

# Show class tree as ASCII graph
tc -g class show dev eth0

# Watch stats live (combined with watch)
watch -n 1 'tc -s qdisc show dev eth0'

# Verify current default qdisc
sysctl net.core.default_qdisc
# Change system default (persists in /etc/sysctl.conf)
echo 'net.core.default_qdisc = fq_codel' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```
