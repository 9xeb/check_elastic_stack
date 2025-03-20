#!/bin/bash

usage()
{
  echo "Usage: check_elastic_stack [options...]
  -c, --check <elasticsearch|kibana|logstash>
  -h, --host <host_or_endpoint>
  -u, --user <user>
  -p, --password <password>
  [-t, --timeout <seconds>]
  
Perform healthchecks on elasticsearch, kibana or logstash endpoints."
  exit 3
}

elasticsearch_checks() {
    if echo "$curl_output" | jq -e '. | select(.status == "green")' >/dev/null; then
        check_code=0
        check_message="All shards are active!"
    elif echo "$curl_output" | jq -e '. | select(.status == "yellow")' >/dev/null; then
        check_code=1
        check_message="Some shards are inactive!"
    elif echo "$curl_output" | jq -e '. | select(.status == "red")' >/dev/null; then
        check_code=2
        check_message="Some shards are absent!"
    fi
}

kibana_checks() {
    check_code=0
    check_message="[ ($check_path) All good in kibana ]"
}

logstash_checks() {
    check_code=0
    check_message="[ ($check_path) All good in kibana ]"
}

# see https://www.shellscript.sh/examples/getopt/
PARSED_ARGUMENTS=$(getopt -n check_elastic_stack -o c:h:u:p:t: --long check:,host:,user:,password:,timeout: -- "$@")
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

# Default value for timeout seconds
TIMEOUT_SECONDS=5

# Translate 'getopt'-ed arguments into env vars to be used during actual check operations
# Care is taken here to ensure sane defaults to fall back to are set for values like PORTs and URLs
while :
do
  case "$1" in
    -c | --check)
        # first three cases determine the default PORT, then they all fallthrough to set the CHECK mode
        case "$2" in
            elasticsearch) CHECK=elasticsearch; SCHEMA=https:// PORT=9200; CHECK_PATHS="_cluster/health?pretty";                       shift 2 ;;
            kibana)        CHECK=kibana;        SCHEMA=http://  PORT=5601; CHECK_PATHS="status api/status api/task_manager/_health";   shift 2 ;;
            logstash)      CHECK=logstash;      SCHEMA=http://  PORT=9600; CHECK_PATHS="changeme";                                     shift 2 ;;
            # elasticsearch|kibana|logstash) CHECK=$2; shift 2 ;; # CHECK mode is recalled later when performing check operations
            *) echo "Invalid check type: $2"
               usage ;;
        esac
        ;;
    -h | --host)     HOST=$2            ; shift 2 ;;
    -u | --user)     USER=$2            ; shift 2 ;;
    -p | --password) PASSWORD=$2        ; shift 2 ;;
    -t | --timeout)  TIMEOUT_SECONDS=$2 ; shift 2 ;;
    # -- means the end of the arguments; drop this, and break out of the while loop
    --) shift; break ;;
    # If invalid options were passed, then getopt should have reported an error,
    # which we checked as VALID_ARGUMENTS when getopt was called...
    *) echo "Unexpected option: $1 - this should not happen."
       usage ;;
  esac
done

# Ensure mandatory arguments were passed
if ! [[ -v CHECK && -v HOST && -v USER && -v PASSWORD ]]; then
    echo "Missing options."
    usage
fi

# ENDPOINT is built here
ENDPOINT=$HOST
# First check if host does not have URL scheme and possibly prepend the default (https)
[[ "$ENDPOINT" =~ ^(http|https):\/\/.* ]] || ENDPOINT=$SCHEMA$ENDPOINT
# Then check if host does not have explicit port and possibly append the default port (depends on check)
# TODO: this is broken, fix it
[[ "$ENDPOINT" =~ .*:\d{1,5}$ ]] || ENDPOINT=$ENDPOINT:$PORT

# echo "Checking $CHECK on endpoint $ENDPOINT with creds $USER:$PASSWORD" 1>&2

nagios_message=""
nagios_exit_code=0
for check_path in $CHECK_PATHS; do

    echo "Checking $CHECK on endpoint $ENDPOINT/$check_path with creds $USER:$PASSWORD" 1>&2
    # Reach out to API as specified by user request
    curl_output=$(curl --max-time "$TIMEOUT_SECONDS" --silent --fail --show-error -k -u "$USER":"$PASSWORD" "$ENDPOINT"/"$check_path" 2>&1)
    curl_exit_code="$?"
    # TODO: curl timeout, skip TLS and other useful options


    # Perform context-based checks on API response
    case "$curl_exit_code" in
        0) 
            case $CHECK in
                elasticsearch)
                    # see https://www.elastic.co/guide/en/elasticsearch/reference/current/cluster-health.html

                    # Perform arbitrary checks on API responses
                    elasticsearch_checks
                    ;;
                kibana)
                    # https://www.elastic.co/blog/troubleshooting-kibana-health
                    # echo "$curl_output"
                    kibana_checks
                    ;;
                logstash) 
                    # echo "$curl_output"
                    logstash_checks
                    ;;
            esac
            ;;
        22)
            # as per https://everything.curl.dev/cmdline/exitcode.html, 22 is thrown when HTTP response is 400 or above
            nagios_message=$(printf "(%s) %s" "$ENDPOINT"/"$check_path" "$curl_output";)
            nagios_exit_code=2
            ;;
        *) 
            # printf "%s UNKNOWN - (%s) %s" "$CHECK" "$ENDPOINT"/"$check_path" "$curl_output";
            nagios_message=$(printf "(%s) %s" "$ENDPOINT"/"$check_path" "$curl_output";)
            nagios_exit_code=3
            ;;
    esac

    # Nagios output is updated according to the result of API checks above
    if (( check_code >= nagios_exit_code )); then
        # Get here if check escalated to a higher nagios exit code
        nagios_exit_code=$check_code
        printf -v nagios_message "%s %s" "$nagios_message" "$check_message"
        # nagios_message=$(printf "%s%s\n" "$nagios_message" "$check_message")
    fi

done

# Format output according to Nagios specifications
NAGIOS_CODES=(OK WARNING CRITICAL UNKNOWN)
service_name=$(echo "$CHECK" | tr '[:lower:]' '[:upper:]')
printf "%s %s - %s\n" "$service_name" "${NAGIOS_CODES[$nagios_exit_code]}" "$nagios_message"
exit "$nagios_exit_code"