#!/bin/bash

## This Script installs ICCA operator using default values. 
source script-functions.bash

status=$(oc whoami 2>&1)
if [[ $? -gt 0 ]]; then
    echoRed "Login to OpenShift to continue ICCA Operator installation."
        exit 1;
fi

displayStepHeader 1 "Create a new project"
oc create ns icca-operator


displayStepHeader 2 "Create a CatalogSource"

cat <<EOF>icca-CatalogSource.yaml 
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: icca-operator
  namespace: openshift-marketplace
spec:
  displayName: ''
  image: 'quay.io/vishwajitdandage/icca:index'
  publisher: ''
  sourceType: grpc
EOF

oc create -f icca-CatalogSource.yaml 

echoBlue "Waiting for CatalogSource to become ready"
sleep 60s

displayStepHeader 3 "Create an OperatorGroup object YAML file"
cat <<EOF>icca-og.yaml
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: icca-operator-group
  namespace: icca-operator
spec: 
  targetNamespaces:
  - icca-operator
EOF

displayStepHeader 4 "Create the OperatorGroup object"

oc create -f icca-og.yaml 
displayStepHeader 5 "Create a Subscription object YAML file to subscribe a Namespace"

cat <<EOF>icca-subscription.yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: icca-operator
  namespace: icca-operator
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: icca-operator
  source: icca-operator
  sourceNamespace: openshift-marketplace
  startingCSV: icca-operator.v0.0.1
EOF


displayStepHeader 6 "Create Subscription object"

oc create -f icca-subscription.yaml 


displayStepHeader 7 "Verify the Operator installation"
#There should be icca-operator.v0.0.1

check_for_csv_success=$(checkClusterServiceVersionSucceeded 2>&1)

if [[ "${check_for_csv_success}" == "Succeeded" ]]; then
	echoGreen "ICCA Operator installed"
else
    echoRed "ICCA Operator installation failed."
	exit 1;
fi


displayStepHeader 8 "Create the yaml for InstallCatalog instance."


cat <<EOF>installcatalog-sample.yaml
apiVersion: icca.com/v1alpha1
kind: InstallCatalog
metadata:
  name: installcatalog-sample
  namespace: icca-operator
spec:
  foo: bar
EOF

displayStepHeader 9 "Install the Deployment"

oc create -f installcatalog-sample.yaml

echoBlue "Waiting for InstallCatalog to become ready"

while [ "$(kubectl get pods -l=app=icca -n icca-operator -o jsonpath='{.items[*].status.phase}')" != "Running" ]; do
   sleep 5
   echo "Waiting for ICCA to be ready."
done

#Get the URLS
endpoint_url=http://$(oc get routes icca-ui -n icca-operator|awk 'NR==2 {print $2}')

displayStepHeader 10 "Get the Catalog URL"
echo "===========Catalog URL=============="
echoYellow $endpoint_url

