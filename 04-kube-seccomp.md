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

1. There are different ways to record the syscalls used by our workload. In our case we will use the logs recorder since it is the less intrusive in my opinion. Then, apply the recording profile to the application labeled as seccomp-lsl-test.
    
    ~~~sh
    cat <<EOF | kubectl -n ${NAMESPACE} create -f -
    apiVersion: security-profiles-operator.x-k8s.io/v1alpha1
    kind: ProfileRecording
    metadata:
      name: lsl
    spec:
      kind: SeccompProfile
      recorder: logs
      podSelector:
        matchLabels:
          app: seccomp-lsl-test
    EOF
    ~~~
    
3. Create the application that will be recorded.

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
    ~~~

4. Check the new seccomp profile is being recorded. Then delete the pod verify that the profile is created and distributed to all the nodes in the cluster.

    ~~~sh
    kubectl get profilerecording lsl -o jsonpath='{.status}' | jq
    ~~~
    ~~~sh
    {
      "activeWorkloads": [
      "seccomp-lsl-test"
     ]
    }
    ~~~
    
    ~~~sh
    kubectl delete pod seccomp-lsl-test 
    ~~~
    ~~~sh
    pod "seccomp-lsl-test" deleted
    ~~~
    ~~~sh
    kubectl get seccompprofile
    ~~~
    ~~~sh
    NAME                  STATUS      AGE
    ls                    Installed   23h
    lsl-seccomp-ls-test   Installed   2m6s
    ~~~
    ~~~sh
    kubectl describe seccompprofile lsl-seccomp-ls-test
    ~~~
    ~~~sh
    Events:
    Type    Reason                 Age    From             Message
    ----    ------                 ----   ----             -------
    Normal  SeccompProfileCreated  5m24s  profilerecorder  seccomp profile created
    Normal  SavedSeccompProfile    5m23s  profile          Successfully saved profile to disk on fx2-1b.cnf22.cloud.lab.eng.bos.redhat.com
    Normal  SavedSeccompProfile    5m23s  profile          Successfully saved profile to disk on fx2-3b.cnf22.cloud.lab.eng.bos.redhat.com
    Normal  SavedSeccompProfile    5m22s  profile          Successfully saved profile to disk on fx2-1c.cloud.lab.eng.bos.redhat.com
    Normal  SavedSeccompProfile    5m21s  profile          Successfully saved profile to disk on fx2-3c.cnf22.cloud.lab.eng.bos.redhat.com
    Normal  SavedSeccompProfile    5m19s  profile          Successfully saved profile to disk on fx2-3a.cnf22.cloud.lab.eng.bos.redhat.com
    Normal  SavedSeccompProfile    5m19s  profile          Successfully saved profile to disk on fx2-3d.cnf22.cloud.lab.eng.bos.redhat.com
    ~~~

5. You can check diferences between the profiles
    
    ~~~sh
    diff -y <(kubectl get seccompprofiles -o yaml lsl-seccomp-ls-test) <(kubectl get seccompprofiles -o yaml ls)
    ~~~

6. Finally apply the profile to the lsl pod again

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
          localhostProfile: operator/test-seccomp/lsl-seccomp-ls-test.json
      containers:
      - image: registry.fedoraproject.org/fedora:36
        name: seccomp-ls-test
        command: ["ls", "-l", "/"]
      dnsPolicy: ClusterFirst
      restartPolicy: Never
    status: {}
    EOF
    ~~~

    ~~~sh
    kubectl logs seccomp-ls-test 
    ~~~
    ~~~sh
    total 0
    dr-xr-xr-x.   2 root root   6 Jan 20 03:04 afs
    lrwxrwxrwx.   1 root root   7 Jan 20 03:04 bin -> usr/bin
    dr-xr-xr-x.   2 root root   6 Jan 20 03:04 boot
    drwxr-xr-x.   5 root root 360 Jul  8 10:24 dev
    drwxr-xr-x.   1 root root  25 Jul  8 10:24 etc
    drwxr-xr-x.   2 root root   6 Jan 20 03:04 home
    lrwxrwxrwx.   1 root root   7 Jan 20 03:04 lib -> usr/lib
    lrwxrwxrwx.   1 root root   9 Jan 20 03:04 lib64 -> usr/lib64
    drwx------.   2 root root   6 May  6 10:10 lost+found
    drwxr-xr-x.   2 root root   6 Jan 20 03:04 media
    drwxr-xr-x.   2 root root   6 Jan 20 03:04 mnt
    drwxr-xr-x.   2 root root   6 Jan 20 03:04 opt
    dr-xr-xr-x. 642 root root   0 Jul  8 10:24 proc
    dr-xr-x---.   2 root root 196 May  6 10:11 root
    drwxr-xr-x.   1 root root  42 Jul  8 10:24 run
    lrwxrwxrwx.   1 root root   8 Jan 20 03:04 sbin -> usr/sbin
    drwxr-xr-x.   2 root root   6 Jan 20 03:04 srv
    dr-xr-xr-x.  13 root root   0 Jul  8 09:24 sys
    drwxrwxrwt.   2 root root   6 May  6 10:10 tmp
    drwxr-xr-x.  12 root root 144 May  6 10:10 usr
    drwxr-xr-x.  18 root root 235 May  6 10:10 var
    ~~~

