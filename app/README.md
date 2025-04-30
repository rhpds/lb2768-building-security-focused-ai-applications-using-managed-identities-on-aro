# Application image

## Building

The npm build happens during the image build. To do it successfully, you may have to augment the limits on open files in your system. Ex:

`podman build --no-cache --ulimit nofile=10000:10000 -t rhoai-lab-insurance-claim-app:2.1.0 .`

mac

`podman build --platform linux/amd64 --no-cache --ulimit nofile=10000:10000 -t rhoai-lab-insurance-claim-app:2.1.0 .`

OCP

```
oc new-project build

oc new-build --name rhoai-lab-insurance-claim-app --binary
oc start-build rhoai-lab-insurance-claim-app --from-dir=.

# once finished...

IMAGE=$(oc get build rhoai-lab-insurance-claim-app-3 -o json | jq -r '.status.outputDockerImageReference')
DIGEST=$(oc get build rhoai-lab-insurance-claim-app-3 -o json | jq -r '.status.output.to.imageDigest')

# make registry visible
oc patch config.imageregistry.operator.openshift.io/cluster --patch='[{"op": "add", "path": "/spec/disableRedirect", "value": true}]' --type=json
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

HOST=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')

podman login -u admin -p $(oc whoami -t) $HOST

podman pull $HOST/build/rhoai-lab-insurance-claim-app@$DIGEST
podman tag $HOST/build/rhoai-lab-insurance-claim-app@$DIGEST ghcr.io/rh-mobb/rhoai-lab-insurance-claim-app:miwi
podman push ghcr.io/rh-mobb/rhoai-lab-insurance-claim-app:miwi

```