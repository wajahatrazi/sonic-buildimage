#!/usr/bin/env bash

EXIT_TELEMETRY_VARS_FILE_NOT_FOUND=1
INCORRECT_TELEMETRY_VALUE=2
TELEMETRY_VARS_FILE=/usr/share/sonic/templates/telemetry_vars.j2

if [ ! -f "$TELEMETRY_VARS_FILE" ]; then
    echo "Telemetry vars template file not found"
    exit $EXIT_TELEMETRY_VARS_FILE_NOT_FOUND
fi

# Try to read telemetry and certs config from ConfigDB.
# Use default value if no valid config exists
TELEMETRY_VARS=$(sonic-cfggen -d -t $TELEMETRY_VARS_FILE)
TELEMETRY_VARS=${TELEMETRY_VARS//[\']/\"}
X509=$(echo $TELEMETRY_VARS | jq -r '.x509')
GNMI=$(echo $TELEMETRY_VARS | jq -r '.gnmi')
CERTS=$(echo $TELEMETRY_VARS | jq -r '.certs')

export GRPC_GO_LOG_VERBOSITY_LEVEL=99
export GRPC_GO_LOG_SEVERITY_LEVEL=info

TELEMETRY_ARGS=" -logtostderr"
export CVL_SCHEMA_PATH=/usr/sbin/schema
export GOTRACEBACK=crash

if [ -n "$CERTS" ]; then
    SERVER_CRT=$(echo $CERTS | jq -r '.server_crt')
    SERVER_KEY=$(echo $CERTS | jq -r '.server_key')
    if [ -z $SERVER_CRT  ] || [ -z $SERVER_KEY  ]; then
        TELEMETRY_ARGS+=" --insecure"
    else
        TELEMETRY_ARGS+=" --server_crt $SERVER_CRT --server_key $SERVER_KEY "
    fi

    CA_CRT=$(echo $CERTS | jq -r '.ca_crt')
    if [ ! -z $CA_CRT ]; then
        TELEMETRY_ARGS+=" --ca_crt $CA_CRT"
    fi

    # Reuse GNMI_CLIENT_CERT for telemetry service
    TELEMETRY_ARGS+=" --config_table_name GNMI_CLIENT_CERT"
elif [ -n "$X509" ]; then
    SERVER_CRT=$(echo $X509 | jq -r '.server_crt')
    SERVER_KEY=$(echo $X509 | jq -r '.server_key')
    if [ -z $SERVER_CRT  ] || [ -z $SERVER_KEY  ]; then
        TELEMETRY_ARGS+=" --insecure"
    else
        TELEMETRY_ARGS+=" --server_crt $SERVER_CRT --server_key $SERVER_KEY "
    fi

    CA_CRT=$(echo $X509 | jq -r '.ca_crt')
    if [ ! -z $CA_CRT ]; then
        TELEMETRY_ARGS+=" --ca_crt $CA_CRT"
    fi
else
    TELEMETRY_ARGS+=" --noTLS"
fi

# If no configuration entry exists for TELEMETRY, create one default port
if [ -z "$GNMI" ]; then
    PORT=8080
else
    PORT=$(echo $GNMI | jq -r '.port')
fi
TELEMETRY_ARGS+=" --port $PORT"

CLIENT_AUTH=$(echo $GNMI | jq -r '.client_auth')
if [ -z $CLIENT_AUTH ] || [ $CLIENT_AUTH == "false" ]; then
    TELEMETRY_ARGS+=" --allow_no_client_auth"
fi

LOG_LEVEL=$(echo $GNMI | jq -r '.log_level')
if [[ $LOG_LEVEL =~ ^[0-9]+$ ]]; then
    TELEMETRY_ARGS+=" -v=$LOG_LEVEL"
else
    TELEMETRY_ARGS+=" -v=2"
fi

if [ -nz "$GNMI" ]; then
    ENABLE_CRL=$(echo $GNMI | jq -r '.enable_crl')
    if [ $ENABLE_CRL == "true" ]; then
        TELEMETRY_ARGS+=" --enable_crl"
    fi

    CRL_EXPIRE_DURATION=$(echo $GNMI | jq -r '.crl_expire_duration')
    if [ -n $CRL_EXPIRE_DURATION ]; then
        TELEMETRY_ARGS+=" --crl_expire_duration $CRL_EXPIRE_DURATION"
    fi
fi

# gNMI save-on-set behavior is disabled by default.
# Save-on-set can be turned on by setting the "TELEMETRY|gnmi|save_on_set"
# to "true".
readonly SAVE_ON_SET=$(echo $GNMI | jq -r '.save_on_set // empty')
if [ ! -z "$SAVE_ON_SET" ]; then
    TELEMETRY_ARGS+=" --with-save-on-set=$SAVE_ON_SET"
fi

# Server will handle threshold connections consecutively
THRESHOLD_CONNECTIONS=$(echo $GNMI | jq -r '.threshold')
if [[ $THRESHOLD_CONNECTIONS =~ ^[0-9]+$ ]]; then
    TELEMETRY_ARGS+=" --threshold $THRESHOLD_CONNECTIONS"
else
    if [ -z "$GNMI" ] || [[ $THRESHOLD_CONNECTIONS == "null" ]]; then
        TELEMETRY_ARGS+=" --threshold 100"
    else
        echo "Incorrect threshold value, expecting positive integers" >&2
        exit $INCORRECT_TELEMETRY_VALUE
    fi
fi

# Close idle connections after certain duration (in seconds)
IDLE_CONN_DURATION=$(echo $GNMI | jq -r '.idle_conn_duration')
if [[ $IDLE_CONN_DURATION =~ ^[0-9]+$ ]]; then
    TELEMETRY_ARGS+=" --idle_conn_duration $IDLE_CONN_DURATION"
else
    if [ -z "$GNMI" ] || [[ $IDLE_CONN_DURATION == "null" ]]; then
        TELEMETRY_ARGS+=" --idle_conn_duration 5"
    else
        echo "Incorrect idle_conn_duration value, expecting positive integers" >&2
        exit $INCORRECT_TELEMETRY_VALUE
    fi
fi
TELEMETRY_ARGS+=" -gnmi_native_write=false"

exec /usr/sbin/telemetry ${TELEMETRY_ARGS}
