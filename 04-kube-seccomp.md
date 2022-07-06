# Seccomp Profiles on Kubernetes demos

## Demo 1 - Running a workload with a custom seccomp profile

1. Add below's seccomp profile in your kubernetes nodes under `/var/lib/kubelet/seccomp/centos8-ls.json`

    ~~~sh
    {
      "defaultAction": "SCMP_ACT_ERRNO",
      "architectures": [
        "SCMP_ARCH_X86_64"
      ],
      "syscalls": [
        {
          "names": [
            "access",
            "arch_prctl",
            "brk",
            "capget",
            "capset",
            "chdir",
            "close",
            "epoll_ctl",
            "epoll_pwait",
            "execve",
            "exit_group",
            "fchown",
            "fcntl",
            "fstat",
            "fstatfs",
            "futex",
            "getdents64",
            "getpid",
            "getppid",
            "ioctl",
            "mmap",
            "mprotect",
            "munmap",
            "nanosleep",
            "newfstatat",
            "openat",
            "prctl",
            "pread64",
            "prlimit64",
            "read",
            "rt_sigaction",
            "rt_sigprocmask",
            "rt_sigreturn",
            "sched_yield",
            "seccomp",
            "set_robust_list",
            "set_tid_address",
            "setgid",
            "setgroups",
            "setuid",
            "stat",
            "statfs",
            "tgkill",
            "write"
          ],
          "action": "SCMP_ACT_ALLOW",
          "args": [],
          "comment": "",
          "includes": {},
          "excludes": {}
        }
      ]
    }
    ~~~
2. Create a namespace for our workload

    ~~~sh
    NAMESPACE=test-seccomp
    kubectl create ns ${NAMESPACE}
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
          localhostProfile: centos8-ls.json
      containers:
      - image: registry.centos.org/centos:8
        name: seccomp-ls-test
        command: ["ls", "/"]
      dnsPolicy: ClusterFirst
      restartPolicy: Never
    status: {}
    EOF
    ~~~
4. We can check pod logs:

    ~~~sh
    kubectl -n ${NAMESPACE} logs seccomp-ls-test
    ~~~
5. Let's try to modify the container command, this time let's run 'ls -l /':

    ~~~sh
     cat <<EOF | kubectl -n ${NAMESPACE} create -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: seccomp-lsl-test
    spec:
      containers:
      - image: registry.centos.org/centos:8
        name: seccomp-lsl-test
        command: ["ls", "-l", "/"]
        securityContext:
          seccompProfile:
            type: Localhost
            localhostProfile: centos8-ls.json
      dnsPolicy: ClusterFirst
      restartPolicy: Never
    status: {}
    EOF
    ~~~
6. This time the pod failed since the seccomp profile doesn't allow the required syscalls for `ls -l /` to run:

    ~~~sh
    kubectl -n ${NAMESPACE} logs seccomp-lsl-test
    ~~~ 
