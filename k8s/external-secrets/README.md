# external-secrets

## Enable Kubernetes auth for external secrets operator

    vault auth enable kubernetes
    vault write auth/kubernetes/config kubernetes_host=https://kubernetes.default.svc

    vault write auth/kubernetes/role/vault bound_service_account_names=vault bound_service_account_namespaces="*"
    policies=vault ttl=1h

    # don't forget to create policy
