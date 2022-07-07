# Seccomp on Containers demos

## Demo 1 - Create your own seccomp profile

1. We will use the [OCI Hook project](https://github.com/containers/oci-seccomp-bpf-hook) in order to generate the seccomp profile for our app

    ~~~sh
    $ sudo dnf install oci-seccomp-bpf-hook.x86_64 oci-seccomp-bpf-hook-tests.x86_64
    ~~~
3. Create a container with the OCI Hook which runs our application:

    ~~~sh
    sudo podman run --rm --annotation io.containers.trace-syscall="of:/tmp/ls.json" fedora:32 ls / > /dev/null
    ~~~
3. The hook wrote the seccomp profile to /tmp/ls.json, let's review it

    ~~~sh
    jq < /tmp/ls.json
    ~~~
4. We can now run our app with this profile

    ~~~sh
    podman run --rm --security-opt seccomp=/tmp/ls.json fedora:32 ls /
    ~~~
5. What happens if we change the command?

    ~~~sh
    podman run --rm --security-opt seccomp=/tmp/ls.json fedora:32 ls -l /
    ~~~
6. The required syscalls are not allowed, so it fails. Let's use the hook to append the ones we're missing:

    ~~~sh
    sudo podman run --rm --annotation io.containers.trace-syscall="if:/tmp/ls.json;of:/tmp/lsl.json" fedora:32 ls -l / > /dev/null
    ~~~
7. We have an updated seccomp profile now, let's diff them:

    ~~~sh
    diff <(jq -S . /tmp/ls.json) <(jq -S . /tmp/lsl.json)
    ~~~
8. We can use this new profile to run our app:

    ~~~sh
    podman run --rm --security-opt seccomp=/tmp/lsl.json fedora:32 ls -l /
    ~~~
