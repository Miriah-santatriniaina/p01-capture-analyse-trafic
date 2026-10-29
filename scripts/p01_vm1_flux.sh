#!/bin/bash
# P01 - gestion des flux LAN1 -> vm3 et capture (a executer en root sur vm1)
#   sudo bash p01_vm1_flux.sh offensif | defensif | reset | capture NOM [filtre]

VM3="192.168.20.10"
LAN1="192.168.10.0/24"
IF_LAN1="ens37"
IF_LAN2="ens38"
CHAIN="P01"

init_chain() {
  iptables -N $CHAIN 2>/dev/null || true
  iptables -F $CHAIN
  iptables -C FORWARD -j $CHAIN 2>/dev/null || iptables -I FORWARD 1 -j $CHAIN
  iptables -A $CHAIN -i $IF_LAN2 -o $IF_LAN1 -m state --state ESTABLISHED,RELATED -j ACCEPT
}

case "$1" in
  offensif)
    init_chain
    iptables -A $CHAIN -i $IF_LAN1 -o $IF_LAN2 -s $LAN1 -d $VM3 -p tcp \
      -m multiport --dports 21,22,23,80,443,40000:40010 -j ACCEPT
    echo "Phase offensive : flux en clair ET chiffres ouverts vers $VM3"
    ;;
  defensif)
    init_chain
    iptables -A $CHAIN -i $IF_LAN1 -o $IF_LAN2 -s $LAN1 -d $VM3 -p tcp \
      -m multiport --dports 22,443 -j ACCEPT
    iptables -A $CHAIN -i $IF_LAN1 -o $IF_LAN2 -s $LAN1 -d $VM3 -p tcp \
      -m multiport --dports 21,23,80 -j LOG --log-prefix "P01-BLOCK " --log-level 4
    echo "Phase defensive : seuls SSH (22) et HTTPS (443) passent vers $VM3"
    ;;
  reset)
    iptables -D FORWARD -j $CHAIN 2>/dev/null || true
    iptables -F $CHAIN 2>/dev/null || true
    iptables -X $CHAIN 2>/dev/null || true
    echo "Regles P01 supprimees"
    ;;
  capture)
    NOM="${2:?Donnez un nom de capture, ex: clair_http}"
    FILTRE="${3:-host $VM3}"
    mkdir -p ~/captures
    echo "Capture sur $IF_LAN2 -> ~/captures/$NOM.pcap (Ctrl+C pour arreter)"
    tcpdump -i $IF_LAN2 -nn -s 0 -w ~/captures/$NOM.pcap $FILTRE
    ;;
  *)
    echo "Usage : $0 {offensif|defensif|reset|capture NOM [filtre]}"
    exit 1
    ;;
esac

iptables -L P01 -n -v --line-numbers 2>/dev/null
