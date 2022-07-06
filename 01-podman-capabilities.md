# Capabilities on Containers demos

## Demo 1 - Run a container and get its thread capabilities

1. Let’s run a test container, this container has an application that listens on a given port, but that’s not important for now:

    ~~~sh
    podman run -d --rm --name reversewords-test quay.io/mavazque/reversewords:latest
    ~~~
2. We can always get capabilities for a process by querying the /proc filesystem:

    ~~~sh
    # Get container's PID
    CONTAINER_PID=$(podman inspect reversewords-test --format {{.State.Pid}})
    # Get caps for a given PID
    grep Cap /proc/${CONTAINER_PID}/status
    ~~~
3. We get the capability sets in hex format, we can decode them using `capsh` tool:

    ~~~sh
    capsh --decode=00000000800405fb
    ~~~
4. We can use podman inspect as well:

    ~~~sh
    podman inspect reversewords-test --format {{.EffectiveCaps}}
    ~~~
5. Stop the container:

    ~~~sh
    podman stop reversewords-test
    ~~~

## Demo 2 - Container running with UID 0 vs container running with nonroot UID

1. Run our test container with a root uid and get it’s capabilities:

    ~~~sh
    podman run --rm -it --user 0 --entrypoint /bin/bash --name reversewords-test quay.io/mavazque/reversewords:ubi8
    grep Cap /proc/1/status
    ~~~
2. We can see thread's permitted, effective and bound capability sets populated:

    ```sh
    CapInh:	0000000000000000
    CapPrm:	00000000800405fb
    CapEff:	00000000800405fb
    CapBnd:	00000000800405fb
    CapAmb:	0000000000000000
    ```
   let's decode them:

    ~~~sh
    capsh --decode=00000000800405fb
    ~~~
3. Exit the container:

    ~~~sh
    exit
    ~~~
4. Same test but running the container with a nonroot UID:

    ~~~sh
    podman run --rm -it --user 1024 --entrypoint /bin/bash --name reversewords-test quay.io/mavazque/reversewords:ubi8 
    grep Cap /proc/1/status
    ~~~
5. We can see thread's permitted and effective capability sets cleared, we can exit our container now:

    ~~~sh
    exit
    ~~~
6. We can requests extra capabilities and those will be assigned to the corresponding sets:

    ~~~sh
    podman run --rm -it --user 1024 --cap-add=cap_net_bind_service --entrypoint /bin/bash --name reversewords-test quay.io/mavazque/reversewords:ubi8
    grep Cap /proc/1/status
    ~~~
7. Since Podman supports ambient capabilities, you can see how we got the NET_BIND_SERVICE cap into the ambient, permitted and effective sets.
8. We can exit the container now:

    ~~~sh
    exit
    ~~~

## Demo 3 - Real world scenario

### Using thread capabilities

1. We can control in which port our application listens by using the APP_PORT environment variable. Let’s try to run our application in a non-privileged port with a non-privileged user:

    ~~~sh
    podman run --rm --user 1024 -e APP_PORT=8080 --name reversewords-test quay.io/mavazque/reversewords:ubi8
    ~~~
2. Stop the container with Ctrl+C and try to bind to port 80 this time:

    ~~~sh
    podman run --rm --user 1024 -e APP_PORT=80 --name reversewords-test quay.io/mavazque/reversewords:ubi8
    ~~~
3. This time it fails, remember that since we're running as nonroot, permitted and effective capability sets were cleared (so NET_BIND_SERVICE present on podman's default cap set is not available).
4. We know that the capability NET_BIND_SERVICE allows unprivileged processes to bind to ports under 1024, let’s assign this capability to the container and see what happens:

    ~~~sh
    podman run --rm --user 1024 -e APP_PORT=80 --cap-add=cap_net_bind_service --name reversewords-test quay.io/mavazque/reversewords:ubi8
    ~~~
5. This time it worked because the NET_BIND_SERVICE cap was added to the ambient, permitted and effective sets.
6. You can stop the container using Ctrl+C.

### Using file capabilities

1. We added the NET_BIND_SERVICE capability to our binary when we built the image:

    ~~~sh
    setcap 'cap_net_bind_service+ep' /usr/bin/reverse-words
    ~~~
2. Let's take a look inside the container:

    ~~~sh
    podman run --rm -it --entrypoint /bin/bash --user 1024 -e APP_PORT=80 --name reversewords-test quay.io/mavazque/reversewords-captest:latest
    getcap /usr/bin/reverse-words
    ~~~
3. The capability is added to the effective and permitted file capability sets.
4. Let's review the thread capabilities:

    ~~~sh
    grep Cap /proc/1/status 
    ~~~
5. As you can see, the effective and permitted sets are cleared. But the inheritable and bounding do have the NET_BIND_SERVICE.
6. Let's run our app:

    ~~~sh
    /usr/bin/reverse-words &
    ~~~
7. We were able to bind to port 80, the binary had the file capability required to do that and it was present on the inheritable and bounding sets, to the thread adquired the capability on its effective set. We can check the effective and permitted sets:

    ~~~sh
    grep Cap /proc/<app_pid>/status
    ~~~
9. We can exit the container now.

    ~~~sh
    exit
    ~~~
9. Does this mean that we can bypass thread capabilities? - Let's see:

    ~~~sh
    podman run --rm -it --entrypoint /bin/bash --user 1024 --cap-drop=all -e APP_PORT=80 --name reversewords-test quay.io/mavazque/reversewords-captest:latest
    ~~~
10. Check the cointainer thread capabilities:

    ~~~sh
    grep Cap /proc/1/status
    ~~~
11. All sets are zeroed, let's try to run our app:

    ~~~sh
    /usr/bin/reverse-words
    ~~~
12. The kernel blocked the execution, since NET_BIND_SERVICE capability cannot be acquired.
13. That answers the question, NO. Now we can exit the container:

    ~~~sh
    exit
    ~~~
