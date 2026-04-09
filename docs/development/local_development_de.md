# Lokale Entwicklung von LOP-IdP-Komponenten

1. in den Sub-Chart-Repos: `make helm-package`
2. In der lop-idp 
   1. `Chart.yaml` anpassen
      - `version` auf die Major-Version der Komponenten nullen
        - z. B. CAS v7.2.3-1 -> `^7.0.0-0`
      - `repository` mittels File-Referenz auf die zu testende Komponente umbiegen
   2. die Sub-Charts inkls. Entwicklungsteil beziehen: `make helm-update-dependencies`
3. ggf. sämtliche frühere Komponententeile löschen (nur bei Erstinstallation)
4. LOP-IDP auf den Cluster anwenden `make component-apply`

Beispiel Chart.yaml:
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

### Externer LDAP
https://github.com/rroemhild/docker-test-openldap

`docker run --rm -p 10389:10389 -p 10636:10636 ghcr.io/rroemhild/docker-test-openldap:master`
Konfig siehe operations_de.md