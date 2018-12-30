logger -t "rc.firstboot" "Expanding root partition"

# Detect root partition device
ROOT_PART=$(mount | sed -n 's|^/dev/\(.*\) on / .*|\1|p')
if [ -z "$ROOT_PART" ] ; then
  log_warning_msg "unable to detect root partition device"
  return 1
fi

# Extract root device name
case "${ROOT_PART}" in
  mmcblk0*) ROOT_DEV=mmcblk0 ;;
  sda*)     ROOT_DEV=sda ;;
esac

# Check detected root partition name
PART_NUM=$(echo ${ROOT_PART} | grep -o '[1-9][0-9]*$')
if [ "$PART_NUM" = "$ROOT_PART" ] ; then
  logger -t "rc.firstboot" "$ROOT_PART is not an SD card. Don't know how to expand"
  return 0
fi

# NOTE: the NOOBS partition layout confuses parted. For now, let's only
# agree to work with a sufficiently simple partition layout
if [ "$PART_NUM" -gt 2 ] ; then
  logger -t "rc.firstboot" "Your partition layout is not currently supported by this tool."
  return 0
fi

# Check if last partition number
LAST_PART_NUM=$(parted /dev/${ROOT_DEV} -ms unit s p | tail -n 1 | cut -f 1 -d:)
if [ $LAST_PART_NUM -ne $PART_NUM ]; then
  logger -t "rc.firstboot" "$ROOT_PART is not the last partition. Don't know how to expand"
  return 0
fi

# Get the starting offset of the root partition
PART_START=$(parted /dev/${ROOT_DEV} -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d: | sed 's/[^0-9]//g')
if [ -z "$PART_START" ] ; then
  logger -t "rc.firstboot" "${ROOT_DEV} unable to get starting sector of the partition"
  return 1
fi

# Get the possible last sector for the root partition
PART_LAST=$(fdisk -l /dev/${ROOT_DEV} | grep '^Disk.*sectors' | awk '{ print $7 - 1 }')
if [ -z "$PART_LAST" ] ; then
  logger -t "rc.firstboot" "${ROOT_DEV} unable to get last sector of the partition"
  return 1
fi

### Since rc.local is run with "sh -e", let's add "|| true" to prevent premature exit
fdisk /dev/${ROOT_DEV} <<EOF2 || true
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START
$PART_LAST
p
w
EOF2

# Reload the partition table, resize root filesystem then remove resizing code from this file
partprobe &&
  resize2fs /dev/${ROOT_PART} &&
  logger -t "rc.firstboot" "Root partition successfully resized."
