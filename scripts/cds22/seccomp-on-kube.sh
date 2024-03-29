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
kubectl delete ns test-seccomp



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

pei "# DEMO 1: In this first demo we're going to load the seccomp profile we generated with Podman into our cluster. We have two options, manually copying the profile file to the nodes or use the Security Profile Operator. We will do the later."
pe "# We have the Security Protile Operator already deployed ⏎"
pei "kubectl -n security-profiles-operator get pods"
pei "# Next, let's create the namespace for the workload"
pei "kubectl create ns test-seccomp"
pe "# We can now create the profile and the operator will make it available to the nodes in the cluster ⏎"
TYPE_SPEED=100
pei "
cat <<EOF | kubectl -n test-seccomp create -f -
apiVersion: security-profiles-operator.x-k8s.io/v1beta1
kind: SeccompProfile
metadata:
  name: ls
spec:
  architectures:
  - SCMP_ARCH_X86_64
  - SCMP_ARCH_X86
  - SCMP_ARCH_X32
  defaultAction: SCMP_ACT_ERRNO
  syscalls:
  - action: SCMP_ACT_ALLOW
    names:
    - access
    - arch_prctl
    - brk
    - capget
    - capset
    - chdir
    - close
    - dup3
    - epoll_ctl
    - epoll_pwait
    - execve
    - exit_group
    - fchdir
    - fcntl
    - fstat
    - fstatfs
    - futex
    - getdents64
    - getpid
    - getppid
    - getrandom
    - ioctl
    - mmap
    - mount
    - mprotect
    - munmap
    - nanosleep
    - newfstatat
    - openat
    - pipe2
    - pivot_root
    - prctl
    - pread64
    - prlimit64
    - read
    - rseq
    - rt_sigreturn
    - set_robust_list
    - set_tid_address
    - setgid
    - setgroups
    - sethostname
    - setuid
    - statfs
    - statx
    - tgkill
    - umask
    - umount2
    - write
EOF
"
sleep 2
TYPE_SPEED=50
pe "# We can see the profile installed, at this point it will be available for us to use ⏎"
pei "kubectl -n test-seccomp get seccompprofile"
pei "# DEMO 2: In this demo we will show how the Security Profile Operator can be used to record a workload and produce a profile that can be consumed"
pe "# Let's create a ProfileRecording targetting workloads labeled with app=seccomp-lsl-recording ⏎"
pei "
cat <<EOF | kubectl -n test-seccomp create -f -
apiVersion: security-profiles-operator.x-k8s.io/v1alpha1
kind: ProfileRecording
metadata:
  name: lsl
spec:
  kind: SeccompProfile
  recorder: logs
  podSelector:
    matchLabels:
      app: seccomp-lsl-recording
EOF
"
pe "# We can create the workload now ⏎"
pei "
cat <<EOF | kubectl -n test-seccomp create -f -
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-lsl-recording
  labels:
    app: seccomp-lsl-recording
spec:
  containers:
  - image: registry.fedoraproject.org/fedora:36
    name: seccomp-ls-recording
    command: [\"ls\",\"-l\", \"/\"]
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}
EOF
"
pe "# We can now check the profile recording status ⏎"
pei "kubectl -n test-seccomp get profilerecording lsl -o jsonpath='{.status}' | jq"
pe "# We can delete the workload pod now ⏎"
pei "kubectl -n test-seccomp delete pod seccomp-lsl-recording"
pei "kubectl -n test-seccomp delete ProfileRecording lsl"
pe "# We should have a new profile installed ⏎"
pei "kubectl -n test-seccomp get seccompprofile"
pe "# Now that we have a profile for running ls -l, let's create the pod ⏎"
pei "
cat <<EOF | kubectl -n test-seccomp create -f -
apiVersion: v1
kind: Pod
metadata:
  name: seccomp-lsl-test-2
spec:
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: operator/test-seccomp/lsl-seccomp-ls-recording.json
  containers:
  - image: registry.fedoraproject.org/fedora:36
    name: seccomp-ls-test-2
    command: [\"ls\", \"-l\", \"/\"]
  dnsPolicy: ClusterFirst
  restartPolicy: Never
status: {}
EOF
"
pe "# If we check the logs we should have the ls -l output ⏎"
pei "kubectl -n test-seccomp logs seccomp-lsl-test-2"
pei "# Demo finished!"
