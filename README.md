# CascadingOpenvpnConnect
Scripts that allow cascading vpn connections ( You -> Server A -> Server B -> Server C )

#For Linux use the updown.sh

This script called updown.sh can be used to create a cascading connection to multiple vpn servers
You basically start a vpn connection to multiple servers and this script will create routes so it will create a 
vpn chain for you


#Example:
1
sudo openvpn --config eu.fr1.cdn.internetz.me.ovpn --script-security 2 --route remote_host --persist-tun --up updown.sh --down updown.sh --route-noexec

2
sudo openvpn --config eu.fr4.cdn.internetz.me.ovpn --script-security 2 --route remote_host --persist-tun --up updown.sh --down updown.sh --route-noexec --setenv hopid 2 --setenv prevgw 10.9.1.1

3
sudo openvpn --config am.us4.cdn.internetz.me.ovpn --script-security 2 --route remote_host --persist-tun --up updown.sh --down updown.sh --route-noexec --setenv hopid 3 --setenv prevgw 10.9


