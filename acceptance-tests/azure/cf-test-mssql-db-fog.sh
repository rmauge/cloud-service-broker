#!/usr/bin/env bash

set -o nounset

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

. "${SCRIPT_DIR}/functions.sh"

PRIMARY_SERVER_NAME=mssql-server-p-$$
SECONDARY_SERVER_NAME=mssql-server-s-$$
USERNAME=anadminuser
PASSWORD=This_S0uld-3eC0mplex~
SERVER_RG=csb-acceptance-test-rg

"${SCRIPT_DIR}/cf-create-mssql-server.sh" "${PRIMARY_SERVER_NAME}" "${USERNAME}" "${PASSWORD}" "${SERVER_RG}" westus &
PRIMARY_PID=$!

"${SCRIPT_DIR}/cf-create-mssql-server.sh" "${SECONDARY_SERVER_NAME}" "${USERNAME}" "${PASSWORD}" "${SERVER_RG}" eastus &
SECONDARY_PID=$!

RESULT=1
if wait ${PRIMARY_PID} && wait ${SECONDARY_PID}; then
    FOG_NAME=mssql-server-fog-$$
    CONFIG="{
      \"instance_name\":\"${FOG_NAME}\", \
      \"server_pair\":\"test\", \
      \"server_credential_pairs\":{ \
        \"test\":{ \
          \"admin_username\":\"${USERNAME}\", \
          \"admin_password\":\"${PASSWORD}\", \
          \"primary\":{ \
            \"server_name\":\"${PRIMARY_SERVER_NAME}\", \
            \"resource_group\":\"${SERVER_RG}\" \
          }, \
          \"secondary\":{ \
            \"server_name\":\"${SECONDARY_SERVER_NAME}\", \
            \"resource_group\":\"${SERVER_RG}\" \
          } \
        } \
      } \
    }"

    echo $CONFIG

    ../cf-test-spring-music.sh csb-azure-mssql-db-failover-group medium "${CONFIG}"
    RESULT=$?
fi

"${SCRIPT_DIR}/cf-delete-mssql-server.sh" "${PRIMARY_SERVER_NAME}"   &
"${SCRIPT_DIR}/cf-delete-mssql-server.sh" "${SECONDARY_SERVER_NAME}" &

wait

exit ${RESULT}