# Local Development of LOP-IdP Components

Since the sub-components (ldap, cas, usermgt, ldap-mapper, k8s-auth-registration-operator) are not installed as standalone CES components but belong to the Helm release of LOP-IdP, they cannot be deployed with `make component-apply` from their own repos.
To test a sub-component in the context of LOP-IdP, LOP-IdP itself must be deployed with a local development version of that sub-component.

## Automated Dev Workflow (recommended)

### Setup

A `.env.template` file in the repo root serves as a template. Copy and adjust it once:

```bash
cp .env.template .env
```

In the `.env` file, enter the paths to the locally checked-out sub-components you want to develop. All others remain commented out:

```dotenv
NAMESPACE=ecosystem
STAGE=development

#export RUNTIME_ENV=remote
#export RUNTIME=k8s

DEV_DIR_ldap=../ecosystem/containers/ldap
#DEV_DIR_cas=../ecosystem/containers/cas
#DEV_DIR_usermgt=../ecosystem/containers/usermgt
#DEV_DIR_ldap_mapper=../ecosystem/containers/ldap-mapper
#DEV_DIR_k8s_auth_registration_operator=../k8s-auth-registration-operator
```

> **Note:** Component names with dashes become underscores in variable names  
> (e.g. `ldap-mapper` → `DEV_DIR_ldap_mapper`).

### Deployment

```bash
# Deploy via the Component Operator (standard)
make dev-component-apply

# Direct Helm deployment (faster iteration, no Component Operator)
make dev-component-helm-apply
```

All sub-components for which a `DEV_DIR_*` entry is set in `.env` are built and swapped into LOP-IdP.
All others remain at their release version.

### How it works internally

1. For each set `DEV_DIR_<name>` variable, `make helm-package image-import STAGE=development` is run inside the respective sub-component repo. This builds the dev chart and pushes the dev image to the local registry.
2. The chart dependencies of LOP-IdP are redirected to the locally built charts (via `file://` reference in `Chart.yaml`).
3. The hardcoded image overrides for the affected sub-components are removed from the generated `values.yaml`, so that the correct dev image references from the sub-charts are used.
4. `helm dependency update` resolves the redirected dependencies.
5. LOP-IdP is deployed (`component-apply` or `helm-apply`).

---

## Manual Workflow (background knowledge)

The automated workflow essentially performs the following manual steps. They are documented here for understanding or special cases.

1. **In the sub-chart repos:** `make helm-generate helm-package`
   - Generates chart versions with the current version (instead of `0.0.0-replaceme`)
   - Required for upgrades to work (downgrades are generally prevented)
2. **Push dev image to the local registry:** `make image-import STAGE=development RUNTIME_ENV=k3d`
3. **In the `lop-idp` repo — adjust `Chart.yaml`:**
   - Set `version` to zero for the major version of the respective components (e.g. `^7.0.0-0` for CAS `7.2.3-1`)
   - Redirect `repository` to the component to be tested using a `file://` reference
4. **Resolve sub-charts:** `make helm-update-dependencies`
5. **Deploy LOP-IdP:** `make component-apply`

Example `Chart.yaml` after manual adjustment:

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

---

### External LDAP

Testing an external LDAP connection without the LDAP Dogu/component is relatively straightforward. All you need is an LDAP service with existing account and group data.

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
