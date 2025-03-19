#!/bin/bash

# EXAMPLE USAGE MESSAGE
# Usage: curl [options...] <url>
#  -d, --data <data>          HTTP POST data
#  -f, --fail                 Fail silently (no output at all) on HTTP errors
#  -h, --help <category>      Get help for commands
#  -i, --include              Include protocol response headers in the output
#  -o, --output <file>        Write to file instead of stdout
#  -O, --remote-name          Write output to a file named as the remote file
#  -s, --silent               Silent mode
#  -T, --upload-file <file>   Transfer local FILE to destination
#  -u, --user <user:password> Server user and password
#  -A, --user-agent <name>    Send User-Agent <name> to server
#  -v, --verbose              Make the operation more talkative
#  -V, --version              Show version number and quit

# This is not the full help, this menu is stripped into categories.
# Use "--help category" to get an overview of all categories.
# For all options use the manual or "--help all".


usage()
{
  echo "Usage: check_elastic_stack [ -c | --check <elasticsearch|kibana|logstash> ]
                        [ -h | --host <host_or_endpoint> ]
                        [ -u | --user <user> ] 
                        [ -p | --password <password> ]"
  exit 2
}

# see https://www.shellscript.sh/examples/getopt/
PARSED_ARGUMENTS=$(getopt -n check_elastic_stack -o c:h:u:p: --long check:,host:,user:,password: -- "$@")
VALID_ARGUMENTS=$?
if [ "$VALID_ARGUMENTS" != "0" ]; then
    usage
fi
# echo "PARSED_ARGUMENTS is $PARSED_ARGUMENTS" 1>&2
eval set -- "$PARSED_ARGUMENTS"


# TODO: maybe simpler without getopt
# while [ $# -gt 0 ]; do
#     case $1 in
#         -s|--service) SERVICE_NAME="$2" ; shift;;
#         -r|--registry) REGISTRY="$2" ; shift;;
#         -h|--help) HELP=true ;;
#         *) echo "help" && exit 1;;
#     esac
#     shift
# done


# Translate 'getopt'-ed arguments into env vars to be used during actual check operations
# Care is taken here to ensure sane defaults to fall back to are set for values like PORTs and URLs
while :
do
  case "$1" in
    -c | --check)
        # first three cases determine the default PORT, then they all fallthrough to set the CHECK mode
        case "$2" in
            elasticsearch) CHECK=elasticsearch; PORT=9200; CHECK_PATH="_cluster/health"; shift 2 ;;
            kibana)        CHECK=kibana;        PORT=5601; CHECK_PATH="changeme";        shift 2 ;;
            logstash)      CHECK=logstash;      PORT=9600; CHECK_PATH="changeme";        shift 2 ;;
            # elasticsearch|kibana|logstash) CHECK=$2; shift 2 ;; # CHECK mode is recalled later when performing check operations
            *) echo "Invalid check type: $2"
               usage ;;
        esac
        ;;
    -h | --host)     HOST=$2     ; shift 2 ;;
    -u | --user)     USER=$2     ; shift 2 ;;
    -p | --password) PASSWORD=$2 ; shift 2 ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

# ENDPOINT is built here
ENDPOINT=$HOST
# First check if host does not have URL scheme and possibly prepend the default (https)
[[ "$ENDPOINT" =~ ^(http|https):\/\/.* ]] || ENDPOINT=https://$ENDPOINT
# Then check if host does not have explicit port and possibly append the default according to requested check
[[ "$ENDPOINT" =~ :\d{1,5}$ ]] || ENDPOINT=$ENDPOINT:$PORT
ENDPOINT=$ENDPOINT/$CHECK_PATH

echo "Checking $CHECK on endpoint $ENDPOINT with creds $USER:$PASSWORD" 1>&2

# curl_response=$(curl --silent --show-error -k -u "$USER":"$PASSWORD" "$ENDPOINT")
# curl_exit_code="$?"
# case "$curl_exit_code" in
#     0) echo "OK - $CHECK is green!"; exit 0 ;;
#     *) echo "UNKNOWN - $curl_response"; exit $curl_exit_code ;;
# esac