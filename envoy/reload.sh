# no-op calls to `sed`, the -i flag marks the file as moved (editing the file isn't sufficient)
docker compose exec -T envoy sed -i s/xxx/yyy/ /var/lib/envoy/lds.yaml
docker compose exec -T envoy sed -i s/xxx/yyy/ /var/lib/envoy/cds.yaml
