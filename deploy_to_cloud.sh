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
  -a    TEST_ADMIN user password (will be set to the given value)
  -r    TEST_REST user password (will be set to the given value)
  -?    Display this help message.
EOF
  return 1
}

while getopts :H:p:a:r: o; do
  case "$o" in
    p)
      ADMIN_PWD="$OPTARG"
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
  echo "Enter the password of the TEST_ADMIN user: "
  read -rs TEST_ADMIN_PWD
fi

if [ -z "$TEST_REST_PWD" ]; then
  echo "Enter the password of the TEST_REST user: "
  read -rs TEST_REST_PWD
fi

echo "Creating schemas TEST_ADMIN and TEST_REST..."

cat ./deploy_test_admin.sql |
  sed "s/&TEST_ADMIN_PASSWORD/$TEST_ADMIN_PWD/" |
  sed "s/&TEST_REST_PASSWORD/$TEST_REST_PWD/" |
  curl -s -X POST \
    -H "Content-Type: application/sql" \
    -u "ADMIN:$ADMIN_PWD" \
    --data-binary @- \
    "https://$ORA_HOST/ords/admin/_/sql"

echo
echo "Creating the REST API..."

cat ./deploy_test_rest.sql |
  curl -s -X POST \
    -H "Content-Type: application/sql" \
    -u "TEST_REST:$TEST_REST_PWD" \
    --data-binary @- \
    "https://$ORA_HOST/ords/test/_/sql"
