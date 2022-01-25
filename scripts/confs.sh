# conf_networking(){
  cat <<EOF > $MNT/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
# iface eth0 inet dhcp
iface eth0 inet static
  address 192.168.8.144
  netmask 255.255.255.0
  gateway 192.168.8.1
EOF

  cat <<EOF > $MNT/etc/resolv.conf
nameserver 192.168.8.145
search myctl.space
EOF
# }
