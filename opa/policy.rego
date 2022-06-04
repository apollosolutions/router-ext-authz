package envoy.authz

import input.attributes.request.http as http_request

default allow := false

allow {
    http_request.method == "OPTIONS"
}

allow {
    http_request.method == "GET"
    not is_application_json
}

is_application_json {
    http_request.headers["content-type"] == "application/json"
}

allow {
    is_graphql_post
    is_token_valid
}

is_graphql_post {
    http_request.method == "POST"
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

status_code := 200 {
  allow
} else := 401 {
  not is_token_valid
} else := 403 {
  true
}

body := json.marshal({ "data": null, "errors": [{ "message": "Authorization failed" }]}) { status_code == 401 }
body := json.marshal({ "data": null, "errors": [{ "message": "Unauthorized Request" }]}) { status_code == 403 }

default headers := { "content-type": "application/json" }
headers := {
    "x-user-id": token.payload.sub,
    "x-user-name": token.payload.name,
  } {
  allow
}

result["allowed"] := allow
result["status_code"] := status_code
result["headers"] := headers
result["body"] := body

jwks_request(url) = http.send({
    "url": url,
    "method": "GET",
    "force_cache": true,
    "force_cache_duration_seconds": 3600 # Cache response for an hour
})

# decode_verify requires a json-encoded string, not an object
jwks = json.marshal(jwks_request(opa.runtime().env["JWKS_ENDPOINT"]).body)
