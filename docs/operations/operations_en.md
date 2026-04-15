# Running LOP-IdP

The `lop-idp` component (Low Ops Platform - Identity Provider) is a composite component that bundles the installation of core LOP components within a Cloudogu EcoSystem multi-node instance.

It replaces the Dogu variants of Dogu CAS, LDAP, LDAP Mapper, and User Management by offering centrally located Kubernetes components instead. This offers significant advantages in terms of rights management between Dogus and/or components.

This document describes common scenarios for installing the `lop-idp` component. All of the following scenarios share the prerequisite that a certain basic installation must already have been completed. That is, before the `lop-idp` component can be installed, the following components and CRDs must be installed and operational:

- Dogu Operator `k8s-dogu-operator` including the associated CRDs
- Component Operator `k8s-component-operator` including the associated CRDs
- Auth-Registration-CRD `k8s-auth-registration-lib`

The `k8s-auth-registration-operator` itself is deployed together with `lop-idp` as a sub-chart. Only the corresponding CRD must be installed separately in advance.

https://github.com/cloudogu/ecosystem-core/blob/develop/docs/operations/configuration_de.md#komponenten-components

All references to values in the `values.yaml` file refer to populating the `spec.valuesYamlOverwrite` field in the component CR with the corresponding changes, for example:

```yaml
apiVersion: k8s.cloudogu.com/v1
kind: Component
metadata:
  name: lop-idp
  #...
spec:
  #...
  valuesYamlOverwrite: |
    lop-idp:
      external-ldap:
        disabled: false
  # ...
```

The specified values are then passed on to the Helm library via the component operator.

