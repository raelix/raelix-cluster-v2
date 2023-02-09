# raelix-cluster-v2
[![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen.svg)](https://renovatebot.com)

## Overview
This repo is modified using coder on my Kubernetes cluster. 
Almost all components (WIP) are authenticated using KeyCloak (locally) and Auth0 (remote) using OID Connect to allow the SSO (single sign-on).

### Requirements
- sops
- pre-commit
- flux (cli)
- kubectl

### Optional
- task
- helm

### Portal overview
![Drag Racing](doc/img/portal.png)

### Main installed components
- cert-manager - used to generate the certificate with let's encrypt using dns01 challenge
- local-path-provisioner - dynamic local volume provisioner
- volsync - sync volumes content to my google drive :) 
- external-snapshotter - required but not used by volsync
- external-dns - configure the DNS records to my pi-hole instance running on a Raspberry-pi
- Keycloak - indentity and access management solution
- oauth2-proxy - redirect unauthenticated users to the identity provider
- cloudnative-pg - postgres operator
- redis - in memory key/value data store
- weave-dashboard - useful flux dashboard
- coder - creating and managing developer workspaces
- paperless - documents management tool with OCR integration 
- homer - portal to have a single place to access every service
- home-assistant - home automation and appliance management
- zigbee2mqtt (2 instances - 2 coordinators)
- nodered (currently disabled) - automation flows
- emqx-operator - broker mqtt
- ring-mqtt - Software to interact with Ring devices through MQTT

## Installation guide

### Deploy the secret containing the private-key
You must have the age.agekey used previously to encrypt the contained secrets

```shell
cat age.agekey |
kubectl create secret generic sops-age \
--namespace=flux-system \
--from-file=age.agekey=/dev/stdin
```
> N.B.: the flux-system may not be already present in that case create it with ```kubectl create ns flux-system```

### Bootstrap
Use this command to initialize and bootstrap flux. Use this command as well to run the flux upgrade
```shell
flux bootstrap github \
--owner=raelix \
--repository=raelix-cluster-v2  \
--branch=main  \
--path=clusters/production \
--personal
```
> N.B.: Before running this command to upgrade the flux components remember to upgrade the flux cli
### Restore the cluster
- In order to restore the cluster you just need to apply the main flux resource. The main folder is ```cluster/production/flux-system```. You can use kustomize to render the manifest and apply them on the cluster.
- Another option is to use the bootstrap command to initialize again the cluster from the repository (suggested option).

## Developer guide
This developer guide is useful to remember the important steps. It is still WIP and there are a lot of installed components that are not tracked here yet.

### Secret encryption
Generate the age pub and private key (only the first time).
```shell
age-keygen -o age.agekey
```

#### Create the secret
Create the secret that will be use by the kustomize controller

```shell
cat age.agekey |
kubectl create secret generic sops-age \
--namespace=flux-system \
--from-file=age.agekey=/dev/stdin
```

#### Add the decryption section to the kustomize controllers
```
add the decryption section to the kustomize controllers so flux will take care of decrypting the secrets

  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

#### Encryption rules
The encryption rule is defined in the root directory of the project in a file called ```.sops.yaml``` which contains the rules and the age public key to use for the encryption:
```
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    age: age1elje5gj3cyqhn44m66xlngczm8dklwmry9803ne69945e256xgequ9xtt6
```
#### Encrypt a secret
To encrypt a secret just run the ```encrypt_me.sh``` passing as first argument the secret yaml file. The script just runs the ```sops -e $1 | tee $1.encrypted``` command which uses the previous defined rule.

### Apps details
This section contains the main part related to the application deployment. WIP

#### Cert-manager
The cert-manager is used to create a wildcard certificate for all the sub-domains with ```*.raelix.com``` in order to use it on all the ingresses without copying it on every namespace add the following argument to the ```nginx-ingress-controller```:
```
- --default-ssl-certificate=cert-manager/wildcard-cert
```
Where ```cert-manager``` is the namespace and ```wildcard-cert``` is the secret name.

#### Ring-mqtt

Ring-mqtt is deployed with the common chart (thanks for this great library). This specific image requires the ```config.json``` file to placed ```/data/config.json``` which should contains the following configuration:
```json
{
  "mqtt_url": "mqtt://username:password@emqx-listeners.message.svc.cluster.local:1883",
  "mqtt_options": "",
  "livestream_user": "",
  "livestream_pass": "",
  "disarm_code": "1234",
  "enable_cameras": true,
  "enable_modes": false,
  "enable_panic": true,
  "branch": "addon",
  "debug": "ring-*",
  "location_ids": [
    ""
  ]
}
```
This json is then created with the ```ring-mqtt-options.yaml``` secret mounted in the right folder.

#### EMQX
EMQX is deployed through the operator hence a new CR must be created in order to spawn the cluster. Unfortunately the dashboard user and the mqtt user can't be created easly hence a sidecar is used to do that using the REST API

##### Users secret
The expected secret to create the users is something like:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mqtt-users
  namespace: default
data:
  users.json: BASE64ENCODED_BELOW_JSON
```

This can be generated with the kubectl command:
```shell
kubectl create secret generic secret-name --from-file=./user.json --dry-run=client -o yaml
```

Where the user.json is like:
```json
// this is just an example
{
  "user_id": "user",
  "password": "password",
  "is_superuser": true
}
```
The secret is then encrypted using the ```encrypt_me.sh``` script.

##### Dashboard secret
The expected secret to create define the dashboard user and password is something like:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dashboard-auth
type: Opaque
data:
  EMQX_DASHBOARD__DEFAULT_USERNAME: BASE64ENCODED_USERNAME
  EMQX_DASHBOARD__DEFAULT_PASSWORD: BASE64ENCODED_PASSWORD
```
The secret is then encrypted using the ```encrypt_me.sh``` script.
