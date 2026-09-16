# User Namespaces Enabled in OCP 4.20

Watch the video here: [https://youtu.be/fX_IzmR2hkE](https://youtu.be/fX_IzmR2hkE)

OpenShift 4.20 includes support for kernel level user namespaces!

Why is this important?

It unlocks a whole slew of possibilities for making your OpenShift environment even more secure than it already is, while at the same time giving you more freedom around what you run and how you run it inside your containers.

Would you like to run container-in-container in OpenShift?

Would you like to run as a known UID in a container?

Would you like to run as root inside of a container?

Well...  NOW YOU CAN!

Let's explore.

This git repo includes a `devfile.yaml` that enables you to launch a Dev Spaces workspace.  If you want to try it out, first visit this link to set up Dev Spaces in your cluster: [https://github.com/cgruver/ocp-4-20-nested-containers](https://github.com/cgruver/ocp-4-20-nested-containers)

__Note:__ The container image used for this demo can be found in the `workspace-image` folder of this repo.

# Running a Pod with a fixed UID using User Namespaces

Log in as a cluster administrator

```bash
oc login -u=admin $(oc whoami --show-server)
podman login -u $(oc whoami) -p $(oc whoami -t) image-registry.openshift-image-registry.svc:5000
```

Create an OpenShift Project

```bash
oc new-project userns-test
```

Create an SCC that ensures Pods run as UID 375

```bash
cat << EOF | oc apply -f -
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: uid-375
priority: null
fsGroup:
  type: MustRunAs
  uid: 375
runAsUser:
  type: MustRunAs
  uid: 375
seLinuxContext:
  type: MustRunAs
userNamespaceLevel: RequirePodLevel
EOF
```

Build the image

```bash
podman build -t image-registry.openshift-image-registry.svc:5000/userns-test/uid-375:latest ./fixedId
podman push image-registry.openshift-image-registry.svc:5000/userns-test/uid-375:latest
```

Create a Pod

```bash
cat << EOF | oc apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: uid-375
  namespace: userns-test
  annotations:
    openshift.io/scc: uid-375
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
      name: uid-375
      securityContext:
        capabilities:
          drop:
            - ALL
        runAsUser: 375
      imagePullPolicy: Always
      image: 'image-registry.openshift-image-registry.svc:5000/userns-test/uid-375:latest'
EOF
```

## Run a container inside a container in a Pod.

Create a SecurityContextConstraint that allows container-in-container:

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
  uid: 1000
runAsUser:
  type: MustRunAs
  uid: 1000
seLinuxContext:
  type: MustRunAs
  seLinuxOptions:
    type: container_engine_t
userNamespaceLevel: RequirePodLevel
EOF
```

Build the image

```bash
podman build -t image-registry.openshift-image-registry.svc:5000/userns-test/container-in-container:latest ./nested-containers
podman push image-registry.openshift-image-registry.svc:5000/userns-test/container-in-container:latest
```

Create a Pod

```bash
cat << EOF | oc apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: container-in-container
  namespace: userns-test
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
        allowPrivilegeEscalation: true
        procMount: Unmasked
      imagePullPolicy: Always
      image: 'image-registry.openshift-image-registry.svc:5000/userns-test/container-in-container:latest'
EOF
```

Open a shell into the Pod

```bash
oc rsh container-in-container
```

Note that your UID is 1000 inside the Pod

```bash
id
```

Pull a container image

```bash
podman pull quay.io/libpod/banner
```

Run a container with the image

```bash
podman run -d --rm --name webserver -p 8080:80 quay.io/libpod/banner
```

Curl the Nginx endpoint in the running container

```bash
curl http://localhost:8080
```

Open a shell into the container

```bash
podman exec -it webserver /bin/sh 
```

When done, delete the Pod

## Run a Pod as root

Create another SecurityContextConstraint

```bash
cat << EOF | oc apply -f -
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: run-as-root
priority: null
fsGroup:
  type: RunAsAny
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: MustRunAs
userNamespaceLevel: RequirePodLevel
EOF
```

Build the image

```bash
podman build -t image-registry.openshift-image-registry.svc:5000/userns-test/run-as-root:latest ./runAsRoot
podman push image-registry.openshift-image-registry.svc:5000/userns-test/run-as-root:latest
```

Create a Pod that runs as root inside the Pod

```bash
cat << EOF | oc apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: run-as-root
  namespace: userns-test
  annotations:
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
      imagePullPolicy: Always
      image: 'image-registry.openshift-image-registry.svc:5000/userns-test/run-as-root:latest'
EOF
```

## Enable `sudo` in a Pod - aka Run a Pod with a fixed MAC address

Create another SecurityContextConstraint

The SCC enables CAP_NET_ADMIN for manipulating the network device, and CAP_SETUID/CAP_SETGID for sudo.

```bash
cat << EOF | oc apply -f -
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: user-namespace-net-admin
priority: null
allowPrivilegeEscalation: true
allowedCapabilities:
- SETUID
- SETGID
- NET_ADMIN
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
supplementalGroups:
  type: MustRunAs
  ranges:
  - min: 1000
    max: 65534
userNamespaceLevel: RequirePodLevel
EOF
```

Build the image

```bash
podman build -t image-registry.openshift-image-registry.svc:5000/userns-test/set-mac:latest ./sudo
podman push image-registry.openshift-image-registry.svc:5000/userns-test/set-mac:latest
```

Create a Pod

```bash
cat << EOF | oc apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: fixed-mac-addr
  namespace: userns-test
  annotations:
    openshift.io/scc: user-namespace-net-admin
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
      name: fixed-mac-addr
      securityContext:
        capabilities:
          add:
            - NET_ADMIN
            - SETUID
            - SETGID
          drop:
            - ALL
        runAsUser: 1000
        allowPrivilegeEscalation: true
      imagePullPolicy: Always
      image: 'image-registry.openshift-image-registry.svc:5000/userns-test/set-mac:latest'
EOF
```
