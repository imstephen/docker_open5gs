#!/bin/bash

# BSD 2-Clause License

# Copyright (c) 2020, Supreeth Herle
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:

# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.

# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export IP_ADDR=$(awk 'END{print $1}' /etc/hosts)
export IF_NAME=$(ip r | awk '/default/ { print $5 }')

# use nftables instead of iptables
update-alternatives --set iptables `which iptables-nft`
update-alternatives --set ip6tables `which ip6tables-nft`

# Remove UPF Interfaces if they exist
ip link delete $UPF2_PRIVATE_APN_IF_NAME 2>/dev/null

# Validate interface names based on UPF2_TUNTAP_MODE
if [ "$UPF2_TUNTAP_MODE" = "tap" ]; then
    if [[ "$UPF2_PRIVATE_APN_IF_NAME" != *"tap"* ]] || [[ "$UPF_IMS_APN_IF_NAME" != *"tap"* ]]; then
        echo "Error: When UPF2_TUNTAP_MODE is 'tap', both UPF2_PRIVATE_APN_IF_NAME and UPF_IMS_APN_IF_NAME must contain 'tap'"
        exit 1
    fi
elif [ "$UPF2_TUNTAP_MODE" = "tun" ]; then
    if [[ "$UPF2_PRIVATE_APN_IF_NAME" == *"tap"* ]] || [[ "$UPF_IMS_APN_IF_NAME" == *"tap"* ]]; then
        echo "Error: When UPF2_TUNTAP_MODE is 'tun', UPF2_PRIVATE_APN_IF_NAME and UPF_IMS_APN_IF_NAME must not contain 'tap'"
        exit 1
    fi
else
    echo "Error: UPF2_TUNTAP_MODE must be either 'tap' or 'tun'"
    exit 1
fi

python3 /mnt/upf/tun_if.py --tun_ifname $UPF2_PRIVATE_APN_IF_NAME --tun_ifmode $UPF2_TUNTAP_MODE --ipv4_range $UE_IPV4_PRIVATE --ipv6_range 2001:230:fafe::/48

UE_IPV4_PRIVATE_APN_GATEWAY_IP=$(python3 /mnt/upf/ip_utils.py --ip_range $UE_IPV4_PRIVATE)

cp /mnt/upf/upf2.yaml install/etc/open5gs/upf.yaml

sed -i 's|UPF2_IP|'$UPF2_IP'|g' install/etc/open5gs/upf.yaml
sed -i 's|SMF2_IP|'$SMF2_IP'|g' install/etc/open5gs/upf.yaml
sed -i 's|UE_IPV4_PRIVATE_APN_GATEWAY_IP|'$UE_IPV4_PRIVATE_APN_GATEWAY_IP'|g' install/etc/open5gs/upf.yaml
sed -i 's|UE_IPV4_PRIVATE_APN_SUBNET|'$UE_IPV4_PRIVATE'|g' install/etc/open5gs/upf.yaml
sed -i 's|UPF2_ADVERTISE_IP|'$UPF2_ADVERTISE_IP'|g' install/etc/open5gs/upf.yaml
sed -i 's|MAX_NUM_UE|'$MAX_NUM_UE'|g' install/etc/open5gs/upf.yaml
sed -i 's|UPF2_PRIVATE_APN_IF_NAME|'$UPF2_PRIVATE_APN_IF_NAME'|g' install/etc/open5gs/upf.yaml

# Sync docker time
#ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
