# External Auth for Apollo Router using Envoy

**The code in this repository is experimental and has been provided for reference purposes only. Community feedback is welcome but this project may not be supported in the same way that repositories in the official [Apollo GraphQL GitHub organization](https://github.com/apollographql) are. If you need help you can file an issue on this repository, [contact Apollo](https://www.apollographql.com/contact-sales) to talk to an expert, or create a ticket directly in Apollo Studio.**

DISCLAIMER: This is an example for illustrative purposes. It has not been security audited.

## Overview

This repo demonstrates using Envoy to:

- Verify access tokens as JWTs (JSON Web Token) using public keys from a JWKS (JSON Web Key Set) server.
- Use Envoy's `ext_authz` plugin to authorize requests using an auth service.
- Forward user information to subgraphs using Apollo Router's header propagation configuration.

```mermaid
sequenceDiagram
  Client->>Envoy: Request with token
  Envoy->>Auth: Authorize request
  Auth->>JWKS: Fetch key for verifying token
  Auth->>Envoy: 200 OK + new headers
  Envoy->>Router: Request with new headers
  Router->>Subgraph: Subgraph fetch with new headers
```

Considerations when evaluating this approach:

- No Apollo Router plugins necessary.
- Authentication happens outside of the GraphQL API. The entire graph requires a valid access token, so this doesn't support unauthenticated access patterns or `login` mutations.
- Envoy and Open Policy Agent typically run as sidecars to the Router, making network requests between the three components fast.
- Envoy can also enforce mutual TLS between the Router and subgraph.

## Running the demo

```sh
docker compose up --build
```

Visit [Apollo Sandbox](https://studio.apollographql.com/sandbox/explorer?endpoint=http%3A%2F%2Flocalhost%3A8080%2F&explorerURLState=N4IgJg9gxgrgtgUwHYBcQC4QEcYIE4CeABAKIAeAhnAA4A2CAiroUcADpJFEAWCttEDgF8OIADQheFMPgDOGEOxABBGCm4Q8ASwBeFFFohI2GEwCEEFPPiIICAKW4AjAOJQtAeS32AygFUdAEkARgA5bwBOADo7ex0wAHVAzy1AsmSAdy0nOAAxFAAtH0CANkCAa1zZCgTQ2kytCgANUKCAKwgtAE0AJgiUABk4ADUAFi6E4IzXPxhm1sThggaupuHywI7uvsGR8cnpl1nV9ZrhmF6-LQGAYXtqVYZPNpIe0IAVBgBmAFl3gHMAKw-Nq5aIAMwSSBuJAAIggCkgCrQbjcdAxRgBaWQ3ABuHmGLlxSHsYBcA2CAHYfqFcT1AgAONpJAZ%2BNpwBIMCAACUp3G4tH%2BPT8AAZuH4SnBuRk-P9ZGQyNxyoCegyzGQ2oEErQMmQAPoAaRcyj1ZmoeB0evBgVxCRQXW5UG5eASLwACh4GT1ynASMoENwBiQzIbaBEkD8nBEELkbi4XD9ZHrcU53gNuIEmk1ytR3j4voCEhRwW7cdQmblwbl7MMIspyqMMqMegQoBRyjBuB4BoCuriBpTuig2l8voEfAhlBQ3XkEHrQsp-niICQbqE2j4CAAlN0EUJIbiYwElWh%2BAY-XwuOA-LoeHQFJxQEooHoiroIFCwzF%2BFwFPx4JAGC3WFgnsdURULFAtwQcouicNoSneJoDTwEoEBKRMEC3MAMkxXFAlyVYwAGYZZBIJAKDIJxuR8PUIi6NohgNEUkAyYYbzdPwqmoGEtAQL4zBuBIRVobh7B6XEXECd4GX%2BYISn%2Bf4GFkagCC6YYGBMIQQCEIA). (Notice the `Authorization` header in the Headers pane.)

Or use `curl`:

```
curl http://localhost:8080/ \
  -H 'Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxIiwibmFtZSI6IkFsaWNlIiwiaXNzIjoiY29tLmV4YW1wbGUuaXNzdWVyIiwiYXVkIjoiY29tLmV4YW1wbGUuYXVkaWVuY2UiLCJpYXQiOjE2NTQ3MTg5MjF9.fWnCEDeZnZlCCzQ4-sCvOVGvnJdGL17MNv2I8jWILUjmWQoH7hhlg2U0hU6mHwUgsxxhk528BxjIWlwx_KGA_Bprz_fIvWtYHcHrWjEPO82kmEAehLEB_Kl9nMb9eFCGGMs_vbTLhIXXkpTS35WafPvp8jFfFJV9Ak4w42ycakuhOL5YvL7iYtj33ISeAaPmFe_NAgCvoECNjSyRPyNnh-56lULMJSGmMYOzZbc6t20YetD-UGZUrnQRD1JBx05WtRekYbj6TXKr6e6MseRdw-vIFYXdLVsEnaxbHS_9YjLmK0nwVMYPUFspCEie3BCW0lhJ2vGIT8g16ggQspyYVQ' \
  -H 'content-type: application/json' \
  -d '{"query":"{hello}"}'
```

## Auth server options for Envoy `ext_authz`

### HTTP server

The default Docker Compose example uses a Node.js server to verify the client JWT. It also extracts headers from the JWT payload and returns them as headers to be forwarded through the router to subgraphs.

The `ext_authz` plugin's [`http_service`][http_service] allows specifying which headers are sent to the auth service, as well as which response headers from the auth service will be added to the request.

[http_service]: https://github.com/envoyproxy/envoy/blob/c98dc9f7a3e8fd53000d622e05727f3503f2a135/api/envoy/extensions/filters/http/ext_authz/v3/ext_authz.proto#L210

### Open Policy Agent (gRPC server)

The `ext_authz` plugin also supports [gRPC auth services][grpc_service]. Open Policy Agent has built-in support for the [`Check` RPC method][check].

[grpc_service]: https://github.com/envoyproxy/envoy/blob/c98dc9f7a3e8fd53000d622e05727f3503f2a135/api/envoy/extensions/filters/http/ext_authz/v3/ext_authz.proto#L40
[check]: https://github.com/envoyproxy/envoy/blob/c98dc9f7a3e8fd53000d622e05727f3503f2a135/api/envoy/service/auth/v3/external_auth.proto#L33

To run this example:

```sh
docker compose -f docker-compose-opa.yaml up --build
```

Open Policy Agent downloads a policy bundle from the bundle server, which contains:

- Policies for allowing requests based on HTTP method, content type, and valid access tokens.
- A cached request to the JWKS server for verifying the token.
- A "result" object in the respond to include additional properties on the [`CheckResponse`][checkresponse] message for setting headers, status codes, and response bodies.

[checkresponse]: https://github.com/envoyproxy/envoy/blob/c98dc9f7a3e8fd53000d622e05727f3503f2a135/api/envoy/service/auth/v3/external_auth.proto#L118

## Limitations

- Does not demonstrate key rotation (the JWKS server returning multiple keys in a single key set and verifying the JWT with the correct key by matching `kid`.) See the [Open Policy Agent blog post](https://blog.styra.com/blog/integrating-identity-oauth2-and-openid-connect-in-open-policy-agent) for an example.

## Appendix

### References

- [Envoy External Authorization](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/ext_authz_filter)
- [OPA + JWKS](https://blog.styra.com/blog/integrating-identity-oauth2-and-openid-connect-in-open-policy-agent)

### Details

Generating public/private keys in the JWKS service:

```sh
cd jwks-service
openssl genpkey -algorithm RSA -out privatekey.pem
openssl rsa -in privatekey.pem -outform PEM -pubout -out publickey.pem
```

Generating an access token:

```sh
docker compose up -d
curl http://localhost:4005/login -H 'content-type: application/json' -d '{"sub": "1", "name": "Alice"}' | pbcopy
docker compose down
```

Bundling policies for OPA:

```sh
cd opa
# https://www.openpolicyagent.org/docs/latest/#1-download-opa
curl -L -o opa https://openpolicyagent.org/downloads/v0.41.0/opa_darwin_amd64
./opa build policy.rego
```

Debugging OPA Check requests with [`grpcurl`](https://github.com/fullstorydev/grpcurl):

```sh
grpcurl -plaintext -d '
{
  "attributes": {
    "request": {
      "http": {
        "body": "{\"query\":\"query Query {\\n  hello\\n}\",\"variables\":{},\"operationName\":\"Query\"}",
        "headers": {
          ":authority": "localhost:8080",
          ":method": "POST",
          ":path": "/",
          ":scheme": "http",
          "content-type": "application/json"
        },
        "host": "localhost:8080",
        "id": "17812313932871240739",
        "method": "POST",
        "path": "/",
        "protocol": "HTTP/1.1",
        "scheme": "http",
        "size": "76"
      }
    }
  }
}' localhost:9191 envoy.service.auth.v3.Authorization/Check
```
