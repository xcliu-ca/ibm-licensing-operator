#!/usr/bin/env bats
#
# Copyright 2020 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http:#www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

setup_file() {
  echo "start tests in namespace ibm-common-services$SUFIX for LS" > k8s.txt
}


setup() {
  echo "  " >> k8s.txt
  echo "-----------------------------------------" >> k8s.txt
  echo "Start $BATS_TEST_NAME" >> k8s.txt
  echo "-----------------------------------------" >> k8s.txt
  echo "  " >> k8s.txt
}

teardown() {
  echo "  " >> k8s.txt
  echo "-----------------------------------------" >> k8s.txt
  echo "End $BATS_TEST_NAME" >> k8s.txt
  echo "-----------------------------------------" >> k8s.txt
  echo "  " >> k8s.txt
}

@test "Create namespace ibm-common-services$SUFIX" {
  echo Create namespace ibm-common-services$SUFIX >&3


  kubectl create namespace ibm-common-services$SUFIX
  [ "$?" -eq 0 ]

  kubectl get namespaces >> k8s.txt
  [ "$?" -eq 0 ]
}

@test "Build Operator" {
  make build
  [ "$?" -eq 0 ]
}

@test "Apply CRD and RBAC" {
  kubectl apply -f ./deploy/crds/operator.ibm.com_ibmlicenseservicereporters_crd.yaml
  [ "$?" -eq 0 ]

  kubectl apply -f ./deploy/crds/operator.ibm.com_ibmlicensings_crd.yaml
  [ "$?" -eq 0 ]

  kubectl apply -f ./deploy/service_account.yaml -n ibm-common-services$SUFIX
  [ "$?" -eq 0 ]

  sed "s/ibm-common-services/ibm-common-services$SUFIX/g" < ./deploy/role.yaml > ./deploy/role_ns.yaml
  [ "$?" -eq 0 ]

  kubectl apply -f ./deploy/role_ns.yaml
  [ "$?" -eq 0 ]

  sed "s/ibm-common-services/ibm-common-services$SUFIX/g" < ./deploy/role_binding.yaml > ./deploy/role_binding_ns.yaml
  [ "$?" -eq 0 ]

  kubectl apply -f ./deploy/role_binding_ns.yaml
  [ "$?" -eq 0 ]
}

@test "Run Operator in backgroud" {
  operator-sdk run --watch-namespace ibm-common-services$SUFIX --local > operator-sdk-ls_logs.txt 2>&1 &

  export OPERATOR_PID=$!
  [ "$OPERATOR_PID" -gt 0 ]

  echo $OPERATOR_PID > ./operator.pid
  [ "$?" -eq 0 ]
}

@test "List all POD in cluster" {
  kubectl get pods --all-namespaces &>> k8s.txt || true

  results="$(kubectl get pods --all-namespaces | wc -l)"
  [ "$results" -gt 0 ]
}

@test "Wait 12s for checking pod in ibm-common-services$SUFIX. List should be empty" {
  echo "Checking if License Service pod is deleted" >&3
  retries=4
  results="$(kubectl get pods -n ibm-common-services$SUFIX | wc -l)"
  until [[ $retries == 0 || $results -eq "0" ]]; do
    results="$(kubectl get pods -n ibm-common-services$SUFIX | wc -l)"
    retries=$((retries - 1))
    sleep 3
  done
  kubectl get pods -n ibm-common-services$SUFIX &>> k8s.txt ||true

  [ $results -eq "0" ]
}

@test "create secret for artifactory" {
   kubectl create secret generic my-registry-token -n ibm-common-services$SUFIX --from-file=.dockerconfigjson=./artifactory.yaml --type=kubernetes.io/dockerconfigjson
   [ $? -eq "0" ]

   kubectl get secrets -n ibm-common-services$SUFIX >> k8s.txt
   [ $? -eq "0" ]
}


@test "Load CR for LS" {
cat <<EOF | kubectl apply -f -
  apiVersion: operator.ibm.com/v1alpha1
  kind: IBMLicensing
  metadata:
    name: instance$SUFIX
  spec:
    apiSecretToken: ibm-licensing-token
    datasource: datacollector
    httpsEnable: true
    imageRegistry: hyc-cloud-private-integration-docker-local.artifactory.swg-devops.com/ibmcom
    imageTagPostfix: 1.3.0
    imagePullSecrets:
      - my-registry-token
    instanceNamespace: ibm-common-services$SUFIX
EOF
  [ "$?" -eq "0" ]

  kubectl get IBMLicensing >> k8s.txt
  [ "$?" -eq "0" ]

  kubectl describe IBMLicensing instance$SUFIX >> k8s.txt
  [ "$?" -eq "0" ]
}

