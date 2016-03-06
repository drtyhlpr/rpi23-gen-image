#!/bin/sh
ip6tables -F
ip6tables -X
ip6tables -Z

for table in $(</proc/net/ip6_tables_names)
do
  ip6tables -t \$table -F
  ip6tables -t \$table -X
  ip6tables -t \$table -Z
done

ip6tables -P INPUT ACCEPT
ip6tables -P OUTPUT ACCEPT
ip6tables -P FORWARD ACCEPT
