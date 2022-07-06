# Capabilities on Kubernetes demos

## Demo 1 - Pod running with UID 0 vs container running with nonroot UID

> Cluster was created with the following command: `kcli create kube generic -P masters=1 -P workers=1 -P master_memory=4096 -P numcpus=2 -P worker_memory=4096 -P sdn=calico -P version=1.24 -P ingress=true -P ingress_method=nginx -P metallb=true -P engine=crio -P domain=linuxera.org caps-cluster`

1. Create a namespace

    ~~~sh
    NAMESPACE=test-capabilities
    kubectl create ns ${NAMESPACE}
    ~~~
2. Create a pod running our application with UID 0:

    ~~~sh
    cat <<EOF | kubectl -n ${NAMESPACE} create -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: reversewords-app-captest-root
    spec:
      containers:
      - image: quay.io/mavazque/reversewords:ubi8
        name: reversewords
        securityContext:
          runAsUser: 0
      dnsPolicy: ClusterFirst
      restartPolicy: Never
    status: {}
    EOF
    ~~~
3. Let's review the thread capability sets:

    ~~~sh
    kubectl -n ${NAMESPACE} exec -ti reversewords-app-captest-root -- grep Cap /proc/1/status
    ~~~
4. We can see that the permitted and effective set have some capabilities, if we decode them this is what we get:

    ~~~sh
    CapInh:	00000000000005fb
    CapPrm:	00000000000005fb
    CapEff:	00000000000005fb
    CapBnd:	00000000000005fb
    CapAmb:	0000000000000000
    ~~~
    ~~~sh
    $ capsh --decode=00000000000005fb
    0x00000000000005fb=cap_chown,cap_dac_override,cap_fowner,cap_fsetid,cap_kill,cap_setgid,cap_setuid,cap_setpcap,cap_net_bind_service
    ~~~
    This are the default capabilities in CRI-O 1.23 which matches the one shown previously
    ~~~
    default_capabilities = [
	"CHOWN",
	"DAC_OVERRIDE",
	"FSETID",
	"FOWNER",
	"SETGID",
	"SETUID",
	"SETPCAP",
	"NET_BIND_SERVICE",
	"KILL",
    ]
    ~~~~
        
5. Now, let's run the same application pod but with a nonroot UID:

    ~~~sh
    cat <<EOF | kubectl -n ${NAMESPACE} create -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: reversewords-app-captest-nonroot
    spec:
      containers:
      - image: quay.io/mavazque/reversewords:ubi8
        name: reversewords
        securityContext:
          runAsUser: 1024
      dnsPolicy: ClusterFirst
      restartPolicy: Never
    status: {}
    EOF
    ~~~
6. If we review the thread capability sets this is what we get:

    ~~~sh
    kubectl -n ${NAMESPACE} exec -ti reversewords-app-captest-nonroot -- grep Cap /proc/1/status
    CapInh:	00000000000005fb
    CapPrm:	0000000000000000
    CapEff:	0000000000000000
    CapBnd:	00000000000005fb
    CapAmb:	0000000000000000
    ~~~
7. The permitted and effective sets got cleared, if you remember this is expected. The problem on Kube is that it doesn't support ambient capabilities, as you can see the ambient set is cleared. That leaves us only with two options: File caps or caps aware apps.

## Demo 2 - Application with NET_BIND_SERVICE

1. In this first deployment we are going to run our app with root uid and drop every runtime capability but NET_BIND_SERVICE.

    ~~~sh
    cat <<EOF | kubectl -n ${NAMESPACE} create -f -
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      creationTimestamp: null
      labels:
        app: reversewords-app-rootuid
      name: reversewords-app-rootuid
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: reversewords-app-rootuid
      strategy: {}
      template:
        metadata:
          creationTimestamp: null
          labels:
            app: reversewords-app-rootuid
        spec:
          containers:
          - image: quay.io/mavazque/reversewords:ubi8
            name: reversewords
            resources: {}
            env:
            - name: APP_PORT
              value: "80"
            securityContext:
              runAsUser: 0
              capabilities:
                drop:
                - all
                add:
                - NET_BIND_SERVICE
    status: {}
    EOF
    ~~~