@test "Wait for instance to be running" {
  echo "Checking IBMLicensing instance$SUFIX status" >&3
  retries_start=80
  retries=$retries_start
  retries_wait=3
  until [[ $retries == 0 || $new_ibmlicensing_phase == "Running" || "$ibmlicensing_phase" == "Failed" ]]; do
    new_ibmlicensing_phase=$(kubectl get IBMLicensing instance$SUFIX -o jsonpath='{.status..phase}' 2>/dev/null || echo "Waiting for IBMLicensing pod to appear")
    if [[ $new_ibmlicensing_phase != "$ibmlicensing_phase" ]]; then
      ibmlicensing_phase=$new_ibmlicensing_phase
      echo "IBMLicensing Pod phase: $ibmlicensing_phase" >&3
    fi
    sleep $retries_wait
    retries=$((retries - 1))
  done
  echo "Waited $((retries_start*retries_wait-retries*retries_wait)) seconds" >&3
  [[ $new_ibmlicensing_phase == "Running" ]]
}

@test "Wait for Pod to starts all containers" {
  retries_start=100
  retries=$retries_start
  retries_wait=3

  until [[ $retries == 0 || $number_of_line == "1" ]]; do
    number_of_line="$(kubectl get pods -n ibm-common-services$SUFIX |grep ibm-licensing-service-instance | grep 1/1 | wc -l)"
    sleep $retries_wait
    retries=$((retries - 1))
  done
  echo "Waited $((retries_start*retries_wait-retries*retries_wait)) seconds" >&3
  kubectl get pods -n ibm-common-services$SUFIX  &>> k8s.txt || true
  kubectl describe pods -n ibm-common-services$SUFIX &>> k8s.txt || true
  [[ $number_of_line == "1" ]]
}

@test "Check Services" {
  kubectl get services -n ibm-common-services$SUFIX &>> k8s.txt || true
  number_of_line="$(kubectl get services -n ibm-common-services$SUFIX |grep ibm-licensing-service-instance | wc -l)"
  [[ $number_of_line == "1" ]]
}

@test "Check Route" {
  routeExists="$(kubectl get deployment --all-namespaces|grep openshift-ingress-operator| wc -l)"
  routeCreated="$(kubectl get route -n ibm-common-services$SUFIX  |grep ibm-licensing-service-instance | wc -l)"
  if [[ $routeExists == "1" && $routeCreated == "1" ]]; then
    export status="ok"
  fi
  if [[ $routeExists == "0" ]]; then
    export status="ok"
  fi
  if [[ $routeExists == "1" ]]; then
    kubectl get route -n ibm-common-services$SUFIX &>> k8s.txt || true
  fi

  [[ $status == "ok" ]]
}

@test "Remove CR from IBMLicensing" {
  kubectl delete IBMLicensing instance$SUFIX
  [ $? -eq 0 ]

  kubectl get IBMLicensing >> k8s.txt
  [ "$?" -eq "0" ]
}

@test "Wait for pods to be deleted" {
  echo "Checking if License Service pod is deleted" >&3
  retries_start=80
  retries=$retries_start
  retries_wait=3
  results="$(kubectl get pods -n ibm-common-services$SUFIX | grep ibm-licensing-service-instance | wc -l)"
  until [[ $retries == 0 || $results -eq "0" ]]; do
    results="$(kubectl get pods -n ibm-common-services$SUFIX | grep ibm-licensing-service-instance | wc -l)"
    retries=$((retries - 1))
    sleep $retries_wait
  done
  kubectl get pods -n ibm-common-services$SUFIX &>> k8s.txt || true
  kubectl describe pods -n ibm-common-services$SUFIX &>> k8s.txt || true
  echo "Waited $((retries_start*retries_wait-retries*retries_wait)) seconds" >&3
  [ $results -eq "0" ]
}

@test "Check if operator log does not contains error" {
  results="$(cat ./operator-sdk_logs.txt | grep "{\"level\":\"error\"" | wc -l)"
  [ $results -eq "0" ]
}

@test "Delete namespace and CRD" {
  kubectl delete namespace ibm-common-services$SUFIX
  kubectl delete crd ibmlicensings.operator.ibm.com
  kubectl delete crd ibmlicenseservicereporters.operator.ibm.com

  [ $? -eq "0" ]
}

@test "Kill operator" {
  export OPERATOR_PID=`cat ./operator.pid`
  kill  $OPERATOR_PID
  [ $? -eq "0" ]
}

