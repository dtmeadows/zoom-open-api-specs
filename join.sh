#!/usr/bin/env bash

# all these apis share a similiar security scheme. The only difference is the OAUTH scopes they define
# trivially let's just take 1 of the schemes, add all the scopes to it, and then remove the scheme from the others
# probalby could do a json merge to make this easier
UNIFIED_SCOPES=$(cat ZoomRESTspecs/*.json | jq -n '{ scopes: [ inputs.components.securitySchemes.openapi_oauth.flows.authorizationCode.scopes ] | add }' | jq -c '.scopes')

# go through all the operationIds and find the ones that have more than one entry
CONFLICTING_OPERATION_IDS=$(cat ZoomRESTspecs/*.json | jq '.paths[][].operationId' | jq -s 'group_by(.) | map(select(length>1) | .[0])')

cd ZoomRESTspecs || exit
for i in *.json; do
    [ -f "$i" ] || break
    echo "Processing $i file..."

    with_security_scheme=""
    if [ "$i" = "ZoomAccountAPISpec.json" ]; then
        # add all the unified scopes to the first security scheme
        with_security_scheme=$(jq --argjson unified_scopes "$UNIFIED_SCOPES" '.components.securitySchemes.openapi_oauth.flows.authorizationCode.scopes = $unified_scopes' "$i")
    else
        # otherwise just remove the security scheme
        with_security_scheme=$(jq 'del(.components.securitySchemes)' "$i")
    fi

    filename_without_extension=$(echo "$i" | cut -f 1 -d '.')
    # now go through and make all the operationId's unique by appending the filename if the operation ID is in the list of conflicting operation IDs
    with_security_scheme=$(echo "$with_security_scheme" | jq --arg filename "$filename_without_extension" --argjson conflicting_operation_ids "$CONFLICTING_OPERATION_IDS" '.paths[][] |= (.operationId as $oid | if($conflicting_operation_ids | index($oid)) then .operationId = .operationId + $filename else . end)')

    echo "$with_security_scheme" > ../ZoomRESTspecsSansConflicts/"$i"
done
cd ..

redocly join ./ZoomRESTspecsSansConflicts/*.json --prefix-tags-with-info-prop title -o ./ZoomUnifiedSpec.json