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

Visit [Apollo Sandbox](https://studio.apollographql.com/sandbox/explorer?endpoint=http%3A%2F%2Flocalhost%3A8080%2F&explorerURLState=N4IgJg9gxgrgtgUwHYBcQC4QEcYIE4CeABAIq6FHAA6SRRAFggDZMQ0C%2BIANCIwIZh8AZwwhqIAIIwU9CHgCWALz4p5EJFQyaAQgj558RBAQBS9AEYBxKPIDy8kwGUAqooCSARgByDgJwA6YxNFMAB1Nzt5NwAPCIB3eXM4ADEUAC1HNwA2NwBrZKE%2BUK8mePk%2BAA0vdwArCHkATQAmXxQAGTgANQAWBtCPOKtnGErqsM6CMoaKzty3OsaW9q7e-sHLYenZos6YZud5NoBhEwAHaZI7GoBRJq8AFRJvABESRQBZRQBzITcVqCO2Xe9waL2cHmBrlsAAkAAz%2BLwAaQIAHZnABWbRfNLQvjJJBHWEAZjwWSJuXoiIQcRc0OeRKQRKyXwAHFk0iQAGYAfRIvi%2ByQ8OD4JGiQgabjw3QAtE0AG6cgAKHiQ0SYcrSHgasO63RZNzS8mkuUcQne7ya7w8zwASmAmDbHFk8CQUbDcs8vChObl3ng%2BB4JG5ESqGhJLG8akIkFkTHBcoMGnhQiQmopnGkIF8mtDTnwhNovNFrnAhI5oaF3OiYBVubDLLD3kw0oovDbua2%2BO8UNFOQgWRVfHhHPIhBIJE1EM9nG4IKFFYi0tc5SR0jaUdcYDA8PRFSZ3tLEc8mI44GkUWl7uYWb5FIj7kgJO2jjaCNp5JZfJrHM9nj8mhIUAQLYNTaCY6IkIgcp4CyDT3NyRb3K%2BEDXM4LLchAcDSngKJ8Nozh4IiJzRFAfASPQ9ynM4CAmNCCCKlkSByvI2jvNyaReM81zctoNoePIX7ol8WBYDU3KKskvjXCgSChBIcqnAgCBwLYRyOFANqwpy0JxF8micOwQA). (Notice the `Authorization` header in the Headers pane.)

Or use `curl`:

```
curl http://localhost:8080/ \
  -H 'Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxIiwibmFtZSI6IkFsaWNlIiwiaXNzIjoiY29tLmV4YW1wbGUuaXNzdWVyIiwiYXVkIjoiY29tLmV4YW1wbGUuYXVkaWVuY2UiLCJpYXQiOjE2NTQ1NDQzMzgsImV4cCI6MTY1NDU1MTUzOH0.NKy7U5BgZHaFnC03r63khKewSUHD3n36g86ZQf_Q9gF1quaQxsYIr4-2vfP1nxlvZ1Y0448jEZiutkSsMM2M1DRdlRS6rQ70kDNtfkMra1AIK1nYAGQzjsn6JmkwbYrWQ2zUZog2HpasBNxEmsSHWzI5uX_0G0MlZzNR_zNaMtxfe8X9rSisAA2meDUIoWPKZEvQtZR7EuurhPJM-KDlSmZ7ZTb89zKTnAR_CRyBiG9Z1SDDgs2AcoOjBJ5Qmevr8YT_NxTRyoEU8_om-r7aBUrKCJxcaAhTpUeJHeP6nviBM_ZNDE_BR1i9Z5gqqj_PF9EtnWAvpeemOCScR0fHwg' \
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

- No support for key rotation (selecting the appropriate with according to its `kid`).

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
