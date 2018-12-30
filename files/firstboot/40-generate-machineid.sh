logger -t "rc.firstboot" "Generating D-Bus machine-id"
rm -f /var/lib/dbus/machine-id 
dbus-uuidgen --ensure
