#!/bin/bash
kcli create kube generic -P masters=1 -P workers=1 -P master_memory=4096 -P numcpus=8 -P worker_memory=8192 -P sdn=calico -P version=1.24 -P engine=crio -P domain=cds22.lab secintrocluster


