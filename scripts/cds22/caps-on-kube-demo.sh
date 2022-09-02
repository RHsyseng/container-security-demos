#!/usr/bin/env bash

########################
# include the magic
########################
. ../demo-magic.sh


########################
# Configure the options
########################

#
# speed at which to simulate typing. bigger num = faster
#
TYPE_SPEED=50

# Cleanup previous demo
kubectl delete ns test-capabilities
#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# text color
# DEMO_CMD_COLOR=$BLACK

# hide the evidence
clear
PROMPT_TIMEOUT=0

pei "# We have a Kubernetes cluster running"
pei "kubectl get nodes"
pe "# DEMO 1: In this first demo we're going to compare a workload running with UID 0 vs non-root UID ⏎"
pei "# Let's start by creating a namespace and the workload"
pei "kubectl create ns test-capabilities"
pe "# Now let's create the workload ⏎"
TYPE_SPEED=100
pei "
cat <<EOF | kubectl -n test-capabilities create -f -
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
"
TYPE_SPEED=50
sleep 5
pe "# We can see the threads capability sets by exec'ing into the container ⏎"
pei "kubectl -n test-capabilities exec -ti reversewords-app-captest-root -- grep Cap /proc/1/status"
pe "# We can see the value of the capability sets, let's decode the effective set ⏎"
pei "capsh --decode=00000000000005fb"
pei "# Above capabilities match the default capabilities enabled in the CRI-O runtime by default"
pe "# As we did earlier with Podman, let's run the same workload with a nonroot UID and after that we will get the capability sets one more time ⏎"
TYPE_SPEED=100
pei "
cat <<EOF | kubectl -n test-capabilities create -f -
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
"
TYPE_SPEED=50
sleep 5
pei "kubectl -n test-capabilities exec -ti reversewords-app-captest-nonroot -- grep Cap /proc/1/status"
pe "# The permitted and effective sets got cleared, if you remember this is expected. The problem on Kube is that it doesn't support ambient capabilities, as you can see the ambient set is cleared. That leaves us only with two options: File caps or caps aware apps. ⏎"
clear
pe "# DEMO 2: In this second demo we are going to show the difference in a workload requiring NET_BIND_SERVICE when running as UID 0 vs nonroot UID ⏎"
pe "# Let's create the workload dropping all caps but NET_BIND_SERVICE and running with UID 0 ⏎"
TYPE_SPEED=100
pei "
cat <<EOF | kubectl -n test-capabilities create -f -
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
          value: \"80\"
        securityContext:
          runAsUser: 0
          capabilities:
            drop:
            - all
            add:
            - NET_BIND_SERVICE
status: {}
EOF
"
TYPE_SPEED=50
sleep 5
pe "# If we check the app logs we can see the app is running ⏎"
pei "kubectl -n test-capabilities logs deployment/reversewords-app-rootuid"
pe "# If we take a look at the capability sets, this is what we get ⏎"
pei "kubectl -n test-capabilities exec -ti deployment/reversewords-app-rootuid -- grep Cap /proc/1/status" 
pe "# We have the NET_BIND_SERVICE cap in the effective set, nice ⏎"
pe "# Now it's time to run the app as a nonroot uid, let's create the workload and check the logs ⏎"
TYPE_SPEED=100
pei "
cat <<EOF | kubectl -n test-capabilities create -f -
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
          value: \"80\"
        securityContext:
          runAsUser: 1024
          capabilities:
            drop:
            - all
            add:
            - NET_BIND_SERVICE
status: {}
EOF
"
TYPE_SPEED=50
sleep 5
pei "kubectl -n test-capabilities logs deployment/reversewords-app-nonrootuid"
pe "# It failed this time, that's because the workload didn't get the capabilities it needs to work, if we check the capability sets this is what we get ⏎"
pei "kubectl -n test-capabilities patch deployment reversewords-app-nonrootuid -p '{\"spec\":{\"template\":{\"spec\":{\"$setElementOrder/containers\":[{\"name\":\"reversewords\"}],\"containers\":[{\"$setElementOrder/env\":[{\"name\":\"APP_PORT\"}],\"env\":[{\"name\":\"APP_PORT\",\"value\":\"8080\"}],\"name\":\"reversewords\"}]}}}}'"
sleep 5
pei "kubectl -n test-capabilities exec -ti deployment/reversewords-app-nonrootuid -- grep Cap /proc/1/status"
pe "# We don't have the NET_BIND_SERVICE cap in the effective and permitted set, this mean we would require ambient caps for this to work. Since we don't have support for that in Kube yet, we need to use file caps which we will see in the next demo ⏎"
clear
pe "# DEMO 3: File capabilities ⏎"
pe "# In this demo we will patch the previous deployment to make use of an image with file capabilities configured for our binary ⏎"
pei "kubectl -n test-capabilities patch deployment reversewords-app-nonrootuid -p '{\"spec\":{\"template\":{\"spec\":{\"$setElementOrder/containers\":[{\"name\":\"reversewords\"}],\"containers\":[{\"$setElementOrder/env\":[{\"name\":\"APP_PORT\"}],\"env\":[{\"name\":\"APP_PORT\",\"value\":\"80\"}],\"image\":\"quay.io/mavazque/reversewords-captest:latest\",\"name\":\"reversewords\"}]}}}}'"
sleep 5
pe "# Now that the deployment is patched, let's check the logs ⏎"
pei "kubectl -n test-capabilities logs deployment/reversewords-app-nonrootuid"
pe "# If we check the capabilities again, this is what we get ⏎"
pei "kubectl -n test-capabilities exec -ti deployment/reversewords-app-nonrootuid -- grep Cap /proc/1/status"
pe "# Now we got the caps in the right sets, that's because file capabilities. We can see our binary enabled caps ⏎"
pei "kubectl -n test-capabilities exec -ti deployment/reversewords-app-nonrootuid -- getcap /usr/bin/reverse-words"
pei "# Demo finished!"
