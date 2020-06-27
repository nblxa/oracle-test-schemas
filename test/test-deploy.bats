#!/usr/bin/env bats

NAMESPACE=CI
REST_NS=$(echo "$NAMESPACE" | tr '[:upper:]' '[:lower:]')

@test "01. Deploy to the cloud (NAMESPACE=$NAMESPACE)" {
  OUTPUT=$("$GITHUB_WORKSPACE/deploy_to_cloud.sh" \
            -p "$OC_ADMIN_PWD" \
            -n "$NAMESPACE" \
            -a "$OC_TEST_ADMIN_PWD" \
            -r "$OC_TEST_REST_PWD" "$OC_HOST_NAME")
  CUTLINE1=$(echo -n "$OUTPUT" | grep -n "Creating schemas ${NAMESPACE}_ADMIN and ${NAMESPACE}_REST..." | cut -d : -f 1)
  CUTLINE2=$(echo -n "$OUTPUT" | grep -n 'Creating the REST API...' | cut -d : -f 1)
  CUTLINE3=$(echo -n "$OUTPUT" | grep -n 'Please use the following credentials' | cut -d : -f 1)
  # find the result of the 1st deployment step
  JSON1=$(echo -n "$OUTPUT" | sed -n "$((CUTLINE1+1)),$((CUTLINE2-1))p")
  # all SQL and PL/SQL statement results are 0 (success):
  RESULT=$(echo -n "$JSON1" | jq .items[].result - | uniq)
  [ "$RESULT" == '0' ]
  # find the result of the 2nd deployment step
  JSON2=$(echo -n "$OUTPUT" | sed -n "$((CUTLINE2+1)),$((CUTLINE3-1))p")
  # all SQL and PL/SQL statement results are 0 (success):
  RESULT=$(echo -n "$JSON2" | jq .items[].result - | uniq)
  [ "$RESULT" == '0' ]

  # authenticate
  CRED='.items[] | select(.statementText=="select id, name, client_id, client_secret from user_ords_clients") | .resultSet.items[0]'
  CLIENT_ID=$(echo -n "$JSON2" | jq -j "$CRED.client_id" -)
  CLIENT_SECRET=$(echo -n "$JSON2" | jq -j "$CRED.client_secret" -)
  OUTPUT=$(curl -s -w '\n%{http_code}' -X POST \
           -u "$CLIENT_ID:$CLIENT_SECRET" \
           --data-urlencode "grant_type=client_credentials" \
           -H "Content-Type: application/x-www-form-urlencoded" \
           "https://$OC_HOST_NAME/ords/$REST_NS/oauth/token")
  HTTPCODE=$(echo -n "$OUTPUT" | tail -1)
  [ "$HTTPCODE" == '200' ]
  JSON=$(echo -n "$OUTPUT" | sed \$d)
  echo -n "$JSON" | jq -j '.access_token' > "$BATS_TMPDIR/access_token.txt"
}

@test "02. when not authenticated, /test/log/ returns HTTP 401" {
  OUTPUT=$(curl -s -w '\n%{http_code}' -X GET "https://$OC_HOST_NAME/ords/$REST_NS/log/")
  HTTPCODE=$(echo -n "$OUTPUT" | tail -1)
  echo "HTTP code: $HTTPCODE"
  [ "$HTTPCODE" == '401' ]
}

@test "03. when not authenticated, /test/schema/ returns HTTP 401" {
  OUTPUT=$(curl -s -w '\n%{http_code}' -X GET "https://$OC_HOST_NAME/ords/$REST_NS/schema/")
  HTTPCODE=$(echo -n "$OUTPUT" | tail -1)
  echo "HTTP code: $HTTPCODE"
  [ "$HTTPCODE" == '401' ]
}

@test "04. /test/version/ returns the current version" {
  ACCESS_TOKEN=$(cat "$BATS_TMPDIR/access_token.txt")
  OUTPUT=$(curl -s -w '\n%{http_code}' -X GET \
           -H "Authorization: Bearer $ACCESS_TOKEN" \
           "https://$OC_HOST_NAME/ords/$REST_NS/version/")
  HTTPCODE=$(echo -n "$OUTPUT" | tail -1)
  echo "HTTP code: $HTTPCODE"
  [ "$HTTPCODE" == '200' ]
  JSON=$(echo -n "$OUTPUT" | sed \$d)
  # check that there are 0 elements in the "items" array
  VERSION=$(echo -n "$JSON" | jq -j '.version' -)
  echo "Version: $VERSION"
  [ "$VERSION" == '0.1.0' ]
}

@test "05. /test/log/ is empty at first" {
  ACCESS_TOKEN=$(cat "$BATS_TMPDIR/access_token.txt")
  OUTPUT=$(curl -s -w '\n%{http_code}' -X GET \
           -H "Authorization: Bearer $ACCESS_TOKEN" \
           "https://$OC_HOST_NAME/ords/$REST_NS/log/")
  HTTPCODE=$(echo -n "$OUTPUT" | tail -1)
  echo "HTTP code: $HTTPCODE"
  [ "$HTTPCODE" == '200' ]
  JSON=$(echo -n "$OUTPUT" | sed \$d)
  # check that there are 0 elements in the "items" array
  COUNT=$(echo -n "$JSON" | jq '.items | length' -)
  [ "$COUNT" == '0' ]
}
