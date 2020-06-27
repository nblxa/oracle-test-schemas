#!/usr/bin/env bash
#
# Copyright (c) 2020 Pavel Mitrofanov
# MIT License
# More details at https://github.com/nblxa/oracle-test-schemas
#

set -e

usage() {
  cat <<EOF
Usage: $0 [OPTION]... HOST
HOST is the fully-qualified hostname of the Oracle Database,
     e.g. my-host-name.adb.eu-frankfurt-1.oraclecloudapps.com
Options are:
  -p    ADMIN user password
  -n    Namespace. The default is "TEST". Oracle schema names will start with the namespace
        in uppercase, e.g.: TEST_ADMIN, TEST_REST, and temporary schemas TEST_1, TEST_2, etc.
        The REST endpoints will contain the namespace in lowercase,
        e.g. https://example.com/ords/test/
  -a    define the password the TEST_ADMIN user will have
  -r    define the password the TEST_REST user will have
  -?    Display this help message.
EOF
  return 1
}

while getopts :H:p:n:a:r: o; do
  case "$o" in
    p)
      ADMIN_PWD="$OPTARG"
      ;;
    n)
      NAMESPACE="$OPTARG"
      ;;
    a)
      TEST_ADMIN_PWD="$OPTARG"
      ;;
    r)
      TEST_REST_PWD="$OPTARG"
      ;;
    ?)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

shift $(( OPTIND-1 ))
ORA_HOST=$1
if [ -z "$ORA_HOST" ]; then
  usage
fi

if [ -z "$ADMIN_PWD" ]; then
  echo "Enter the password of the ADMIN user: "
  read -rs ADMIN_PWD
fi

if [ -z "$TEST_ADMIN_PWD" ]; then
  echo "Enter the password of the ${NAMESPACE}_ADMIN user: "
  read -rs TEST_ADMIN_PWD
fi

if [ -z "$TEST_REST_PWD" ]; then
  echo "Enter the password of the ${NAMESPACE}_REST user: "
  read -rs TEST_REST_PWD
fi

echo "Creating schemas ${NAMESPACE}_ADMIN and ${NAMESPACE}_REST..."

sed -E "s/&TEST_ADMIN_PASSWORD\b\\.?/$TEST_ADMIN_PWD/i" ./deploy_test_admin.sql |
  sed -E "s/&TEST_REST_PASSWORD\b\\.?/$TEST_REST_PWD/i" |
  sed -E "s/&NAMESPACE\b\\.?/$NAMESPACE/i" |
  curl -s -X POST \
    -H "Content-Type: application/sql" \
    -u "ADMIN:$ADMIN_PWD" \
    --data-binary @- \
    "https://$ORA_HOST/ords/admin/_/sql"

echo
echo "Creating the REST API..."

REST_NS=$(echo "$NAMESPACE" | tr '[:upper:]' '[:lower:]')
JSON=$(
  sed -E "s/&NAMESPACE\b\\.?/$NAMESPACE/i" ./deploy_test_rest.sql |
  curl -s -X POST \
    -H "Content-Type: application/sql" \
    -u "${NAMESPACE}_REST:$TEST_REST_PWD" \
    --data-binary @- \
    "https://$ORA_HOST/ords/$REST_NS/_/sql" )
echo -n "$JSON"

CRED=$(echo -n "$JSON" | grep -oE '"client_id":"[^"]+","client_secret":"[^"]+"' | tail -1)
[ -n "$CRED" ]

CLIENT_ID=$(echo "$CRED" | cut -d , -f 1 | cut -d : -f 2 | tr -d '"')
CLIENT_SECRET=$(echo "$CRED" | cut -d , -f 2 | cut -d : -f 2 | tr -d '"')

echo ; echo

cat <<EOF
Please use the following credentials to get an OAuth token for using the REST services:
    client_id: $CLIENT_ID
    client_secret: $CLIENT_SECRET

Example:

curl -X POST "https://$ORA_HOST/ords/$REST_NS/oauth/token" \\
     -u "$CLIENT_ID:$CLIENT_SECRET" \\
     -H 'Content-Type: application/x-www-form-urlencoded' \\
     --data-urlencode 'grant_type=client_credentials'
EOF
