# User Namespaces Enabled in OCP 4.20

OpenShift 4.20 includes support for kernel level user namespaces!

Why is this important?

It unlocks a whole slew of possibilities for making your OpenShift environment even more secure than it already is, while at the same time giving you more freedom around what you run and how you run it inside your containers.

Would you like to run container-in-container in OpenShift?

Would you like to run as a known UID in a container?

Would you like to run as root inside of a container?

Well...  NOW YOU CAN!

Let's explore.

This git repo includes a `devfile.yaml` that enables you to launch a Dev Spaces workspace.  If you want to try it out, first visit this link to set up Dev Spaces in your cluster: [https://github.com/cgruver/ocp-4-20-nested-containers](https://github.com/cgruver/ocp-4-20-nested-containers)

# Run a container inside a container.

```bash
cat << EOF | oc apply -f -
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: container-in-container
priority: null
allowPrivilegeEscalation: true
allowedCapabilities:
- SETUID
- SETGID
fsGroup:
  type: MustRunAs
  ranges:
  - min: 1000
    max: 65534
runAsUser:
  type: MustRunAs
  uid: 1000
seLinuxContext:
  type: MustRunAs
  seLinuxOptions:
    type: container_engine_t
supplementalGroups:
  type: MustRunAs
  ranges:
  - min: 1000
    max: 65534
userNamespaceLevel: RequirePodLevel
EOF
```

```bash
oc new-project userns-test
```

```bash
cat << EOF | oc apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: container-in-container
  annotations:
    io.kubernetes.cri-o.Devices: '/dev/fuse,/dev/net/tun'
    openshift.io/scc: container-in-container
spec:
  hostUsers: false
  restartPolicy: Always
  containers:
    - resources:
        limits:
          cpu: "1"
          memory: 2Gi
        requests:
          cpu: 100m
          memory: 256Mi
      name: container-in-container
      securityContext:
        capabilities:
          add:
            - SETGID
            - SETUID
          drop:
            - ALL
        runAsUser: 1000
        runAsNonRoot: true
        readOnlyRootFilesystem: false
        allowPrivilegeEscalation: true
        procMount: Unmasked
      imagePullPolicy: Always
      image: 'quay.io/cgruver0/che/ocp-4-20-userns:latest'
EOF
```

```bash
oc rsh container-in-container
```

```bash
id
```

```bash
podman pull quay.io/libpod/banner
```

```bash
podman run -d --rm --name webserver -p 8080:80 quay.io/libpod/banner
```

```bash
curl http://localhost:8080
```


```bash
cat << EOF | oc apply -f -
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: run-as-root
priority: null
allowPrivilegeEscalation: true
fsGroup:
  type: RunAsAny
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: MustRunAs
  seLinuxOptions:
    type: container_engine_t
supplementalGroups:
  type: RunAsAny
userNamespaceLevel: RequirePodLevel
EOF
```

```bash
cat << EOF | oc apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: run-as-root
  annotations:
    io.kubernetes.cri-o.Devices: '/dev/fuse,/dev/net/tun'
    openshift.io/scc: run-as-root
spec:
  hostUsers: false
  restartPolicy: Always
  containers:
    - resources:
        limits:
          cpu: "1"
          memory: 2Gi
        requests:
          cpu: 100m
          memory: 256Mi
      name: run-as-root
      securityContext:
        capabilities:
          drop:
            - ALL
        runAsUser: 0
        readOnlyRootFilesystem: false
        allowPrivilegeEscalation: true
        procMount: Unmasked
      imagePullPolicy: Always
      image: 'quay.io/cgruver0/che/ocp-4-20-userns:latest'
EOF
```
