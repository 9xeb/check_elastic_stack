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
    # https://www.elastic.co/guide/en/elasticsearch/reference/current/cluster-health.html
    elasticsearch_status=$(echo "$curl_output" | jq -e '.status' | xargs)
    case $elasticsearch_status in
        green)  check_code=0; check_message="All shards are active!"    ;;
        yellow) check_code=1; check_message="Some shards are inactive!" ;;
        red)    check_code=2; check_message="Some shards are absent!"   ;;
        *)      check_code=3; check_message="Unknown shards status!"    ;;
    esac
    # printf -v check_message "%s\n%s" "$check_message" "$curl_output"
}

basic_kibana_checks() {
    # https://www.elastic.co/blog/troubleshooting-kibana-health

    # Kibana checks support multiple API endpoints
    if [[ "$check_path" == "/api/status" ]]; then
        kibana_overall=$(echo "$curl_output" | jq -rc '.status.overall.level' | xargs)
        case $kibana_overall in
            available) check_code=0; check_message="$check_path is available" ;;
            critical)  check_code=2; check_message="$check_path is critical"  ;;
            # If status is reported as degraded, more specific checks are performed to determine if it is due to backend issues (Elasticsearch) or degraded plugins
            *)  
                # Extract backend status from JSON answer coming from API
                backend_status=$(echo "$curl_output" | jq -rc '.status.core|{ elasticsearch: .elasticsearch.level, savedObjects: .savedObjects.level }')
                # Extract all degraded plugins as declared by API response
                kibana_degraded_plugins=$(echo "$curl_output" | jq -rc '.status.plugins|to_entries[]|{ plugin: .key, status: .value.level }|select(.status != "available")')

                check_code=1
                check_message="$check_path is degraded"
                printf -v check_message "%s\n%s\n%s\n" "$check_message" "$backend_status" "$kibana_degraded_plugins"
                ;;
        esac
    elif [[ "$check_path" == "/api/task_manager/_health" ]]; then
        kibana_task_manager=$(echo "$curl_output" | jq -e '.status' | xargs)
        case $kibana_task_manager in
            OK) check_code=0; check_message="$check_path is OK"      ;;
            *)  check_code=1; check_message="$check_path is not OK"  ;;
        esac
    fi
}

logstash_checks() {
    # https://www.elastic.co/docs/api/doc/logstash/operation/operation-healthreport
    # https://discuss.elastic.co/t/logstash-healthcheck/271088/2
    logstash_status=$(echo "$curl_output" | jq -rc '.status' | xargs)
    case $logstash_status in
        green)  check_code=0; check_message="$check_path is green!"   ;;
        yellow) check_code=1; check_message="$check_path is yellow!"  ;;
        red)    check_code=2; check_message="$check_path is red!"     ;;
        *)      check_code=3; check_message="$check_path is unknown!" ;;
    esac

    # Append symptom to Nagios message
    logstash_symptom=$(echo "$curl_output" | jq -rc '.symptom|{ symptom: .}')
    printf -v check_message "%s\n%s\n" "$check_message" "$logstash_symptom"
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


# FIRST SECTION: parse user arguments
# Translate 'getopt'-ed arguments into env vars to be used during actual check operations
# Care is taken here to ensure sane defaults to fall back to are set for values like PORTs and URLs
while :
do
  case "$1" in
    -c | --check)
        # first three cases determine the default PORT, then they all fallthrough to set the CHECK mode
        case "$2" in
            # This section is available for defining new contexts
            # A context is fundamentally a bunch of env vars that can be recalled later in the script
            elasticsearch) CHECK=elasticsearch; SCHEMA=https:// PORT=9200; CHECK_PATHS="/_cluster/health";                      shift 2 ;;
            kibana)        CHECK=kibana;        SCHEMA=http://  PORT=5601; CHECK_PATHS="/api/status /api/task_manager/_health"; shift 2 ;;
            logstash)      CHECK=logstash;      SCHEMA=http://  PORT=9600; CHECK_PATHS="/_health_report";                       shift 2 ;;
            # your_custom_context) your_custom_vars ;;
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
[[ "$ENDPOINT" =~ .*:[0-9]{1,5}$ ]] || ENDPOINT=$ENDPOINT:$PORT

# echo "Checking $CHECK on endpoint $ENDPOINT with creds $USER:$PASSWORD" 1>&2


# SECOND SECTION: perform context-based checks
nagios_message=""
nagios_exit_code=0

# This is the main check loop. It does the following, for all CHECK_PATHS defined in the context:
# 1. Call the API and store the response
# 2. Check the response at the connection level (HTTP error codes going to curl)
# 3. If cURL is ok with the response, call the contextual check function and let that define the state of the check
# 4. Update the global state of the check
# The final result is a Nagios compatible response with the highest exit code produced by each check function, and a combination of all explanation messages
for check_path in $CHECK_PATHS; do
    echo "Checking $CHECK on endpoint $ENDPOINT$check_path with creds $USER:$PASSWORD" 1>&2

    # 1. Call the API as specified by context
    curl_output=$(curl --max-time "$TIMEOUT_SECONDS" --silent --fail --show-error -vk -u "$USER":"$PASSWORD" "$ENDPOINT""$check_path" 2>&1)
    curl_exit_code="$?"

    # 2. Case statement to look at cURL exit codes
    case "$curl_exit_code" in
        0) 
            # 3. Perform context-based checks on API response
            case $CHECK in
                # This second section is available for defining new contexts too.
                # Ensure you refer to the value of CHECK you defined in the first section for your context
                # You can call your own check function, which has access to all the variables you defined in the first section
                # Make sure your function sets the check_code and check_message variables according to Nagios output specs!
                elasticsearch)  elasticsearch_checks ;;
                kibana)         basic_kibana_checks  ;;
                logstash)       logstash_checks      ;;
                # your_custom_context) your_custom_check_function ;;
                *) check_code=3; check_message="Unknown context" ;;
            esac
            ;;
        22)
            # as per https://everything.curl.dev/cmdline/exitcode.html, 22 is thrown when HTTP response is 400 or above
            check_message=$(printf "%s %s" "$check_path" "$curl_output";)
            check_code=2
            ;;
        *) 
            # printf "%s UNKNOWN - (%s) %s" "$CHECK" "$ENDPOINT"/"$check_path" "$curl_output";
            check_message=$(printf "%s %s" "$check_path" "$curl_output";)
            check_code=3
            ;;
    esac

    # 4. Nagios output is updated according to the result of the check function
    printf -v nagios_message "%s%s\n" "$nagios_message" "$check_message"
    if (( check_code >= nagios_exit_code )); then
        # Get here if a check escalated to a higher nagios exit code
        nagios_exit_code=$check_code
        # printf -v nagios_message "%s%s\n" "$nagios_message" "$check_message"
    fi
done


# THIRD SECTION: format output according to Nagios specifications
# https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/3/en/pluginapi.html
NAGIOS_CODES=(OK WARNING CRITICAL UNKNOWN)
service_name=$(echo "$CHECK" | tr '[:lower:]' '[:upper:]')
printf "%s %s - %s" "$service_name" "${NAGIOS_CODES[$nagios_exit_code]}" "$nagios_message"
exit "$nagios_exit_code"