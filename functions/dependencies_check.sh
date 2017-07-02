# dependencies_check
# $@	Dependnecy files to check
#
# Each dependency is in the form of a tool to test for, optionally followed by
# a : and the name of a package if the package on a Debian-ish system is not
# named for the tool (i.e., qemu-user-static).
dependencies_check() {
  local missing

  if [[ -f "$1" ]]; then
    for dep in $(cat "$1"); do
      if ! hash ${dep%:*} 2>/dev/null; then
        missing="${missing:+$missing }${dep#*:}"
      fi
    done
  fi

  if [[ "$missing" ]]; then
    echo "Reqired dependencies not installed"
    echo
    echo "This can be resolved on Debian/Raspbian systems by installing:"
    echo "$missing"
    false
  fi
}
