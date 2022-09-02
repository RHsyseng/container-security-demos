#!/bin/bash
kcli create kube generic -P masters=1 -P workers=1 -P master_memory=4096 -P numcpus=8 -P worker_memory=8192 -P sdn=calico -P version=1.24 -P ingress=true -P ingress_method=nginx -P engine=crio -P metallb=true -P domain=cds22.lab secintrocluster


