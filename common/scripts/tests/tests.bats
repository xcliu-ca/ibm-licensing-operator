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

@test "Create namespace $namespace" {
  echo Create namespace $namespace >&3
  kubectl create namespace $namespace
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

  kubectl apply -f ./deploy/service_account.yaml -n $namespace
  [ "$?" -eq 0 ]

  sed -i "s/ibm-common-services/$namespace/g" ./deploy/role.yaml
  [ "$?" -eq 0 ]

  kubectl apply -f ./deploy/role.yaml
  [ "$?" -eq 0 ]

  sed -i "s/ibm-common-services/$namespace/g" ./deploy/role_binding.yaml
  [ "$?" -eq 0 ]

  kubectl apply -f ./deploy/role_binding.yaml
  [ "$?" -eq 0 ]
}

@test "Run Operator in backgroud" {
  operator-sdk run --watch-namespace $namespace --local > operator-sdk_logs.txt 2>&1 &
}

@test "List all POD in cluster" {
  results="$(kubectl get pods --all-namespaces | wc -l)"
  [ "$results" -gt 0 ]
}

@test "Wait 12s for checking pod in $namespace. List should be empty" {
  echo "Checking if License Service pod is deleted" >&3
  retries=4
  results="$(kubectl get pods -n $namespace | wc -l)"
  until [[ $retries == 0 || $results -eq "0" ]]; do
    results="$(kubectl get pods -n $namespace | wc -l)"
    retries=$((retries - 1))
    sleep 3
  done
  [ $results -eq "0" ]
}

@test "Load CR for LS" {
cat <<EOF | kubectl apply -f -
  apiVersion: operator.ibm.com/v1alpha1
  kind: IBMLicensing
  metadata:
    name: instance
  spec:
    apiSecretToken: ibm-licensing-token
    datasource: datacollector
    httpsEnable: true
    imageRegistry: hyc-cloud-private-integration-docker-local.artifactory.swg-devops.com/ibmcom
    instanceNamespace: $namespace
EOF
  [ "$?" -eq "0" ]
}

@test "Wait for instance to be running" {
  echo "Checking IBMLicensing instance status" >&3
  retries_start=80
  retries=$retries_start
  retries_wait=3
  until [[ $retries == 0 || $new_ibmlicensing_phase == "Running" || "$ibmlicensing_phase" == "Failed" ]]; do
    new_ibmlicensing_phase=$(kubectl get IBMLicensing instance -o jsonpath='{.status..phase}' 2>/dev/null || echo "Waiting for IBMLicensing pod to appear")
    if [[ $new_ibmlicensing_phase != "$ibmlicensing_phase" ]]; then
      ibmlicensing_phase=$new_ibmlicensing_phase
      echo "IBMLicensing Pod phase: $ibmlicensing_phase" >&3
    fi
    sleep $retries_wait
    retries=$((retries - 1))
  done
  kubectl get pods -n $namespace >&3
  echo "Waited $((retries_start*retries_wait-retries*retries_wait)) seconds" >&3
  [[ $new_ibmlicensing_phase == "Running" ]]
}

@test "Remove CR from IBMLicensing" {
  kubectl delete IBMLicensing --all
  [ $? -eq 0 ]
}

@test "Wait for pods to be deleted" {
  echo "Checking if License Service pod is deleted" >&3
  retries_start=80
  retries=$retries_start
  retries_wait=3
  results="$(kubectl get pods -n $namespace | grep ibm-licensing-service-instance | wc -l)"
  until [[ $retries == 0 || $results -eq "0" ]]; do
    results="$(kubectl get pods -n $namespace | grep ibm-licensing-service-instance | wc -l)"
    retries=$((retries - 1))
    sleep $retries_wait
  done
  echo "Waited $((retries_start*retries_wait-retries*retries_wait)) seconds" >&3
  [ $results -eq "0" ]
}

@test "Check if operator log does not contains error" {
  results="$(cat ./operator-sdk_logs.txt | grep "{\"level\":\"error\"" | wc -l)"
  [ $results -eq "0" ]
}
