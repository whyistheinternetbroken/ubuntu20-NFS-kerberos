declare -r IDMAP_PATH="/usr/sbin/rpc.idmapd"

idmap_pid=$(pgrep -nxf "${IDMAP_PATH} .*") || {
  sudo /usr/sbin/rpc.idmapd
  >&2 echo "NFS ID map service restarted."
  sudo nfsidmap -c
  exit 1
}