2. If we get the application logs we can see that it started properlly:

    ~~~sh
    kubectl -n ${NAMESPACE} logs deployment/reversewords-app-rootuid
    2022/07/06 15:14:51 Starting Reverse Api v0.0.21 Release: NotSet
    2022/07/06 15:14:51 Listening on port 80
    ~~~
3. If we look at the capability sets this is what we get:

    ~~~sh
    kubectl -n ${NAMESPACE} exec -ti deployment/reversewords-app-rootuid -- grep Cap /proc/1/status
    CapInh:	0000000000000400
    CapPrm:	0000000000000400
    CapEff:	0000000000000400
    CapBnd:	0000000000000400
    CapAmb:	0000000000000000
    ~~~
4. We have the NET_BIND_SERVICE available in the effective and permitted so it worked as expected. 
5. Now, we are dropping all of the runtime’s default capabilities, on top of that we add the NET_BIND_SERVICE capability and request the app to run with **non-root UID**. In the environment variables we configure our app to listen on port 80.

    ~~~sh
    cat <<EOF | kubectl -n ${NAMESPACE} create -f -
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      creationTimestamp: null
      labels:
        app: reversewords-app-nonrootuid
      name: reversewords-app-nonrootuid
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: reversewords-app-nonrootuid
      strategy: {}
      template:
        metadata:
          creationTimestamp: null
          labels:
            app: reversewords-app-nonrootuid
        spec:
          containers:
          - image: quay.io/mavazque/reversewords:ubi8
            name: reversewords
            resources: {}
            env:
            - name: APP_PORT
              value: "80"
            securityContext:
              runAsUser: 1024
              capabilities:
                drop:
                - all
                add:
                - NET_BIND_SERVICE
    status: {}
    EOF
    ~~~
6. Let's check the logs:

    ~~~sh
    kubectl -n ${NAMESPACE} logs deployment/reversewords-app-nonrootuid
    ~~~
7. The application failed to bind to port 80, let's update the confiuration so we can access the pod an check the capability sets:

    ~~~sh
    # Patch the app so it binds to port 8080
    kubectl -n ${NAMESPACE} patch deployment reversewords-app-nonrootuid -p '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"reversewords"}],"containers":[{"$setElementOrder/env":[{"name":"APP_PORT"}],"env":[{"name":"APP_PORT","value":"8080"}],"name":"reversewords"}]}}}}'
    # Get capability sets
    kubectl -n ${NAMESPACE} exec -ti deployment/reversewords-app-nonrootuid -- grep Cap /proc/1/status
    ~~~
8. We don't have the NET_BIND_SERVICE in the `effective` and `permitted` set, that means that in order for this to work we will need the capability to be in the ambient set, but this is not supported yet on Kubernetes, we will need to make us of file capabilities.
9. We have an image with the file capabilities configured, let's update the deployment to use port 80 and this new image:

    ~~~sh
    kubectl -n ${NAMESPACE} patch deployment reversewords-app-nonrootuid -p '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"reversewords"}],"containers":[{"$setElementOrder/env":[{"name":"APP_PORT"}],"env":[{"name":"APP_PORT","value":"80"}],"image":"quay.io/mavazque/reversewords-captest:latest","name":"reversewords"}]}}}}'
    ~~~
10. Let's check the logs for the app:

    ~~~sh
    kubectl -n ${NAMESPACE} logs deployment/reversewords-app-nonrootuid
    ~~~
11. If we check the capabilities now this is what we get:

    ~~~sh
    kubectl -n ${NAMESPACE} exec -ti deployment/reversewords-app-nonrootuid -- grep Cap /proc/1/status
    ~~~
12. We can check the file capabilities configured in our binary as well:

    ~~~sh
    kubectl -n ${NAMESPACE} exec -ti deployment/reversewords-app-nonrootuid -- getcap /usr/bin/reverse-words
    ~~~
