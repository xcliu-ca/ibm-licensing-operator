# Troubleshooting

- [Verifying completeness of license usage data](#verifying-completeness-of-license-usage-data)
- [Preparing resources for offline installation without git](#preparing-resources-for-offline-installation-without-git)
- [License Service pods are crashing and License Service cannot run](#license-service-pods-are-crashing-and-license-service-cannot-run)

## Verifying completeness of license usage data

You can verify if License Service is properly deployed and whether it collects the complete license usage data. For more information, see [Verifying completeness of license usage data and troubleshooting](https://www.ibm.com/support/knowledgecenter/SSHKN6/license-service/1.x.x/monitoring.html).

## Preparing resources for offline installation without git

1\. Apply RBAC roles and CRD:

```bash
# apply the yaml from here:
export operator_release_version=v1.2.2-durham
kubectl apply -f https://github.com/IBM/ibm-licensing-operator/releases/download/${operator_release_version}/rbac_and_crd.yaml
```

2\. Make sure that the `my_docker_registry` variable is set to your private registry and apply the operator:

```bash
export my_docker_registry=<your private registry>
export operator_version=1.2.2
export operand_version=1.2.1
```

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ibm-licensing-operator
  labels:
    app.kubernetes.io/instance: "ibm-licensing-operator"
    app.kubernetes.io/managed-by: "ibm-licensing-operator"
    app.kubernetes.io/name: "ibm-licensing"
spec:
  replicas: 1
  selector:
    matchLabels:
      name: ibm-licensing-operator
  template:
    metadata:
      labels:
        name: ibm-licensing-operator
        app.kubernetes.io/instance: "ibm-licensing-operator"
        app.kubernetes.io/managed-by: "ibm-licensing-operator"
        app.kubernetes.io/name: "ibm-licensing"
      annotations:
        productName: IBM Cloud Platform Common Services
        productID: "068a62892a1e4db39641342e592daa25"
        productMetric: FREE
    spec:
      serviceAccountName: ibm-licensing-operator
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: beta.kubernetes.io/arch
                    operator: In
                    values:
                      - amd64
                      - ppc64le
                      - s390x
      hostIPC: false
      hostNetwork: false
      hostPID: false
      containers:
        - name: ibm-licensing-operator
          image: ${my_docker_registry}/ibm-licensing-operator:${operator_version}
          command:
            - ibm-licensing-operator
          imagePullPolicy: Always
          env:
            - name: WATCH_NAMESPACE
              value: ibm-common-services
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: OPERATOR_NAME
              value: "ibm-licensing-operator"
            - name: OPERAND_LICENSING_IMAGE
              value: "${my_docker_registry}/ibm-licensing:${operand_version}"
            - name: SA_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.serviceAccountName
          resources:
            limits:
              cpu: 20m
              memory: 150Mi
            requests:
              cpu: 10m
              memory: 50Mi
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop:
                - ALL
            privileged: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
EOF
```

## License Service pods are crashing and License Service cannot run

If your License Service pods are crashing and you see multiple instances of License Service with the CrashLoopBackOff status in your OpenShift console, you might have License Service deployed to more than one namespace. As a result, two License Service operators are running in two namespaces and the service crashes. The ibm-licensing-operator should only be deployed in the ibm-common-services namespace, however, if you deployed License Service more than once, the older version of License Service might be deployed to kube-system namespace.

Complete the following steps to fix the problem:

1\. To check whether the `ibm-licensing-operator` is deployed to `kube-system` namespace, run the following command:

    - **Linux** `kubectl get pod -n kube-system | grep ibm-licensing-operator`
    - **Windows** `kubectl get pod -n kube-system | findstr ibm-licensing-operator`

2\. If the response contains information about the running pod, uninstall License Service from `kube-system` namespace.

<b>Related links</b>
- [Go back to home page](../License_Service_main.md#documentation)
