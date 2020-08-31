//
// Copyright 2020 IBM Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// IBMLicensingSpec defines the desired state of IBMLicensing
type IBMLicenseServiceSpec struct {
	// Container Settings
	Container `json:",inline"`
	// Common Parameters for Operator
	IBMLicenseServiceBaseSpec `json:",inline"`
	// Where should data be collected, options: metering, datacollector
	// +kubebuilder:validation:Enum=metering;datacollector
	Datasource string `json:"datasource"`
	// Enables https access at pod level, httpsCertsSource needed if true
	HTTPSEnable bool `json:"httpsEnable"`
	// If default SCC user ID fails, you can set runAsUser option to fix that
	SecurityContext *IBMLicensingSecurityContext `json:"securityContext,omitempty"`
	// Should Route be created to expose IBM Licensing Service API? (only on OpenShift cluster)
	RouteEnabled *bool `json:"routeEnabled,omitempty"`
	// Should Ingress be created to expose IBM Licensing Service API?
	IngressEnabled *bool `json:"ingressEnabled,omitempty"`
	// If ingress is enabled, you can set its parameters
	IngressOptions *IBMLicensingIngressOptions `json:"ingressOptions,omitempty"`
	// Sender configuration, set if you have multi-cluster environment from which you collect data
	Sender *IBMLicensingSenderSpec `json:"sender,omitempty"`
}

// IBMLicensingStatus defines the observed state of IBMLicensing
type IBMLicenseServiceStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "operator-sdk generate k8s" to regenerate code after modifying this file
	// Add custom validation using kubebuilder tags: https://book-v1.book.kubebuilder.io/beyond_basics/generating_crd.html

	// LicensingPods are the names of the licensing pods
	LicensingPods []corev1.PodStatus `json:"licensingPods"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// IBMLicensing is the Schema for the ibmlicenseservice API
// +kubebuilder:printcolumn:name="Pod Phase",type=string,JSONPath=`.status..phase`
// +kubebuilder:subresource:status
// +kubebuilder:resource:path=ibmlicenseservice,scope=Namespaced
type IBMLicenseService struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   IBMLicenseServiceSpec   `json:"spec,omitempty"`
	Status IBMLicenseServiceStatus `json:"status,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// IBMLicensingList contains a list of IBMLicensing
type IBMLicenseServiceList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []IBMLicenseService `json:"items"`
}

func init() {
	SchemeBuilder.Register(&IBMLicenseService{}, &IBMLicenseServiceList{})
}
