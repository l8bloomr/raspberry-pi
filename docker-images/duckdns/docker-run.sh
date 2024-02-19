#!/bin/bash

SELF_NAME=$(basename "$0")
SELF_DIR=$(dirname $(readlink -f "$0"))
DATA_DIR="$HOME/data/$(basename $SELF_DIR)"
CRON_SCHEDULE_REGEX="(^[0-9]{1,2}(,[0-9]{1,2})*$)|(^\*\/([0-9]{1,2}))$"
CONTAINER_NAME="duckdns"
SCHEDULE="*/10"
OPTIONS="
    -d <directory>   Duck DNS data directory (default: $DATA_DIR)
    -s <sub-domain>  Sub-domain to update (i.e. subdomain.duckdns.org)
    -t <token>       Duck DNS user token
    -u <schedule>    Update schedule (minutes) in crontab format (default: $SCHEDULE)
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
    -s)
      shift
      USER_DOMAIN=$1
      ;;
    -t)
      shift
      USER_TOKEN=$1
      ;;
    -u)
      shift
      if ! [[ "$1" =~ $CRON_SCHEDULE_REGEX ]]; then
        fatal_error "Update schedule (minutes) must be in crontab format (eg. $SCHEDULE)"
      fi
      SCHEDULE=$1
      ;;
    *)
      fatal_invalid_option "$1"
      ;;
    esac
    shift
  done
}

parse_options "$@"

assert_not_empty "$USER_TOKEN" "Duck DNS user token must be specified"
assert_not_empty "$USER_DOMAIN" "Duck DNS domain must be specified"
assert_directory_exists "$DATA_DIR" "Couldn't create data directory"

echo "Container name : $CONTAINER_NAME"
echo "Data directory : $DATA_DIR"
echo "Duck DNS domain: $USER_DOMAIN"
echo "Duck DNS token : $USER_TOKEN"
echo "Update schedule: $SCHEDULE * * * *"
assert_prompt_continue "Launch container \"$CONTAINER_NAME\"?"
echo ""

docker build -t "$CONTAINER_NAME" "$SELF_DIR"

docker run -d \
  --name "$CONTAINER_NAME" \
  -e TZ="$TIME_ZONE" \
  -e SUBDOMAINS="$USER_DOMAIN" \
  -e TOKEN="$USER_TOKEN" \
  -e LOG_FILE=true \
  -e SCHEDULE="$SCHEDULE" \
  -v "$DATA_DIR":/data \
  --restart unless-stopped \
  "$CONTAINER_NAME"
