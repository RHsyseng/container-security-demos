# Seccomp on Containers demos

## Demo 1 - Create your own seccomp profile

1. We will use the [OCI Hook project](https://github.com/containers/oci-seccomp-bpf-hook) in order to generate the seccomp profile for our app

    ~~~sh
    $ sudo dnf install oci-seccomp-bpf-hook.x86_64 oci-seccomp-bpf-hook-tests.x86_64
    ~~~
3. Create a container with the OCI Hook which runs our application:

    ~~~sh
    sudo podman run --rm --annotation io.containers.trace-syscall="of:/tmp/ls.json" fedora:36 ls / > /dev/null
    ~~~
3. The hook wrote the seccomp profile to /tmp/ls.json, let's review it

    ~~~sh
    jq < /tmp/ls.json
    ~~~
    
    ```json
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
          "dup3",
          "epoll_ctl",
          "epoll_pwait",
          "execve",
          "exit_group",
          "fchdir",
          "fcntl",
          "fstat",
          "fstatfs",
          "futex",
          "getdents64",
          "getpid",
          "getppid",
          "getrandom",
          "ioctl",
          "mmap",
          "mount",
          "mprotect",
          "munmap",
          "nanosleep",
          "newfstatat",
          "openat",
          "pipe2",
          "pivot_root",
          "prctl",
          "pread64",
          "prlimit64",
          "read",
          "rseq",
          "rt_sigreturn",
          "set_robust_list",
          "set_tid_address",
          "setgid",
          "setgroups",
          "sethostname",
          "setuid",
          "statfs",
          "statx",
          "tgkill",
          "umask",
          "umount2",
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
  
   ```
   
4. We can now run our app with this profile

    ~~~sh
    podman run --rm --security-opt seccomp=/tmp/ls.json fedora:36 ls /
    ~~~
5. What happens if we change the command?

    ~~~sh
    podman run --rm --security-opt seccomp=/tmp/ls.json fedora:36 ls -l /
    ~~~
    ~~~sh
    ls: /: Operation not permitted
    ~~~
6. The required syscalls are not allowed, so it fails. Let's use the hook to append the ones we're missing:

    ~~~sh
    sudo podman run --rm --annotation io.containers.trace-syscall="if:/tmp/ls.json;of:/tmp/lsl.json" fedora:36 ls -l / > /dev/null
    ~~~
7. We have an updated seccomp profile now, let's see the diferences between both:

    ~~~sh
    diff <(jq --sort-keys . /tmp/ls.json) <(jq --sort-keys . /tmp/lsl.json)
    ~~~
    As you can see new syscalls are required to list the attributes of the files
    ~~~sh
    63a64,76
    >     },
    >     {
    >       "action": "SCMP_ACT_ALLOW",
    >       "args": [],
    >       "comment": "",
    >       "excludes": {},
    >       "includes": {},
    >       "names": [
    >         "getxattr",
    >         "lgetxattr",
    >          "lseek",
    >         "readlink"
    >       ]
    ~~~

8. So, now we can use this new profile to run the app that lists the attributes of the root directory:

    ~~~sh
    podman run --rm --security-opt seccomp=/tmp/lsl.json fedora:36 ls -l /
    ~~~
    ~~~~sh
    total 8
    dr-xr-xr-x.   2 root   root      6 Jan 20 03:04 afs
    lrwxrwxrwx.   1 root   root      7 Jan 20 03:04 bin -> usr/bin
    dr-xr-xr-x.   2 root   root      6 Jan 20 03:04 boot
    drwxr-xr-x.   5 root   root    340 Jul  7 09:09 dev
    drwxr-xr-x.  44 root   root     25 Jul  7 09:09 etc
    drwxr-xr-x.   2 root   root      6 Jan 20 03:04 home
    lrwxrwxrwx.   1 root   root      7 Jan 20 03:04 lib -> usr/lib
    lrwxrwxrwx.   1 root   root      9 Jan 20 03:04 lib64 -> usr/lib64
    drwx------.   2 root   root      6 May  6 10:10 lost+found
    drwxr-xr-x.   2 root   root      6 Jan 20 03:04 media
    drwxr-xr-x.   2 root   root      6 Jan 20 03:04 mnt
    drwxr-xr-x.   2 root   root      6 Jan 20 03:04 opt
    dr-xr-xr-x. 546 nobody nobody    0 Jul  7 09:09 proc
    dr-xr-x---.   2 root   root   4096 May  6 10:11 root
    drwxr-xr-x.   3 root   root     42 Jul  7 09:09 run
    lrwxrwxrwx.   1 root   root      8 Jan 20 03:04 sbin -> usr/sbin
    drwxr-xr-x.   2 root   root      6 Jan 20 03:04 srv
    dr-xr-xr-x.  13 nobody nobody    0 Jun 16 12:47 sys
    drwxrwxrwt.   2 root   root      6 May  6 10:10 tmp
    drwxr-xr-x.  12 root   root    144 May  6 10:10 usr
    drwxr-xr-x.  18 root   root   4096 May  6 10:10 var
    ~~~
