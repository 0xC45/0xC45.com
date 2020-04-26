+++
title = "OpenBSD Home Router"
+++

## Overview
Recently, I made a home router from scratch using [OpenBSD 6.6](https://www.openbsd.org/66.html), without installing any additional packages, using only what comes with the basic OS installation. Originally, before deciding to "do it from scratch", I had a goal to make a router using open source software in order to improve my network security. After looking at some popular open source firewall and routing projects (mainly [pfSense](https://www.pfsense.org/) and [OPNSense](https://opnsense.org/)), I finally decided to build my own. pfSense and OPNSense both seem like decent software (and I have successfully used both in the past), but this time, I wanted to "do it the hard way" and learn about the services that make up a typical router. Here are some of the cool features that my custom device currently has:

1. It's almost fully open source, down to the BIOS and firmware. Unfortunately, the hardware isn't open source.
1. It ensures that every DNS request leaving my network is encrypted.
1. It caches DNS lookups for every device on my network, improving request speeds.
1. It supports custom local network DNS entries, allowing me to refer to the various services on my network using memorable names, rather than IP addresses.

Of course, because this device is configured and built from scratch, the sky is the limit in terms of potential features and improvements. In the future, I may add improvements such as a VPN server or metrics reporting / analytics.

Before we begin, because I can't really claim to know what I'm doing (I'm not a networking / firewall expert), I must make a disclaimer. This is a toy project. You probably shouldn't use this in production. However, having said that, I have been using this setup (in "production") for several months now and it has been stable. I haven't noticed any internet issues caused by this appliance. In addition, it seems quite secure. OpenBSD has a reputation for being a secure OS and I made every effort to configure the various services correctly. If you notice any mistakes with this configuration (or potential improvements to make), please let me know! Anyway, let's dive into the details.


## Hardware (apu2)
First, I needed an actual machine for my home network appliance. After considering the various options (purchase a device, build something myself, use a virtual machine, etc.) I decided to use an [apu2](https://pcengines.ch/apu2.htm). It is a low-power, relatively inexpensive yet performant solution, which makes it ideal for this kind of application. In addition, it uses an open source BIOS ([SeaBIOS](https://github.com/pcengines/seabios)) and firmware ([coreboot](https://github.com/pcengines/coreboot)). I went with a model that has a quad-core processor, 4GB memory, and 3 separate gigabit NICs. In addition, I purchased a 16GB M-SATA SSD (for the main OS installation), a 4GB SD (for a utility OS installation), a case, and a serial cable (the apu2 does not have a port for graphics output). The total cost was roughly $160.

After the device arrived, the first challenge was connecting to it. Ok, it wasn't actually that challenging. I connected to the apu2 with my OpenBSD netbook and the serial cable:
```
cu -l /dev/cuaU0 -s 115200
```
No matter which software you use to connect to the apu2 over serial, the important setting is the default baud rate, 115200.


## Firmware (coreboot)
After booting up the apu2, I noticed that the BIOS was a bit out of date. It was probably flashed with the current BIOS version at the time of manufacturing, which was likely a while before it ended up in my hands. So, I needed to upgrade the BIOS. The [official instructions](https://pcengines.ch/howto.htm#bios) describe a method to update the BIOS using a PC Engines custom TinyCore Linux distribution. However, since I was already planning to make two different boot disks, one for the router OS and one for a "utility" OS, I decided to setup the utility OS and make it capable of flashing the BIOS.

### Utility OS (Debian)
Given that my apu2 device has two disks, it made sense to create a separate OS installation on the second disk. In addition to being capable of flashing the BIOS, I envision the second "utility" OS as a backup plan, in case I ever misconfigure the main router OS and want to attempt to debug network issues in a fresh environment. I would only boot into the utility OS for special situations. Generally, the device will always be running the main router OS.

For the "utility" OS, I decided to use Debian Linux, because I like Debian. So, I made a Debian USB installer and booted the apu2 from it. There are a few important steps to follow in order to boot the Debian installer into a serial tty (thanks to [TekLager](https://teklager.se/en/knowledge-base/installing-debian-over-serial-console-apu-board/) for the post on how to boot Debian on an apu2).

1. Highlight the "Install" boot option (not "Graphical Install")
1. Press `<tab>` to edit the boot entry
1. Remove `vga=xxx` to disable graphical output
1. Add `console=ttyS0,115200n8` to enable the serial tty
1. Press `<enter>` to boot

Then, I walked through the regular Debian installation. However, because the install target disk is pretty small (4GB), the installer couldn't auto-partition the disk. So, it was necessary to manually setup disk partitions. Here are the settings that I used:

* 200 MB primary ext4 partition (bootable, relatime flag set, mount point: /boot)
* 3.8 GB primary crypto partition
* Then, after setting up the crypto partition (erase disk, set password)
  * 3.8 GB primary ext4 partition (mount point: /)

In order to boot the new Debian installation for the first time, I had to manually edit the boot entry. Like before, add `console=ttyS0,115200n8` to boot into a serial tty. Then, after booting and logging in as root, I configured grub so that it would no longer be necessary to manually edit the boot entry. To do that, edit /etc/default/grub and change the following settings:
```
GRUB_CMDLINE_LINUX='console=ttyS0,19200n8'
GRUB_TERMINAL=serial
```
Finally, run `update-grub` to regenerate the grub boot menu. At this point, the Debian "utility" OS install is complete and it is time to update the BIOS.

### Firmware Update
Updating the BIOS is fairly simple. First, install the flashrom utility. It's available in the Debian package repositories.
```
apt install flashrom
```
Then, download the latest mainline version of the firmware from [https://pcengines.github.io/](https://pcengines.github.io/), write the file to a USB, and mount the USB on the apu2. To flash the firmware (assuming the file is named coreboot.rom), run:
```
flashrom -w coreboot.rom -p internal
```
Then, reboot. For more information on flashing the apu2 firmware, check out the [docs](https://github.com/pcengines/apu2-documentation/blob/master/docs/firmware_flashing.md).


## OS (OpenBSD)
Ok, now it is time to start talking about the actual router OS. For this, I chose OpenBSD. OpenBSD is a popular flavor of BSD that's known for security. Given BSD's general reputation as a networking appliance operating system, OpenBSD seemed like a good fit for the job.

Below (in exhaustive detail) are my installation instructions for OpenBSD 6.6. I decided to make an encrypted disk (why not?) and a custom partitioning strategy. Refer to the OpenBSD docs for additional information.

1. Create an OpenBSD 6.6 installer USB drive.

1. Boot the apu2 from the OpenBSD installer USB drive.

    At the `boot>` prompt, configure and enable a serial tty by entering the following commands.
    ```
    stty com0 115200
    set tty com0
    ```
    Now, press enter at the `boot>` prompt to boot the installer.

1. After the installer boots up, type `s` to run a shell.

1. Erase the target installation disk.

    To determine the identifier for the target installation disk, check `dmesg` (In was sd0 in my case).
    ```
    cd /dev && sh MAKEDEV sd0
    dd if=/dev/urandom of=/dev/rsd0c bs=1m
    ```

1. Setup the disk MBR.
    ```
    fdisk -iy sd0
    ```

1. Create a RAID partition to use as an encrypted pseudo-device.

    Run the disk label editor.

    ```
    disklabel -E sd0
    ```

    In the disk label editor, enter the following commands to create a RAID partition over the entire disk.

    ```
    a a
    <enter>
    <enter>
    RAID
    p
    w
    q
    ```

1. Create the encrypted pseudo-device and set the encryption password.

    ```
    bioctl -c C -l sd0a softraid0
    # use the device identifier created in the previous command (sd3 for me)
    cd /dev && sh MAKEDEV sd3
    ```

1. Clear the first megabyte of the new pseudo-device.

    If you're unlucky, the random data written to the device may look like a real disk header. Clearing out the first megabyte fixes this potential issue.
    ```
    dd if=/dev/zero of=/dev/rsd3c bs=1m count=1
    ```

1. Return to the main installer menu.
    ```
    exit
    ```

1. Type `i` to run the installer.
    ```
    Terminal type? <enter> (the default seemed to work fine for me)
    ```
    Next, set the system hostname and configure the network interfaces.
    ```
    System hostname? firewall (in my case)
    Which nic to configure? em0 (this will be the WAN interface)
    IPv4 address? 192.168.0.2 (in my case)
    Netmask? 255.255.255.0 (in my case)
    IPv6 address? none (in my case)
    Which nic to configure? em1 (this will be the "prod" network interface)
    Symbolic hostname? <enter> (same as system hostname)
    IPv4 address? 192.168.1.1 (in my case)
    Netmask? 255.255.255.0 (in my case)
    IPv6 address? none (in my case)
    Which nic to configure? em2 (this will be the "dev" network interface")
    Symbolic hostname? <enter> (same as system hostname)
    IPv4 address? 192.168.2.1 (in my case)
    Netmask? 255.255.255.0 (in my case)
    IPv6 address? none (in my case)
    Which nic to configure? done
    ```
    Next, set the default route and configure DNS.
    ```
    Default route? 192.168.0.1 (in my case)
    DNS domain name? localdomain (in my case)
    DNS nameservers? 8.8.8.8 8.8.4.4 (for now)
    ```
    Next, there are some miscellaneous tasks: set the root password, enable ssh, setup serial console, create a user, and set your timezone.
    ```
    Password for root account? (something secure)
    Start sshd by default? yes (not necessary, but useful)
    Change default console to com0? yes
    Which speed should com0 use? 115200
    Setup a user? (choose a username)
    Full name? <enter>
    Password? (something secure)
    Allow root ssh login? no
    What timezone? (set your timezone)
    ```
    Next, partition your target installation disk (the encrypted pseudo-device).
    ```
    Which disk is the root disk? sd3 (pseudo-device from previous steps)
    Whole disk MBR? whole
    Disk partitioning? c (setup custom layout)
    ```
    Here are the commands I used to partition my disk.
    ```
    a a
    <enter>
    6G
    <enter>
    /
    a b
    <enter>
    4G
    <enter>
    a d
    <enter>
    0.1G
    <enter>
    /usr/local
    a e
    <enter>
    4G
    <enter>
    /var
    a f
    <enter>
    <enter>
    <enter>
    /tmp
    p
    w
    q
    ```
    My disk ended up being partitioned as follows:
    ```
    #   size       offset     fstype   [fsize   bsize   cpg]
    a:  12594880   64         4.2BSD    2048    16384   1      # /
    b:  8402011    12594944   swap
    c:  31261898   0          unused
    d:  224896     20996960   4.2BSD    2048    16384   1      # /usr/local
    e:  8401984    21221856   4.2BSD    2048    16384   1      # /var
    f:  1622560    29623840   4.2BSD    2048    16384   1      # /tmp
    ```
    Finish partitioning disks.
    ```
    Which disk to initialize? done
    ```
    Before installing the sets, type `!` to exit to a shell and determine the device identifier of the OpenBSD 6.6 installer USB drive. Then, return to the installer.
    ```
    !
    dmesg  # for me, the device identifier ended up being sd2
    exit
    ```
    Next, mount the OpenBSD 6.6 installer USB drive and load the sets.
    ```
    Location of sets? disk
    Already mounted? no
    Which disk contains the install media? sd2 (as just determined)
    Which partition has the install sets? <enter>
    Pathname to the sets? <enter>
    ```
    Next, select which sets to install and install them.
    ```
    Set name(s)? -game* -x* (no need for games or a gui)
    Set name(s)? done
    Continue without verification? yes
    Location of sets? done
    ```

Success! Reboot the device. Don't forget to run `syspatch` after rebooting in order to apply the latest patches.


## Firewall (pf)
Now that we have an apu2 running the latest firmware and OpenBSD, it's time to turn this thing into a router. With OpenBSD, you don't even have to install anything extra in order to make this happen. Everything you need already comes with the basic OS installation.

For my home network, I want two subnets, which I refer to as dev and prod. The dev subnet is an experimental and development zone where I can break things. The prod subnet contains the devices I use on a day-to-day basis. I want both the dev and prod subnets to be able to access the external internet, but I want to block communication between the two subnets. Devices in the dev subnet should not be able to communicate with devices in the prod subnet (and vice versa). Fortunately, the apu2 has three physical NICs. So, one NIC could be used for the WAN network, one NIC could be used for the dev network, and one NIC could be used for the prod network.

To learn how to configure the pf firewall and make this setup a reality, I read the [pf.conf man page](https://man.openbsd.org/pf.conf) and the [router tutorial](https://www.openbsd.org/faq/pf/example1.html). There are three main differences between my configuration and the one described in the tutorial.
1. My configuration has two subnets that are not allowed to talk to each other.
1. My configuration prevents outgoing unencrypted DNS traffic.
1. My router exists on a local network (behind my ISP-supplied modem/router) so I had to allow traffic destined to the gateway at 192.168.0.1.

Here is my /etc/pf.conf that achieves this desired configuration.
```
# interfaces
lo_if = "lo0"
wan_if = "em0"
prod_if = "em1"
dev_if = "em2"

# cidr ranges
prod_range = "192.168.1.0/24"
dev_range = "192.168.2.0/24"

# setup non-routable address list
# note: since this firewall is behind a local network,
#       do not include the default gateway in the table
table <martians> { 0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 169.254.0.0/16     \
                   172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 224.0.0.0/3 \
                   192.168.0.0/16 198.18.0.0/15 198.51.100.0/24        \
                   203.0.113.0/24 !192.168.0.1 }

# drop blocked traffic
set block-policy drop
# set interface for logging
set loginterface $wan_if
# ignore loopback traffic
set skip on $lo_if

# normalize incoming packets
match in all scrub (no-df random-id max-mss 1460)
# perform NAT
match out on $wan_if inet from !($wan_if:network) to any nat-to ($wan_if:0)

# prevent spoofed traffic
antispoof quick for { $wan_if $prod_if $dev_if }

# block non-routable traffic
block in quick on $wan_if from <martians> to any
block return out quick on $wan_if from any to <martians>

# block all traffic
block all
# allow outgoing traffic
pass out inet
# allow traffic from internal networks
pass in on { $prod_if $dev_if } inet
# block traffic from prod <--> dev
block in on $prod_if from $prod_range to $dev_range
block in on $dev_if from $dev_range to $prod_range
# block outgoing unencrypted dns requests
block proto { TCP UDP } from { $prod_range $dev_range } to any port 53
pass proto { TCP UDP } from { $prod_range $dev_range} to self port 53
```

Next, in order to perform NAT (to make this device an actual router), run the following:
```
echo 'net.inet.ip.forwarding=1' >> /etc/sysctl.conf
```
Finally, reboot with `reboot -p`. Now, the router is functional and secured with the pf firewall. At this point, it will work as a minimum viable product. However, every device on the network will need to manually configure its own static IP address, subnet mask, gateway, and DNS server (because there is no DHCP service running to supply these configuration details).


## DHCP (dhcpd)
DHCP is a service that (among other things) gives IP addresses to the devices on your network. So when a device joins the network, it will be given an IP address by the DHCP server running on the router. The DHCP server bundled with OpenBSD 6.6 is dhcpd.

Most devices, upon joining the network, will be given an IP address from within a specified IP range. They could potentially receive any IP address in this range. However, I wanted some devices to be treated specially and always be given the same IP addresses by dhcpd. That way, I can rely on those devices to have predictable IP addresses. It is simpler and easier to define "static" IP addresses all in one place (on the router) rather than configure static IP addresses on each individual device. This way, every IP on my network is defined in one place, on the router. It will be obvious if two devices are configured to have the same static IP (a classic mistake).

In addition to defining the IP address allocations in my network, I configured dhcpd to inform devices on my network of the preferred DNS server for the network, the router itself. We haven't set this up yet, but the router will also function as a caching DNS server.

Here is an example /etc/dhcpd.conf file:
```
# prod network
subnet 192.168.1.0 netmask 255.255.255.0 {
        option routers 192.168.1.1;
        option domain-name-servers 192.168.1.1;
        range 192.168.1.100 192.168.1.149;
        host special-device-1 {
                fixed-address 192.168.1.2;
                hardware ethernet 00:00:00:00:00:00;
        }
}
# dev network
subnet 192.168.2.0 netmask 255.255.255.0 {
        option routers 192.168.2.1;
        option domain-name-servers 192.168.2.1;
        range 192.168.2.100 192.168.2.199;
        host special-device-2 {
                fixed-address 192.168.2.2;
                hardware ethernet 11:11:11:11:11:11;
        }
}
```
This /etc/dhcpd.conf file configures the dhcpd server to hand out IP addresses for the dev and prod networks from within the specified ranges. In addition, it informs devices of the local DNS server (not yet configured). It also configures two "special devices" that will always be given the same IP addresses. dhcpd identifies these two devices by their MAC addresses. For more information check out the [dhcpd.conf man page](https://man.openbsd.org/dhcpd.conf.5).

To enable dhcpd on the em1 and em2 interfaces, run:
```
rcctl enable dhcpd
rcctl set dhcpd flags em1 em2
```
Now, the DHCP server is running, automatically handing out IP addresses and network configuration details to new devices that join the network.


## DNS (unbound)
The last piece (for now) of this home router is DNS. Setting up a caching DNS server on the home router offers several benefits.

1. DNS lookups, if they are already cached, will be quicker. The router will immediately reply with the answer. There will be no need to make a request to some external DNS server on the internet.
1. By ensuring all outgoing DNS lookups are performed by the router, it is easy to enforce a standard of security / privacy. I have configured the DNS caching server running on the router to always encrypt outgoing DNS requests. Of course, any device on the network is free to use other DNS servers besides the router. However, the pf firewall configuration blocks outgoing requests on port 53, the port commonly used for unencrypted DNS.
1. It is possible to configure custom DNS entries for the local network. The "special devices" configured in the DHCP server to always have the same IP addresses can be given DNS entries on the local network. For example, if I have a server running on my home network, I can give it a memorable DNS entry that will always resolve to its "static" IP address defined in the DHCP configuration.

Here is an example unbound config file (located at /var/unbound/etc/unbound.conf):
```
server:
        interface: 127.0.0.1
        interface: 192.168.1.1
        interface: 192.168.2.1
        access-control: 127.0.0.0/8 allow
        access-control: 192.168.1.0/24 allow
        access-control: 192.168.2.0/24 allow
        hide-identity: yes
        hide-version: yes
        do-not-query-localhost: no
        tls-cert-bundle: "/etc/ssl/cert.pem"
        local-data: "special-device-1.localdomain A 192.168.1.2"
        local-data: "special-device-2.localdomain A 192.168.2.2"

forward-zone:
        name: "."
        forward-tls-upstream: yes
        forward-addr: 8.8.8.8@853
        forward-addr: 8.8.4.4@853
```

To enable the unbound DNS caching server, run:
```
rcctl enable unbound
```
Now, the DNS caching server is running. Devices that join the network will automatically use this DNS server (unless otherwise configured) because the DHCP server will inform new devices that this is the preferred DNS server for the network. Also, by using this DNS server, the custom local DNS entries will resolve properly. For example, when any device on the local network makes a DNS lookup for `special-device-1.localdoman`, it resolves to 192.168.1.2. Lastly, all DNS lookups are cached by the unbound service. This will improve the latency of repeat DNS lookups.

## Conclusion
So, that's pretty much it. At this point, the device functions as a router, firewall, DHCP server, and caching DNS server. The software it runs is entirely open source. It maintains several custom DNS entries for services running on my local network. Every outgoing DNS request is guaranteed to be encrypted. For the past few months, I have used this device in my home network and it has been working great. It is secure, performant, minimal, and easy to maintain (only three config files).

In the future, I will likely add more features to this device. It might be useful to add a VPN service in order to allow me to access my home network from anywhere on the internet. Also, it would be neat to setup some logging / metrics collection to analyze network traffic. However, at this point, all of the original project goals have been met. There are probably many easier ways to build a home router, but I learned a lot doing it this way. For now, I am quite happy with this device.
