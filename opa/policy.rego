package envoy.authz

import input.attributes.request.http as http_request

default allow = {
  "allowed": false,
  "body": "{ \"data\": null, \"errors\": [{ \"message\": \"Missing credentials\", \"extensions\": { \"http_status\": 401 } }]}",
  "headers": {
    "content-type": "application/json",
  },
  "http_status": 200
}

allow = r {
  token.payload
  not token.valid
  r := {
    "allowed": false,
    "body": "{ \"data\": null, \"errors\": [{ \"message\": \"Invalid credentials\", \"extensions\": { \"http_status\": 403 } }]}",
    "headers": {
      "content-type": "application/json",
    },
    "http_status": 200
  }
}

# OPA is configured to use /envoy/authz/result for the ext_authn response.
# if allow == true, headers are added to the upstream response
# if allow == false, http_status, headers, and body are used in the denied response

result["allowed"] := allow.allowed
result["body"] := allow.body
result["headers"] := object.union(allow.headers, {
  # denied responses must respect CORS headers for response bodies to appear in browsers
  "access-control-allow-origin": http_request.headers.origin
})
result["http_status"] := allow.http_status

# allow CORS preflights
allow = r {
  http_request.method == "OPTIONS"
  r := { "allowed": true }
}

# allow basic GET requests
allow = r {
  http_request.method == "GET"
  not is_application_json
  r := { "allowed": true }
}

# check GraphQL requests for valid tokens
allow = r {
  is_graphql_request
  is_token_valid
  r := {
    "allowed": true,
    "headers": {
      "x-user-id": token.payload.sub,
      "x-user-name": token.payload.name,
    }
  }
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
