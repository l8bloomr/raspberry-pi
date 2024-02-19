#!/bin/bash

# Reference: https://hub.docker.com/r/weejewel/wg-easy

SELF_NAME=$(basename "$0")
SELF_DIR=$(dirname $(readlink -f "$0"))
DATA_DIR="$HOME/data/$(basename $SELF_DIR)"
TIME_ZONE=$(cat /etc/timezone)
WG_PORT=51820
ADMIN_PORT=51821
WG_DEFAULT_DNS="1.1.1.1, 1.0.0.1"
WG_DEFAULT_ADDRESS="10.20.1.x"
CONTAINER_NAME="wireguard"

OPTIONS="
    -d <directory>       WireGuard data directory (default: $DATA_DIR)
    --dns <dns>          Client DNS servers (default: $WG_DEFAULT_DNS)
    -e <endpoint>        External DDNS endpoint (required)
    -r <default ip>      Client IP address range (default: $WG_DEFAULT_ADDRESS)
    -p <port>            Public UDP port for WireGuard server (default: $WG_PORT)
    --admin-port <port>  Public TCP port for admin UI (default: $ADMIN_PORT)
"

# Shows usage screen
function show_usage()
{
  # Arguments:
  #   1 - list of command line options
  #   2 - additional descriptions
  printf '\n  Usage: %s [options]\n\n  Options:\n%s' "$SELF_NAME" "$1"
  if [ "$2" != "" ]; then
    printf '%s\n' "$2"
  else
    echo ""
  fi
}

# Displays an error message and exits the process
function fatal_error()
{
  # Arguments:
  #   1 - error message

  echo "Error: $1"
  exit 1
}

# Displays an error message and exits
function fatal_invalid_option()
{
  # Arguments:
  #   1 - parameter/option

  fatal_error "Unrecognized option \"$1\". Use \"$SELF_NAME -h\" for valid options."
}

# Displays an error and exits if the specified directory doesn't exist and cannot be created
function assert_directory_exists()
{
  # Arguments:
  #   1 - directory to create/verify
  #   2 - error message

  [[ -d "$1" ]] || mkdir -p "$1" || { fatal_error "$2: $1"; }
}

# Displays an error if the given parameter is empty
function assert_not_empty()
{
  # Arguments:
  #   1 - value to assert isn't empty
  #   2 - error message

  if [ -z "$1" ]; then
    fatal_error "$2"
  fi
}

# Prompt for password to be entered and verified, displays an error if they don't match
function prompt_for_password()
{
  # Arguments:
  #   1 - password prompt (optional)
  #   2 - password re-entry prompt (optional)
  # Returns: RETURN_PASSWORD variable containing the password

  local VERIFIED_PASSWORD

  # Prompt for password
  if [ -z "$1" ]; then
    printf "Enter password: "
  else
    printf "$1: "
  fi
  read -s RETURN_PASSWORD
  echo ""

  # Prompt for password re-entry/verification
  if [ -z "$2" ]; then
    printf "Re-enter password: "
  else
    printf "$2: "
  fi
  read -s VERIFIED_PASSWORD
  echo ""

  # Verify passwords match
  if [ "$RETURN_PASSWORD" != "$VERIFIED_PASSWORD" ]; then
    fatal_error "Passwords do not match"
  fi
}

# Displays a prompt and exits if user doesn't answer yes/y
function assert_prompt_continue()
{
  # Arguments:
  #   1 - message

  local MESSAGE
  local RESPONSE
  if [ -z "$1" ]; then
    MESSAGE="Do you want to continue?"
  else
    MESSAGE="$1"
  fi
  printf "%s (yes/no): " "$MESSAGE"
  read RESPONSE
  RESPONSE=${RESPONSE,,}

  # Affirmative returns
  if [ "$RESPONSE" == "y" ] || [ "$RESPONSE" == "yes" ]; then
    return 0
  fi

  # Anything else aborts
  exit 1
}

function parse_options() {
  while [ $1 ]; do
    case $1 in
    -h)
      show_usage "$OPTIONS"
      exit 1
      ;;
    -d)
      shift
      DATA_DIR=${1%/}
      ;;
    --dns)
      shift
      WG_DEFAULT_DNS=$1
      ;;
    -e)
      shift
      EXTERNAL_IP=$1
      ;;
    -r)
      shift
      WG_DEFAULT_ADDRESS=$1
      ;;
    -p)
      shift
      WG_PORT=$1
      ;;
    --admin-port)
      shift
      ADMIN_PORT=$1
      ;;
    *)
      fatal_invalid_option "$1"
      ;;
    esac
    shift
  done
}

parse_options "$@"

assert_directory_exists "$DATA_DIR" "Couldn't create data directory"
assert_not_empty "$EXTERNAL_IP" "An external endpoint is required"

echo "Container name      : $CONTAINER_NAME"
echo "Data directory      : $DATA_DIR"
echo "External endpoint   : $EXTERNAL_IP"
echo "Client DNS server(s): $WG_DEFAULT_DNS"
echo "Client IP range     : $WG_DEFAULT_ADDRESS"
echo "VPN port (UDP)      : $WG_PORT"
echo "Admin UI port (TCP) : $ADMIN_PORT"
prompt_for_password "Enter admin password" "Re-enter password   "
ADMIN_PASSWORD="$RETURN_PASSWORD"
assert_prompt_continue "Launch container \"$CONTAINER_NAME\"?"
echo ""

docker run -d \
  --name="$CONTAINER_NAME" \
  -e WG_HOST="$EXTERNAL_IP" \
  -e PASSWORD="$ADMIN_PASSWORD" \
  -e WG_PORT="$WG_PORT" \
  -e WG_DEFAULT_DNS="$WG_DEFAULT_DNS" \
  -e WG_DEFAULT_ADDRESS="$WG_DEFAULT_ADDRESS" \
  -e TZ="$TIME_ZONE" \
  -v "$DATA_DIR":/etc/wireguard \
  -p "$WG_PORT":51820/udp \
  -p "$ADMIN_PORT":51821/tcp \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --sysctl="net.ipv4.ip_forward=1" \
  --restart unless-stopped \
  weejewel/wg-easy
