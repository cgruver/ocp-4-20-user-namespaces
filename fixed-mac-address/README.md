# How to create a Pod with a known MAC address

```bash
oc apply -f fixed-mac-address/scc.yaml
oc new-project fixed-mac-test
oc apply -f fixed-mac-address/pod.yaml
```

Note: The details of the container image are in `fixed-mac-address/Containerfile` and `fixed-mac-address/entrypoint.sh`

The SCC enables CAP_NET_ADMIN for manipulating the network device, and CAP_SETUID/CAP_SETGID for sudo.
