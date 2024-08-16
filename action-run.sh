#!/bin/bash

TEMP=$(getopt -n "$0" -a -l "hostname:,username:,password:,outputfile:" -- -- "$@")

[ $? -eq 0 ] || exit

eval set -- "$TEMP"

while [ $# -gt 0 ]
do
    case "$1" in
        --hostname) PERFAI_HOSTNAME="$2"; shift;;
        --username) PERFAI_USERNAME="$2"; shift;;
        --password) PERFAI_PASSWORD="$2"; shift;;
        --outputfile) OUTPUT_FILENAME="$2"; shift;;
        --) shift ;;
    esac
    shift;
done

echo " "

### Step 1:Authenticate User Get Token
TOKEN_RESPONSE=$(curl -s --location --request POST "https://api.perfai.ai/api/v1/auth/token" \
--header "Content-Type: application/json" \
--data-raw "{
    \"username\": \"${PERFAI_USERNAME}\",
    \"password\": \"${PERFAI_PASSWORD}\"
}")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.id_token')

if [ -z "$ACCESS_TOKEN" ]; then
    echo "Failed to retrieve access token."
    echo "Response was: $TOKEN_RESPONSE"
    exit 1
fi

echo "Access Token is: $ACCESS_TOKEN"
echo " "


### Step 2: Retrieve Catalog and App ID ###
CATALOG_RESPONSE=$(curl -s --location --request GET "https://api.perfai.ai/api/v1/sensitive-data-service/apps/all?page=1&pageSize=1" \
--header "Authorization: Bearer $ACCESS_TOKEN")

CATALOG_ID=$(echo $CATALOG_RESPONSE | jq -r '.data[].catalog_id')
APP_ID=$(echo $CATALOG_RESPONSE | jq -r '.data[]._id')

if [ -z "$CATALOG_ID" ]; then
    echo "Failed to retrieve catalog ID."
    echo "Response was: $CATALOG_RESPONSE"
fi

if [ -z "$APP_ID" ]; then
    echo "Failed to retrieve catalog ID."
    echo "Response was: $APP_ID"
fi

echo "Catalog ID is: $CATALOG_ID"
echo "APP ID is: $APP_ID"
echo " "

### Step 3: Schedule Action-Run ###
RUN_RESPONSE=$(curl -s --location --request POST "https://api.perfai.ai/api/v1/api-catalog/apps/schedule-run-multiple" \
--header "Content-Type: application/json" \
--header "Authorization: Bearer $ACCESS_TOKEN" \
--data-raw "{
    \"catalog_id\": \"${CATALOG_ID}\",
    \"services\": [\"governance\", \"vms\", \"sensitive\", \"apitest\", \"performance\"]
}")

echo "Run Response: $RUN_RESPONSE"
echo " "

### Step 4: Sensitive Data Details ###

# sensitivefielddata=$(curl -s --location --request GET "https://api.perfai.ai/api/v1/sensitive-data-service/apps/endpoint-piis?app_id=$APP_ID&page=1&pageSize=1" \
# --header "Authorization: Bearer $ACCESS_TOKEN" | jq -r '{
#    "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
#     "version": "2.1.0",
#     "runs": [
#         {
#             "tool": {
#                 "driver": {
#                     "name": "Custom Security Tool",
#                     "version": "1.0.0",
#                     "informationUri": "https://example.com",
#                     "rules": []
#                 }
#             },
#             "results": [
#                 {
#                     "ruleId": "PII-Leak",
#                     "message": {
#                         "text": .issues[].explainer
#                     },
#                     "locations": [
#                         {
#                             "physicalLocation": {
#                                 "artifactLocation": {
#                                     "uri": .issues[].path,
#                                     "uriBaseId": "%SRCROOT%"
#                                 },
#                                 "region": {
#                                     "startLine": 1,
#                                     "startColumn": 1
#                                 }
#                             }
#                         }
#                     ],
#                     "properties": {
#                         "id": .issues[].id,
#                         "impact": .issues[].impact,
#                         "name": .issues[].name,
#                         "label": .issues[].label,
#                         "direction": .issues[].direction,
#                         "severity": .issues[].severity,
#                         "created_on": .issues[].created_on,
#                         "response": .issues[].response,
#                         "remediation": .issues[].remediation
#                     }
#                 }
#             ]
#         }
#     ]
# }')



# Write SARIF data to file
# echo "Sensitive Data Fields: $sensitivefielddata"
# echo " "

# echo "$sensitivefielddata" >> $GITHUB_WORKSPACE/$OUTPUT_FILENAME

sensitivefielddata=$(curl -s --location --request GET "https://api.perfai.ai/api/v1/sensitive-data-service/apps/endpoint-piis?app_id=$APP_ID&page=1&pageSize=1" \
--header "Authorization: Bearer $ACCESS_TOKEN" | jq -r '{
  "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "Custom Security Tool",
          "version": "1.0.0",
          "informationUri": "https://example.com/tool-info",
          "rules": [
            {
              "id": "PII-Leak",
              "shortDescription": {
                "text": "Sensitive PII Data Leak"
              },
              "fullDescription": {
                "text": "PII Data includes personally identifiable information used for online identification, such as names, addresses, and contact details."
              },
              "helpUri": "https://example.com/rules/PII-Leak",
              "properties": {
                "tags": ["security", "privacy"]
              }
            }
          ]
        }
      },
      "results": [
        {
          "ruleId": "PII-Leak",
          "message": {
            "text": "Encrypt sensitive PII data during storage and transmission to prevent unauthorized access. Implement masking or partial obfuscation techniques where feasible."
          },
          "locations": [
            {
              "physicalLocation": {
                "artifactLocation": {
                  "uri": "user/%7Busername%7D",
                  "uriBaseId": "%SRCROOT%"
                },
                "region": {
                  "startLine": 1,
                  "startColumn": 1
                }
              }
            }
          ],
          "properties": {
            "id": "66b357212f900c785d28206a",
            "impact": "Leak",
            "location": "Response Field.username",
            "name": "username",
            "label": "PII Data",
            "direction": "OUT",
            "severity": "Medium",
            "created_on": "2024-08-10T09:30:27.739Z",
            "response": "{\"id\":1,\"username\":\"johnsmith\",\"firstName\":\"John\",\"lastName\":\"Smith\",\"email\":\"john@example.com\",\"password\":\"s3cur3p@ssw0rd\",\"phone\":\"1234567890\",\"userStatus\":5}",
            "explainer": "PII Data includes personally identifiable information used for online identification, such as names, addresses, and contact details.",
            "remediation": "Encrypt sensitive PII data during storage and transmission to prevent unauthorized access. Implement masking or partial obfuscation techniques where feasible."
          }
        }
      ]
    }
  ]
}')

echo "Sensitive Field Details: $sensitivefielddata"

echo "$sensitivefielddata" >> $GITHUB_WORKSPACE/$OUTPUT_FILENAME 


# sensitivefielddata=$(curl -s --location --request GET "https://api.perfai.ai/api/v1/sensitive-data-service/apps/endpoint-piis?app_id=$APP_ID&page=1&pageSize=1" \
# --header "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.issues[] | {id, path, impact: .impact, location: .location, name: .name, label: .label, direction: .direction, severity: .severity, created_on: .created_on, response: .response, explainer: .explainer, remediation: .remediation}')

# echo "Sensitive Data Fields: $sensitivefielddata"
# echo " "

# echo "$sensitivefielddata" >> $GITHUB_WORKSPACE/$OUTPUT_FILENAME
# echo "SARIF output file created successfully"

