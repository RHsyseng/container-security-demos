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
# Seccomp on Containers demos

p "Demo 5 - Create your own seccomp profile"

p "sudo dnf install oci-seccomp-bpf-hook.x86_64 oci-seccomp-bpf-hook-tests.x86_64"
cat /home/alosadag/Documents/CNF/cnf-git/demo-magic/cds22/oci-seccomp-bpf-hook.log

#p "Create a container with the OCI Hook which runs our application:"
sudo rm -f /tmp/ls*.json
clear
pe "sudo podman run --rm --annotation io.containers.trace-syscall="of:/tmp/ls.json" fedora:36 ls / > /dev/null"

# p"The hook wrote the seccomp profile to /tmp/ls.json, let's review it"
pe "jq < /tmp/ls.json"
   
# p "We can now run our app with this profile"
pe "podman run --rm --security-opt seccomp=/tmp/ls.json fedora:36 ls /"

# p "What happens if we change the command?"
pe "podman run --rm --security-opt seccomp=/tmp/ls.json fedora:36 ls -l /"
#p "Notice that the default action for the profile we have created is **SCMP_ACT_ERRNO**. That means: if the syscall is not explicitly allowed then it will be denied."

# p "The required syscalls to list the files and directories attributes are not allowed, so it fails. Let's use the hook to append the ones we're missing:"
pe "sudo podman run --rm --annotation io.containers.trace-syscall='if:/tmp/ls.json;of:/tmp/lsl.json' fedora:36 ls -l / > /dev/null"
pe "diff <(jq --sort-keys . /tmp/ls.json) <(jq --sort-keys . /tmp/lsl.json)"

# p "So, now we can use this new profile to run the app that lists the attributes of the root directory:"
pe "podman run --rm --security-opt seccomp=/tmp/lsl.json fedora:36 ls -l /"
