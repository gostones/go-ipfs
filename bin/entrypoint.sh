#!/bin/sh
set -e

repo="$IPFS_PATH"

#
ipfs version

if [ -e "$repo/config" ]; then
  echo "Found IPFS fs-repo at $repo"
else
  case "$IPFS_PROFILE" in
    "") INIT_ARGS="" ;;
    *) INIT_ARGS="--profile=$IPFS_PROFILE" ;;
  esac
  ipfs init $INIT_ARGS
  ipfs config Addresses.API /ip4/0.0.0.0/tcp/5001
  ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
  ipfs config --bool Swarm.EnableAutoRelay true

  # Set up the swarm key, if provided

  SWARM_KEY_FILE="$repo/swarm.key"
  SWARM_KEY_PERM=0400

  # Create a swarm key from a given environment variable
  if [ ! -z "$IPFS_SWARM_KEY" ] ; then
    echo "Copying swarm key from variable..."
    echo -e "$IPFS_SWARM_KEY" >"$SWARM_KEY_FILE" || exit 1
    chmod $SWARM_KEY_PERM "$SWARM_KEY_FILE"
  fi

  # Unset the swarm key variable
  unset IPFS_SWARM_KEY

  # Check during initialization if a swarm key was provided and
  # copy it to the ipfs directory with the right permissions
  # WARNING: This will replace the swarm key if it exists
  if [ ! -z "$IPFS_SWARM_KEY_FILE" ] ; then
    echo "Copying swarm key from file..."
    install -m $SWARM_KEY_PERM "$IPFS_SWARM_KEY_FILE" "$SWARM_KEY_FILE" || exit 1
  fi

  # Unset the swarm key file variable
  unset IPFS_SWARM_KEY_FILE

fi

exec ipfs "$@"

