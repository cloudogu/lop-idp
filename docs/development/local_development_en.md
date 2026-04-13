# Local Development of LOP-IdP Components

This section describes the steps required to use `lop-idp` with development versions of subcomponents, such as LDAP, in the cluster. The key step is to set `Chart.yaml` to point to an available development version.

The procedure described here avoids OCI pushes to external registries, instead sourcing its changes from a local `lop-idp` and a local sub-Helm chart via file references in `Chart.yaml`:

1. In the sub-chart repositories: `make helm-generate helm-package`
   - This step generates chart versions with the current `ARTIFACT_ID` or `COMPONENT_ID` (as opposed to `0.0.0-replaceme`)
   - This facilitates component upgrades, as downgrades are generally prevented
2. In the `lop-idp` repo
   1. Adapt `Chart.yaml`
      - **Important:** Set `version` to zero for the major version of the respective components that make up the development part
         - e.g., CAS in repo version `7.2.3-1` is listed as `^7.0.0-0`
      - Redirect `repository` to the component to be tested using a file reference
   2. Pull the sub-charts, including the development part, into `lop-idp`: `make helm-update-dependencies`
      - The correct chart versions should now be in place
3. If necessary, delete all previous component parts (only during initial installation)
4. Apply LOP-IDP to the cluster: `make component-apply`

Example `Chart.yaml`:
```yaml
...
dependencies:
  - name: ldap
    version: "^2.0.0-0"
    repository: "file:///path/to/ecosystem/containers/ldap/target/k8s/helm/"
    condition: lop-idp.external-ldap.disabled
  - name: usermgt
    version: "^1.0.0-0"
    repository: "file:///path/to/ecosystem/containers/usermgt/target/k8s/helm/"
    condition: lop-idp.external-ldap.disabled
  - name: cas
    version: "^7.0.0-0"
    repository: "file:///path/to/ecosystem/containers/cas/target/k8s/helm/"
  - name: ldap-mapper
    version: "^1.0.0-0"
    repository: "file:///path/to/ecosystem/containers/ldap-mapper/target/k8s/helm/"
  - name: k8s-auth-registration-operator
    version: "^1.0.0-0"
    repository: "file:///path/to/k8s-auth-registration-operator/target/k8s/helm/"
...
```

## Tests

### External LDAP

Testing an external LDAP connection without the LDAP-Dogu component is relatively straightforward. All you need is an LDAP service with existing account and group data.

The Docker image [rroemhild/docker-test-openldap](https://github.com/rroemhild/docker-test-openldap) is useful here, as it already provides a useful data structure. In the following example with a local cluster via VirtualBox, an LDAP server is made available to the VMs via the VBox internal IP address `192.168.56.1`:

1. Start the LDAP server on the host outside the cluster
   - `docker run --rm -p 10389:10389 -p 10636:10636 ghcr.io/rroemhild/docker-test-openldap:master`
2. Create an LDAP secret (here: `external-ldap`)
```shell
kubectl -n ecosystem \
  create secret generic external-ldap \
  --from-literal=username=cn=admin,dc=planetexpress,dc=com \
  --from-literal=password=GoodNewsEveryone
```
3. Configure external LDAP in the CAS and ldap-mapper sections of the `values.yaml` file for the `lop-idp` component
```yaml
#...
cas:
  configuration:
    normal: # in config.yaml style
      ldap:
        base_dn: "ou=people,dc=planetexpress,dc=com"
        connection_dn: "cn=admin,dc=planetexpress,dc=com"
        ds_type: "external"
        attribute_id: "uid"
        attribute_group: "memberof"
        attribute_mail: "mail"
        search_filter: "(objectClass=inetOrgPerson)"
        attribute_fullname: "cn"
        encryption: "none"
        host: "192.168.56.1"
        port: "10389"
      logging:
        root: "ERROR"
    secretRefs:
      ldapPassword:
        name: external-ldap
        key: password
      ldapUsername:
        name: external-ldap
        key: username
ldap-mapper:
  configuration:
    backend:
      type: "external"
      host: "192.168.56.1"
      port: "10389"
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
      # Secret containing the read-only backend LDAP bind credentials for the mapper.
      name: "external-ldap"
      usernameKey: "username"
      passwordKey: "password"
```
4. Deploy the `lop-idp` component
   - `make component-apply`

Logins are possible once all components and pods are `ready`. Ensure that existing CAS sessions are properly logged out.
- Admin login with `hermes:hermes`
- Non-admin login with `fry:fry`

For more information on the LDAP structure used, see [rroemhild/docker-test-openldap](https://github.com/rroemhild/docker-test-openldap)
