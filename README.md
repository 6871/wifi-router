# Ethernet to Wi-Fi Adapter

Configure an Ubuntu host that has an ethernet port and Wi-Fi support (such as
a Raspberry Pi) as a NAT router to connect any device with an ethernet port to
a Wi-Fi network.

```
                  Ethernet                            Wi-Fi
                     .                                  .
   Client Device     .     Ethernet to Wi-Fi Adapter    .
 (e.g. router WAN)   .        (e.g. Raspberry Pi)       .  \|/ ... Internet
+-----------------+  .  +--------------------+-------+  .   |
|            eth0 |-----| eth0               | wlan0 |------+
+-----------------+     | 192.168.254.254/24 |       | <--- DHCP
                        +--------------------+-------+
                    <---| DHCP (dnsmasq)     |
                        |   192.168.254.100  |
                        |   ...              |
                        |   192.168.254.199  |
                        +--------------------+
```

A [Unicorn HAT HD](https://github.com/pimoroni/unicorn-hat-hd) LED display can
be used to view the following network status messages:

![led_output.gif](led_output.gif)

> LED display driver: [matrix_display](https://github.com/6871/matrix-display)

## Example Uses

### WAN backup link over Wi-Fi

If a network's internet-facing router has a suitable WAN port, connect this
device to provide an alternate internet connection via a Wi-Fi network such as
a mobile phone hotspot.

Routers with multi-WAN support can failover to this device; for example:

* [EdgeRouter - WAN Load-Balancing](https://help.ubnt.com/hc/en-us/articles/205145990-EdgeRouter-WAN-Load-Balancing)

### Wi-Fi enable ethernet-only devices

Connect any device with an ethernet port (computer, IP camera, etc...) to the
internet via a Wi-Fi network.

### Internet status monitor

Use a [Unicorn HAT HD](https://github.com/pimoroni/unicorn-hat-hd) LED display
to show if internet connectivity is up or down. 

# To Install

The install assumes:
 
* The following network interfaces are present (verify with ```ip link```):
  * ```eth0``` for LAN (ethernet)
  * ```wlan0``` for WAN (Wi-Fi)
* Directory ```/home/ubuntu``` exists

## 1. Setup Device OS

[Creating an Ubuntu OS SD card for a Raspberry Pi](#creating-an-ubuntu-os-sd-card-for-a-raspberry-pi)

## 2. Clone wifi-router repository

```shell script
git clone https://github.com/6871/wifi-router
cd wifi-router
```

## 3. Run Install Script(s)

For a full install run [```install_all.sh```](#install_allsh).

For a minimal install run [```install_network.sh```](#install_networksh).

### install_all.sh

Installs all components ([```install_network.sh```](#install_networksh),
[```install_status_service.sh```](#install_status_servicesh) and
[```install_led_display_service.sh```](#install_led_display_servicesh)).

Use the device console for first run as SSH connections will drop.

```shell script
# Leave blank to be prompted for value(s)
wifi_name=''
wifi_password=''  # if set, must set wifi_name too
sudo ./install_all.sh "${wifi_name}" "${wifi_password}" 2>&1 | tee install.log
```

> ```2>&1``` writes stderr (2) to stdout (1) so both go to tee

> ```tee``` writes its input to both console and file

## install_status_service.sh

Optional service to periodically update a status file that the LED display
driver service can poll.

```shell script
sudo ./install_status_service.sh 2>&1 | tee install.log
```

> The refresh rate is set by ```RestartSec``` in
  [status/services/wifi-router-status.service](status/services/wifi-router-status.service)

## install_led_display_service.sh

Optional service that polls the file generated by the status service and
presents this on a
[Unicorn HAT HD](https://github.com/pimoroni/unicorn-hat-hd) LED display.

```shell script
sudo ./install_led_display_service.sh 2>&1 | tee install.log
```

> The refresh rate is set for each ```add_row``` call in
  [led_display/python/display.py](led_display/python/display.py)

## install_network.sh

This is the main install and configuration script; it can be re-run to change
Wi-Fi network settings.

Use the device console for first run as SSH connections will drop.

```shell script
# Leave blank to be prompted for value(s)
wifi_name=''
wifi_password=''  # if set, must set wifi_name too
sudo ./install_network.sh "${wifi_name}" "${wifi_password}" 2>&1 | tee install.log
```

# To Use

The device will connect automatically to the configured Wi-Fi network.

Port ```eth0``` is configured for network ```192.168.254.0/24``` and assigned
IP address ```192.168.254.254``` (the gateway address for clients to use).

DHCP clients connected to ```eth0``` will receive an IP address in the range
```192.168.254.100``` - ```192.168.254.199```.
 
A client device connected to ```eth0``` will have internet access via the
gateway.

In the event of issues refer to [System Configuration](#system-configuration)
below.

# Appendices

## System Configuration

### Visible Wi-Fi networks
```shell script
sudo iwlist scan | grep -i SSID
```

### Network Configuration

```shell script
hostname -I

ip addr
ip link

cat /etc/netplan/01-lan.yaml
cat /etc/netplan/02-wan.yaml

tail /etc/dnsmasq.conf

sysctl -n net.ipv4.ip_forward

sudo iptables --table nat --list --verbose
```

### Service Status
```shell script
systemctl list-units --type-service

systemctl status wifi-router-status.service
systemctl status wifi-router-display.service

cat /etc/systemd/system/wifi-router-status.service
cat /etc/systemd/system/wifi-router-display.service

cat /home/ubuntu/wifi-router-status.json  # generated by wifi-router-status.service

tail -F /var/log/syslog
```

## Creating an Ubuntu OS SD card for a Raspberry Pi

1. Download the OS image: https://ubuntu.com/download/raspberry-pi

2. Insert the SD card and identify the SD card device; ```lsblk``` can be used
for this

3. For the write operation to work as expected, ```umount``` any sub-devices;
for example, if using ```/dev/sda``` it may have child mounts```/dev/sda1```
and ```/dev/sda2```, in which case run: ```umount /dev/sda2``` and
```umount /dev/sda1```

4. Run the following to write the downloaded OS to the SD card:

```shell script
# Set target_device to your SD card device (e.g.: target_device=/dev/sda)
target_device=
```
```shell script
# Verify target_device is the target SD card
lsblk "${target_device}"
```
```shell script
# Ensure architecture is correct (here arm64 raspi3) and write it to the card
xzcat ubuntu-19.10.1-preinstalled-server-arm64+raspi3.img.xz \
  | sudo dd of="${target_device}" bs=4M status=progress
```
```shell script
# Eject device
sudo eject "${target_device}"
```

The Raspberry Pi can now be booted from the SD card.

### First-boot setup

On first login the ```ubuntu``` user's password must be changed from
```ubuntu```.

> Login will fail if cloud-init scripts are still running

Install the latest OS updates:

```shell script
# If there are locks, try: sudo reboot
sudo apt update
sudo apt upgrade --yes
```

To add github public key(s) for SSH access:

```shell script
github_user=
curl "https://github.com/${github_user}.keys" >> ~/.ssh/authorized_keys
```

To view current IP configuration:

```shell script
ip link
ip addr
hostname -I
```

