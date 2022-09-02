#!/bin/bash

kubectl run test-ubi --image quay.io/mavazque/reversewords:ubi8
kubectl run test-fedora --image registry.fedoraproject.org/fedora:36
kubectl run test-cap --image quay.io/mavazque/reversewords-captest:latest
sleep 120
kubectl delete pod test-ubi
kubectl delete pod test-fedora
kubectl delete pod test-cap

# Deploy cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml
kubectl -n cert-manager wait --for condition=ready pod -l app.kubernetes.io/instance=cert-manager

# Deploy operator
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/security-profiles-operator/v0.4.3/deploy/operator.yaml
kubectl -n security-profiles-operator wait --for condition=ready pod -l name=security-profiles-operator
kubectl -n security-profiles-operator wait --for condition=ready pod -l name=spod
kubectl -n security-profiles-operator patch spod spod --type=merge -p '{"spec":{"enableLogEnricher":true}}'
kubectl -n security-profiles-operator wait --for condition=ready pod -l name=spod

