# Seccomp Profiles on Kubernetes demos

## Demo 1 - Running a workload with a custom seccomp profile

We have multiple ways to use a custom seccomp profile The most straightforward is basically copy the policy in json format to the default path (1.19+) under `/var/lib/kubelet/seccomp`. However, this is a tedious and error prone work in case we have a bunch of worker nodes. There are products such as OpenShift that can use what is called Machine Config Operator to make changes, create or modify files to a pool of workers in the base OS.

Another option is using the [Security Profile Operator](https://github.com/kubernetes-sigs/security-profiles-operator) which will help us by distributing and managing our custom SCCs among other things. Do not hesitate to check it out and take a look at the [documentation](https://github.com/kubernetes-sigs/security-profiles-operator/blob/main/installation-usage.md).

1. First deploy the Security Profile Operator (SPO). See the [installation section](https://github.com/kubernetes-sigs/security-profiles-operator/blob/main/installation-usage.md#install-operator) for more info.

    ~~~sh
    # kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/security-profiles-operator/main/deploy/operator.yaml
    ~~~
2. Create a namespace for our workload

    ~~~sh
    NAMESPACE=test-seccomp
    kubectl create ns ${NAMESPACE}
    ~~~
3. We are going to use the ls.json seccomp profile that we obtained using the [oci-seccomp-bpf-hook](https://github.com/containers/oci-seccomp-bpf-hook). The SPO comes with a CRD called `SeccompProfile` where custom seccomp profiles can be managed
    ~~~sh
    cat <<EOF | kubectl -n ${NAMESPACE} create -f -
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
    ~~~
   
3. We can configure seccomp profiles at pod or container level, this time we're going to configure it at pod level:

    ~~~sh
    cat <<EOF | kubectl -n ${NAMESPACE} create -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: seccomp-ls-test
    spec:
      securityContext:
        seccompProfile:
          type: Localhost
          localhostProfile: operator/test-seccomp/ls.json
      containers:
      - image: registry.fedoraproject.org/fedora:36
        name: seccomp-ls-test
        command: ["ls", "/"]
      dnsPolicy: ClusterFirst
      restartPolicy: Never
    status: {}
    EOF
    ~~~~
4. We can check pod logs:

    ~~~sh
    kubectl -n ${NAMESPACE} logs seccomp-ls-test
    ~~~
    
    ~~~sh
    afs
    bin
    boot
    dev
    etc
    home
    lib
    lib64
    lost+found
    media
    mnt
    opt
    proc
    root
    run
    sbin
    srv
    sys
    tmp
    usr
    var
    ~~~
5. Let's try to modify the container command, this time let's run 'ls -l /':

    ~~~sh
    cat <<EOF | kubectl -n ${NAMESPACE} create -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: seccomp-lsl-test
      labels:
        app: seccomp-lsl-test
    spec:
      securityContext:
        seccompProfile:
          type: Localhost
          localhostProfile: operator/test-seccomp/ls.json
      containers:
      - image: registry.fedoraproject.org/fedora:36
        name: seccomp-ls-test
        command: ["ls","-l", "/"]
      dnsPolicy: ClusterFirst
      restartPolicy: Never
    status: {}
    EOF
    ~~~~
6. This time the pod failed since the seccomp profile doesn't allow the required syscalls for `ls -l /` to run:

    ~~~sh
    kubectl -n ${NAMESPACE} logs seccomp-lsl-test
    ~~~ 
 
    ~~~sh
    ls: /: Operation not permitted
    ~~~
    
## Demo 2 - Creating custom seccomp profile

1. In order to create the recording using the same OCI hook we mentioned in previous demos with podman we need to include the hook in the crio configuration file as explained [here](https://github.com/kubernetes-sigs/security-profiles-operator/blob/main/installation-usage.md#hook-based-recording). 
> ⚠️ Unfortunately, containerd is not capable of running OCI hooks, yet. 
> ❗ You can create or copy the CRI-O configuration file manually or use for instance MCO if running OpenShift.

2. Apply the recording profile to the application labeled as seccomp-lsl-test

    ~~~sh
    cat <<EOF | kubectl -n ${NAMESPACE} create -f -
    apiVersion: security-profiles-operator.x-k8s.io/v1alpha1
    kind: ProfileRecording
    metadata:
      name: recording-reversewords
    spec:
      kind: SeccompProfile
      recorder: hook
      podSelector:
        matchLabels:
          app: seccomp-lsl-test
    EOF
    ~~~ 

3.

    ~~~sh
    cat <<EOF | kubectl -n ${NAMESPACE} create -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: seccomp-lsl-test
      labels:
        app: seccomp-lsl-test
    spec:
      containers:
      - image: registry.fedoraproject.org/fedora:36
        name: seccomp-ls-test
        command: ["ls","-l", "/"]
      dnsPolicy: ClusterFirst
      restartPolicy: Never
    status: {}
    EOF
    ~~~~

