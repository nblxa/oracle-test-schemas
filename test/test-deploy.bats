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
}

@test "02. SQL Log is empty" {
  OUTPUT=$(curl -s -X GET -u "TEST_REST:$OC_TEST_REST_PWD" "https://$OC_HOST_NAME/ords/test/log/")
  # check that there are 0 elements in the "items" array
  COUNT=$(echo -n "$OUTPUT" | jq '.items | length' -)
  [ "$COUNT" == '0' ]
}
