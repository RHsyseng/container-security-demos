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
TYPE_SPEED=30

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

####
p "# Demo 1 - Run a container and get its thread capabilities"
#p "# Let’s run a test container, this container has an application that listens on a given port, but that’s not important for now"
podman rm -f reversewords-test -i
pe "podman run -d --rm --name reversewords-test quay.io/mavazque/reversewords:latest"

#p "We can always get capabilities for a process by querying the /proc filesystem:"

p "echo 'CONTAINER_PID=\$(podman inspect reversewords-test --format {{.State.Pid}})'"
pei "CONTAINER_PID=$(podman inspect reversewords-test --format {{.State.Pid}})"
pe "grep Cap /proc/${CONTAINER_PID}/status"

#p " We get the capability sets in hex format, we can decode them using `capsh` tool"
pe "capsh --decode=00000000800405fb"

#p "We can use podman inspect as well:"
pe "podman inspect reversewords-test --format {{.EffectiveCaps}}"
pe "podman stop reversewords-test"

clear
p "# Demo 2 - Container running with UID 0 vs container running with nonroot UID"

#p "Run our test container with a root uid and get it’s capabilities:"

pe "podman run --rm --user 0 --name reversewords-test quay.io/mavazque/reversewords:ubi8 grep Cap /proc/1/status"

#p "We can see thread's permitted, effective and bound capability sets populated:"

#p "let's decode them:"

pei "capsh --decode=00000000800405fb"
#pei "exit"

#p "Same test but running the container with a nonroot UID:"
pe "podman run --rm --user 1024 --name reversewords-test quay.io/mavazque/reversewords:ubi8 grep Cap /proc/1/status"

#p "We can see threads permitted and effective capability sets cleared, we can exit our container now:"

#p "# We can requests extra capabilities and those will be assigned to the corresponding sets:"
pe "podman run --rm --user 1024 --cap-add=cap_net_bind_service --name reversewords-test quay.io/mavazque/reversewords:ubi8 grep Cap /proc/1/status"

#p "# Since Podman supports ambient capabilities, you can see how we got the NET_BIND_SERVICE cap into the ambient, permitted and effective sets."
pe "capsh --decode=0000000000000400"
wait



clear
p "# Demo 3 - Real world scenario: Using thread capabilities"

#p "We can control in which port our application listens by using the APP_PORT environment variable. Let’s try to run our application in a non-privileged port with a non-privileged user"
pe "podman run --rm --user 1024 -e APP_PORT=8080 --name reversewords-test quay.io/mavazque/reversewords:ubi8"

#p "Stop the container with Ctrl+C and try to bind to port 80 this time:"
pe "podman run --rm --user 1024 -e APP_PORT=80 --name reversewords-test quay.io/mavazque/reversewords:ubi8"
#p "This time it fails, remember that since we re running as nonroot, permitted and effective capability sets were cleared (so NET_BIND_SERVICE present on podmans default cap set is not available)."


#p "We know that the capability NET_BIND_SERVICE allows unprivileged processes to bind to ports under 1024, let’s assign this capability to the container and see what happens:"
pe "podman run --rm --user 1024 -e APP_PORT=80 --cap-add=cap_net_bind_service --name reversewords-test quay.io/mavazque/reversewords:ubi8"



clear
p "# Demo 4  Using file capabilities with unprivileged user - We added the NET_BIND_SERVICE capability to our binary when we built the image"
#p "setcap 'cap_net_bind_service+ep' /usr/bin/reverse-words"

#p "Let's take a look inside the container:"
pe "podman run --rm -it --entrypoint /bin/bash --user 1024 -e APP_PORT=80 --name reversewords-test quay.io/mavazque/reversewords-captest:latest"
#pe "podman run --rm -it --user 1024 -e APP_PORT=80 --name reversewords-test quay.io/mavazque/reversewords-captest:latest getcap /usr/bin/reverse-words"

#p "The capability is added to the effective and permitted file capability sets."
#p "Let's review the thread capabilities:"
#pei "podman exec reversewords-test grep Cap /proc/1/status "
#p "As you can see, the effective and permitted sets are cleared. Only the bounding capability set has NET_BIND_SERVICE."
#p "Let's run our app:"
#pei "/usr/bin/reverse-words &"
#p "We were able to bind to port 80, the binary had the file capabilities (effective and permitted) required to do that and it was present on the bounding set. Then the thread acquired the capability on its effective and permitted sets. We can check the effective and permitted sets:"

#pei "grep Cap /proc/$!/status"
#pei "exit"
clear
p "# Does this mean that we can bypass thread capabilities? - Let's see:"
pe "podman run --rm -it --entrypoint /bin/bash --user 1024 --cap-drop=all -e APP_PORT=80 --name reversewords-test quay.io/mavazque/reversewords-captest:latest"

#p "Check the cointainer thread capabilities:"
#pe "grep Cap /proc/1/status"

#p "All sets are zeroed, let's try to run our app:"
#pei "/usr/bin/reverse-words"
#p "The kernel blocked the execution, since NET_BIND_SERVICE capability cannot be acquired since the capability requested was not in the bounding set."
