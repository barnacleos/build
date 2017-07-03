apply_patches() {
  if [ ! -d "$1" ]; then
    echo "Patches directory does not exist: $1"
    exit 1
  fi

  pushd "$ROOTFS_DIR" > /dev/null

  export QUILT_PATCHES="$1"

  rm -rf   .pc
  mkdir -p .pc

  quilt upgrade
  RC=0
  quilt push -a || RC=$?

  case "$RC" in
  0|2)
    ;;
  *)
    false
    ;;
  esac

  rm -rf .pc

  popd > /dev/null
}

export -f apply_patches
