package envoy.authz

import input.attributes.request.http as http_request

default result = { "allowed": false }

# OPTIONS preflight requests
result = { "allowed": true } {
  http_request.method == "OPTIONS"
}

# Simple requests
result = { "allowed": true } {
  http_request.method == "GET"
  not is_application_json
}

# Missing authorization header
missing_credentials = json.marshal({ "data": null, "errors": [{ "message": "Missing credentials", "extensions": { "status_code": 401 } }] })
result = { "allowed": false, "headers": denied_response_headers, "body": missing_credentials, "http_status": 200 } {
  is_graphql_request
  not token
}

# Invalid JWT
invalid_credentials_body = json.marshal({ "data": null, "errors": [{ "message": "Invalid credentials", "extensions": { "status_code": 403 } }] })
result = { "allowed": false, "headers": denied_response_headers, "body": invalid_credentials_body, "http_status": 200 } {
  is_graphql_request
  token
  not is_token_valid
}

# Operation depth too large
depth_limit_body = json.marshal({ "data": null, "errors": [{ "message": "Query depth limit exceeded", "extensions": { "status_code": 400 } }] })
result = { "allowed": false, "headers": denied_response_headers, "body": depth_limit_body, "http_status": 200  } {
  is_graphql_request
  is_token_valid
  operation_exceeds_depth_limit
}

# OK result, pass JWT claims to router
result = { "allowed": true, "headers": allowed_request_headers } {
  is_graphql_request
  is_token_valid
  not operation_exceeds_depth_limit
}

denied_response_headers = {
  "content-type": "application/json",
  # denied responses must respect CORS headers for response bodies to appear in browsers
  "access-control-allow-origin": http_request.headers.origin
}

allowed_request_headers = {
  "x-user-id": token.payload.sub,
  "x-user-name": token.payload.name,
}

is_application_json {
    http_request.headers["content-type"] == "application/json"
}

is_graphql_request {
    is_application_json
    input.parsed_body.query
}

is_token_valid {
    token.valid
    # TODO: check token.payload.exp < now
}

token := {"valid": valid, "payload": payload} {
    [_, encoded] := split(http_request.headers.authorization, " ")
    [valid, _, payload] := io.jwt.decode_verify(encoded, {
      "cert": jwks,
      "iss": "com.example.issuer",
      "aud": "com.example.audience"
    })
}

jwks_request(url) = http.send({
    "url": url,
    "method": "GET",
    "force_cache": true,
    "force_cache_duration_seconds": 3600 # Cache response for an hour
})

# decode_verify requires a json-encoded string, not an object
jwks = json.marshal(jwks_request(opa.runtime().env["JWKS_ENDPOINT"]).body)

# parsed operation documents
parsed_document = graphql.parse_query(input.parsed_body.query)

named_operation = o {
  	parsed_document.Operations[_].Name == input.parsed_body.operationName
    o := parsed_document.Operations[_]
}

anonymous_operation = parsed_document.Operations[0]

operation = o { o := named_operation }
operation = o { o := anonymous_operation }

default operation_exceeds_depth_limit = false
operation_exceeds_depth_limit {
  # limit to depth of 8
  operation.SelectionSet[_].SelectionSet[_].SelectionSet[_].SelectionSet[_].SelectionSet[_].SelectionSet[_].SelectionSet[_].SelectionSet[_]
}
