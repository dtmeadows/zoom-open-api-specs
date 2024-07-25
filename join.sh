#!/usr/bin/env bash

# first pass through all the files and build up a unified security schemes object
UNIFIED_SCOPES=$(cat ZoomRESTspecs/*.json | jq -n '{ scopes: [ inputs.components.securitySchemes.openapi_oauth.flows.authorizationCode.scopes ] | add }' | jq -c '.scopes')

cd ZoomRESTspecs || exit
for i in *.json; do
    [ -f "$i" ] || break
    echo "Processing $i file..."

    with_security_scheme=""
    if [ "$i" = "ZoomAccountAPISpec.json" ]; then
        # add all the unified scopes to the first security scheme
        with_security_scheme=$(cat "$i" | jq --argjson unified_scopes "$UNIFIED_SCOPES" '.components.securitySchemes.openapi_oauth.flows.authorizationCode.scopes = $unified_scopes' )
    else
        # otherwise just remove the security scheme
        with_security_scheme=$(jq 'del(.components.securitySchemes)' "$i")
    fi

    echo "$with_security_scheme" > ../ZoomRESTspecsSansConflicts/"$i"
done


redocly join ./ZoomRESTspecsSansConflicts/*.json --prefix-tags-with-info-prop title -o ./ZoomUnifiedSpec.json