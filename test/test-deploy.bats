#!/usr/bin/env bats

@test "01. Deploy to the cloud" {
  OUTPUT=$("$GITHUB_WORKSPACE/deploy_to_cloud.sh" \
            -p "$OC_ADMIN_PWD" \
            -a "$OC_TEST_ADMIN_PWD" \
            -r "$OC_TEST_REST_PWD" "$OC_HOST_NAME")
  STARTLINE1=$(echo -n "$OUTPUT" | grep -n 'Creating schemas TEST_ADMIN and TEST_REST...' | cut -d : -f 1)
  STARTLINE2=$(echo -n "$OUTPUT" | grep -n 'Creating the REST API...' | cut -d : -f 1)
  # find the result of the 1st deployment step
  JSON1=$(echo -n "$OUTPUT" | sed -n "$((STARTLINE1+1)),$((STARTLINE2-1))p")
  # all SQL and PL/SQL statement results are 0 (success):
  RESULT=$(echo -n "$JSON1" | jq .items[].result - | uniq)
  [ "$RESULT" == '0' ]
  # find the result of the 2nd deployment step
  JSON2=$(echo -n "$OUTPUT" | sed -n "$((STARTLINE2+1)),\$p")
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
           "https://$OC_HOST_NAME/ords/test/oauth/token")
  HTTPCODE=$(echo -n "$OUTPUT" | tail -1)
  [ "$HTTPCODE" == '200' ]
  JSON=$(echo -n "$OUTPUT" | sed \$d)
  echo -n "$JSON" | jq -j '.access_token' > "$BATS_TMPDIR/access_token.txt"
}

@test "02. when not authenticated, /test/log/ returns HTTP 401" {
  OUTPUT=$(curl -s -w '\n%{http_code}' -X GET "https://$OC_HOST_NAME/ords/test/log/")
  HTTPCODE=$(echo -n "$OUTPUT" | tail -1)
  echo "HTTP code: $HTTPCODE"
  [ "$HTTPCODE" == '401' ]
}

@test "03. when not authenticated, /test/schema/ returns HTTP 401" {
  OUTPUT=$(curl -s -w '\n%{http_code}' -X GET "https://$OC_HOST_NAME/ords/test/schema/")
  HTTPCODE=$(echo -n "$OUTPUT" | tail -1)
  echo "HTTP code: $HTTPCODE"
  [ "$HTTPCODE" == '401' ]
}

@test "04. when authenticated, /test/log/ is empty at first" {
  ACCESS_TOKEN=$(cat "$BATS_TMPDIR/access_token.txt")
  OUTPUT=$(curl -s -w '\n%{http_code}' -X GET \
           -H "Authorization: Bearer $ACCESS_TOKEN" \
           "https://$OC_HOST_NAME/ords/test/log/")
  HTTPCODE=$(echo -n "$OUTPUT" | tail -1)
  echo "HTTP code: $HTTPCODE"
  [ "$HTTPCODE" == '200' ]
  JSON=$(echo -n "$OUTPUT" | sed \$d)
  # check that there are 0 elements in the "items" array
  COUNT=$(echo -n "$JSON" | jq '.items | length' -)
  [ "$COUNT" == '0' ]
}