You can find further information about configurable Values in the following repositories:
- [LDAP `values.yaml`](https://github.com/cloudogu/ldap/blob/develop/k8s/helm/values.yaml) - [explained](https://github.com/cloudogu/ldap/blob/develop/docs/operations/ldap_component_installation_en.md#4-configuration-valuesyaml-overview)
- [LDAP-Mapper `values.yaml`](https://github.com/cloudogu/ldap-mapper/blob/develop/k8s/helm/values.yaml) - [explained](https://github.com/cloudogu/ldap-mapper/blob/develop/docs/operations/ldap_mapper_component_installation_en.md#4-configuration-overview-valuesyaml)
- [CAS `values.yaml`](https://github.com/cloudogu/cas/blob/develop/k8s/helm/values.yaml)
- [User Management `values.yaml`](https://github.com/cloudogu/usermgt/blob/develop/k8s/helm/values.yaml)
- [Auth-Registration-Operator `values.yaml`](https://github.com/cloudogu/k8s-auth-registration-operator/blob/develop/k8s/helm/values.yaml) - [explained](https://github.com/cloudogu/k8s-auth-registration-operator/blob/develop/docs/operations/reference/operator_configuration_en.md#helm-values-k8shelmvaluesyaml)

## Installation

`lop-idp` must be installed as a component using the CES component operator.
To do this, a corresponding custom resource (CR) must be created for the component.

```yaml
apiVersion: k8s.cloudogu.com/v1
kind: Component
metadata:
  name: lop-idp
  labels:
    app: ces
spec:
  name: lop-idp
  namespace: k8s
  version: 0.1.0
```

The new YAML file can then be created in the Kubernetes cluster:

```shell
kubectl apply -f lop-idp.yaml --namespace ecosystem
```

The component operator will now create the `lop-idp` component in the `ecosystem` namespace.

## Upgrading the lop-idp Component

To upgrade, the desired version must be specified in the custom resource.
To do this, edit the created CR-YAML file (e.g., as shown below) and enter the desired version.
Then apply the edited YAML file to the cluster again:

```yaml
apiVersion: k8s.cloudogu.com/v1
kind: Component
metadata:
  name: lop-idp
  labels:
    app: ces
spec:
  name: lop-idp
  namespace: k8s
  version: 0.2.0 # it was 0.1.0 before; this is just an example because this Version does not exist (yet)
```

```shell
kubectl apply -f lop-idp.yaml --namespace ecosystem
```

It is necessary to use versions of the Dogu and Blueprint Operators that are already compatible with running Postfix
as a component and with Authentication CRs:
- k8s-dogu-Operator: v3.22.0+
- k8s-blueprint-Operator: v3.3.0+

## Configuration

### Internal LDAP (New Installation)

Everything should work out of the box

### External LDAP (New Installation)

Store LDAP access as a secret:
```shell
kubectl -n ecosystem create secret generic \
  external-ldap \
  --from-literal=username=cn=admin,dc=planetexpress,dc=com \
  --from-literal=password=GoodNewsEveryone
```

Then configure the `values.yaml` file for the external LDAP service:

```yaml
lop-idp:
  external-ldap:
    disabled: false # deaktivate here internal LDAP usage

cas:
  configuration:
    normal: # in config.yaml style
      ldap:
        base_dn: "ou=people,dc=planetexpress,dc=com"
        connection_dn: "cn=admin,dc=planetexpress,dc=com" # again, the LDAP-Bind username, identical with that in the secret
        ds_type: "external"
        attribute_id: "uid"
        attribute_group: "memberof"
        attribute_mail: "mail"
        search_filter: "(objectClass=inetOrgPerson)"
        attribute_fullname: "cn"
        encryption: "none"
        host: "192.168.56.1"
        port: "10389"
    secretRefs:
      ldapPassword:
        name: external-ldap # reference to the above generated secret 
        key: password
      ldapUsername:
        name: external-ldap
        key: username

ldap-mapper:
  configuration:
    backend:
      type: "external"
      host: "192.168.56.1" # IP address or FQDN to the external LDAP service
      port: "10389"        # and respective port
    mapping:
      user:
        base_dn: "ou=people,dc=planetexpress,dc=com"
        search_filter: "(objectclass=inetOrgPerson)"
        id: "uid"
        given_name: "givenName"
        surname: "sn"
        full_name: "cn"
        mail: "mail"
        group: "memberOf"
      group:
        base_dn: "ou=people,dc=planetexpress,dc=com"
        search_filter: "(objectclass=Group)"
        name: "cn"
        description: "description"
        member: "member"
  secretRefs:
    backendLdap:
      name: "external-ldap"  # reference to the above generated secret
      usernameKey: "username"
      passwordKey: "password"
#...
```

### Migration einer Bestandsinstanz



1. Delete these Dogus
   - cas `kubectl -n ecosystem delete dogu cas`
   - ldap-mapper `kubectl -n ecosystem delete dogu ldap-mapper`
   - postfix `kubectl -n ecosystem delete dogu postfix`
   - usermgt `kubectl -n ecosystem delete dogu usermgt`
2. Install the `postfix` component
   ```shell
   cat <<EOF | kubectl -n ecosystem apply -f -  
   apiVersion: k8s.cloudogu.com/v1
   kind: Component
   metadata:
     name: postfix
     app: ces
   spec:
     name: postfix
     namespace: k8s
     version: 3.10.8-2 # or newer
     valuesYamlOverwrite: |
       configuration:
         normal:
           relayHost: your.mail.relay.host.here
   EOF
   ```
3. Prepare for the LDAP migration
   1. Deploy the Authentication CRD (version 0.1.1 here) if you haven't already
   ```shell
   cat <<EOF | kubectl -n ecosystem apply -f -  
   apiVersion: k8s.cloudogu.com/v1
   kind: Component
   metadata:
     name: k8s-auth-registration-crd
     app: ces
   spec:
     name: k8s-auth-registration-crd
     namespace: k8s
     version: 0.1.1
   EOF
   ```
   2. Deploy the Dogu Operator, if you haven't already
4. Configure the `lop-idp` component's `values.yaml` for an LDAP migration
   - The `ldap.migration.enabled` flag ensures data migration.
   - Dogu will then be automatically stopped. Dogu can be removed once the entire process is complete.
   ```yaml
   #...
   ldap:
     migration:
       enabled: true
   #...
   ```
5. Apply the `lop-idp` component to the cluster
   - Existing LDAP data is imported by the LDAP migration job
6. Check components and pods for any errors
7. Perform cleanup tasks
   - Set the relayhost in the `postfix-config` configmap to its previous value
   - Delete the ldap-Dogu


![A user with the "Administrator" role deletes the "User Management", "ldap-mapper", and CAS Dogus from outside the cluster, but not the "LDAP" Dogu. The user then installs the "lop-idp" component. This creates the corresponding (sub)components for the deleted Dogus. In addition, the "lop-idp" component also creates an LDAP migration that stops the LDAP Dogu after the data migration. On the side are three necessary components: "Component Operator", "Dogu Operator", and "Auth Registration Operator" without arrows, so that viewers can focus on the "lop-idp" component](images/lop-idp-migration-process.drawio.png "Diagram of actions performed in an existing instance for an LDAP migration")
