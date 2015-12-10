#!/bin/bash
#
# This script called updown.sh can be used to create a cascading connection to multiple vpn servers
# You basically start a vpn connection to multiple servers and this script will create routes so it will create a 
# proxy chain for you
#
#
# Example:
# 1:
# sudo openvpn --config eu.fr1.cdn.internetz.me.ovpn --script-security 2 --route remote_host --persist-tun --up updown.sh --down updown.sh --route-noexec
#
# 2 ( script nr 1 will output this command for you
# sudo openvpn --config eu.fr4.cdn.internetz.me.ovpn --script-security 2 --route remote_host --persist-tun --up updown.sh --down updown.sh --route-noexec --setenv hopid 2 --setenv prevgw 10.9.1.1
#
# 3
# sudo openvpn --config am.us4.cdn.internetz.me.ovpn --script-security 2 --route remote_host --persist-tun --up updown.sh --down updown.sh --route-noexec --setenv hopid 3 --setenv prevgw 10.9


# save the name of this script to a variable ( intended name updown.sh )
script_name=$0

# maximum number of hops
# be careful: number of additional routes per hop: 2^($hopid) + 1
MAX_HOPID=5

# disabling resolveconf cause most users are on systems such as kali
disable_resolvconf=1

# all messages from this script start with ##
# print $1 with prefix to STDOUT
function updown_output {
    echo "## updown.sh: $1"
}

# all messages from this script start with ##
# print $1 with prefix to STDERR
function updown_output_error {
    echo "## updown.sh: ERROR: $1">&2
}


# check whether $1 is an IPv4 address (exit on error)
# $1: the IP address to check
# $2: the environment variable name for error message
function check_ipv4_regex {
    regex_255="([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])" # 0-255
    regex_ipv4="^($regex_255.){3}$regex_255$"
    if ! [[ $1 =~ $regex_ipv4 ]]
    then
        updown_output_error "$2 ('$1') is not an IPv4 address"
        updown_output "ABORT"
        exit 1
    fi
}


updown_output "STARTED"
updown_output "hop id:              	$hopid (default: 1)"
updown_output "gateway of last hop: 	$prevgw (default: local gateway)"
updown_output "local gateway:           $route_net_gateway"
updown_output "VPN: local IP address:   $ifconfig_local"
updown_output "VPN: local netmask:      $ifconfig_netmask"
updown_output "VPN: local gateway:      $route_vpn_gateway"
updown_output "VPN: vpn IP address:     $route_network_1"

# if hopid is not set, assume it to be 1
if [[ ${hopid} == "" ]]
then
    updown_output "Notice: You didn't set 'hopid'. Assuming this to be the first hop (hopid=1)."
    hopid=1
fi

# check whether environment variable hopid is a number
regex_number="^[0-9]+$"
if ! [[ ${hopid} =~ $regex_number ]]
then
    updown_output_error "hopid ('$hopid') is not a number!"
    updown_output_error "See updown.sh for the usage of this script."
    updown_output "ABORT"
    exit 1
fi

# check whether hopid <= MAX_HOPID
if [[ ${hopid} -gt ${MAX_HOPID} ]]
then
    updown_output_error "Do not use more than $MAX_HOPID hops."
    updown_output "ABORT"
    exit 1
fi

# check whether all environment variables needed are IPv4 addresses
check_ipv4_regex ${route_vpn_gateway} "route_vpn_gateway"
check_ipv4_regex ${route_network_1} "route_network_1"
vpn_server_ip=${route_network_1}

# make sure we have a valid gateway
# (prevgw is the route_vpn_gateway from the previous hop)
if [[ ${prevgw} == "" ]]
then
    if [[ ${hopid} -eq 1 ]]
    then
        # for the first hop, use the local gateway
        updown_output "Notice: You didn't set the previous gateway. The gateway of your local network ('$route_net_gateway') will be used."
        prevgw=${route_net_gateway}
    else
        updown_output_error "You didn't set the previous gateway."
        updown_output_error "See updown.sh for the usage of this script."
    fi
fi
check_ipv4_regex ${prevgw} "prevgw"

# determine whether to add or del our routes
if [[ "$script_type" == "up" ]]
then
    add_del="add"
elif [[ "$script_type" == "down" ]]
then
    add_del="delete"
else
    updown_output_error "script_type is not 'up' or 'down'!"
    updown_output_error "See updown.sh for the usage of this script."
    updown_output "ABORT"
    exit 1
fi

# add route to (next) vpn server via previous gateway
IP=$(which ip)
route_cmd="$IP route $add_del $vpn_server_ip via $prevgw"
updown_output "executing: '$route_cmd'"
eval ${route_cmd}

# calculate and execute routes
for (( i=0; i < $((2 ** $hopid)); i++ ))
do
    net="$(( $i << $((8 - $hopid)) )).0.0.0"
    route_cmd="$IP route $add_del $net/$hopid via $route_vpn_gateway"
    updown_output "executing: '$route_cmd'"
    eval ${route_cmd}
done

# print hint for the next connection (on up)
if [[ "$script_type" == "up" ]]
then
    if [[ ${hopid} -le ${MAX_HOPID} ]]
    then
        next_hop_number=$((hopid+1))
        next_gateway=${route_vpn_gateway}
        updown_output "HINT: For the next hop, start openvpn with the following options:"
        updown_output "HINT: openvpn --config <config.ovpn> --script-security 2 --route remote_host --persist-tun --up $script_name --down $script_name --route-noexec --setenv hopid $next_hop_number --setenv prevgw $next_gateway"
    else
        updown_output "Notice: Maximum numbers of hops reached. Don't start another connection."
    fi
fi

# update DNS settings
if ! [ "$disable_resolvconf" ]
then
    resolvconf_cmd="/etc/openvpn/update-resolv-conf"
    updown_output "execuding: '$resolvconf_cmd'"
    eval ${resolvconf_cmd}
fi

updown_output "FINISHED"
