# Lokale Entwicklung von LOP-IdP-Komponenten

Dieser Abschnitt beschreibt die notwendigen Tätigkeiten, um `lop-idp` mit Entwicklungsversionen von Unterkomponenten wie z. B. LDAP im Cluster anzuwenden. Der hauptsächliche Trick besteht darin, `Chart.yaml` auf eine verfügbare Entwicklungsversion zu setzen. 

Das hier beschriebene Verfahren vermeidet dabei OCI-Pushes auf externe Registries, sondern bezieht seine Änderungen von einem lokalen `lop-idp`- und einem lokalen Unter-Helm-Chart über Dateireferenzen in der `Chart.yaml`.:   

1. In den Sub-Chart-Repos: `make helm-generate helm-package`
   - dieser Schritt erzeugt Chart-Versionen mit der aktuellen `ARTIFACT_ID` bzw. `COMPONENT_ID` (im Ggs. zu `0.0.0-replaceme`)
   - dies erleichtert Komponentenupgrades, da Downgrades i. d. R. unterbunden werden
2. Im `lop-idp`-Repo
   1. `Chart.yaml` anpassen
      - **Wichtig:** `version` auf die Major-Version der jeweiligen Komponenten nullen, die den Entwicklungsteil ausmachen
        - z. B. CAS in der Repo-Version `7.2.3-1` wird als `^7.0.0-0` genannt
      - `repository` mittels File-Referenz auf die zu testende Komponente umbiegen
   2. Die Sub-Charts inkls. Entwicklungsteil in die `lop-idp` ziehen: `make helm-update-dependencies`
      - die richtigen Chart-Versionen müssten sich nun 
3. ggf. sämtliche frühere Komponententeile löschen (nur bei Erstinstallation)
4. LOP-IDP auf den Cluster anwenden `make component-apply`

Beispiel-`Chart.yaml`:
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

Tests einer externen LDAP-Verbindung ohne LDAP-Dogu/-Komponente ist vergleichsweise einfach. Alles was benötigt wird, ist ein LDAP-Dienst mit bestehenden Konten- und Gruppendaten.

Hier lohnt sich das Docker-Image [rroemhild/docker-test-openldap](https://github.com/rroemhild/docker-test-openldap), da hier bereits eine sinnvolle Datenstruktur angeboten wird. In dem folgenden Beispiel mit lokalem Cluster über VirtualBox wird ein LDAP über die VBox-interne IP-Adresse `192.168.56.1` in den VMs bekannt gemacht:

1. Auf dem Host außerhalb des Clusters den LDAP starten
   - `docker run --rm -p 10389:10389 -p 10636:10636 ghcr.io/rroemhild/docker-test-openldap:master`
2. LDAP-Secret (hier: `external-ldap`) anlegen
```shell
kubectl -n ecosystem \
  create secret generic external-ldap \
  --from-literal=username=cn=admin,dc=planetexpress,dc=com \
  --from-literal=password=GoodNewsEveryone
```
3. Externen LDAP in den CAS- und ldap-mapper-Bereichen in der `values.yaml` der `lop-idp`-Komponente konfigurieren 
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
4. Ausbringen der `lop-idp`-Komponente
   - `make component-apply` 

Anmeldungen sind möglich, wenn alle Komponenten und Pods `ready` sind. Auf saubere Abmeldung bestehender CAS-Sessions achten.
- Admin-Login mit `hermes:hermes`
- Nicht-Admin-Login mit `fry:fry`

Mehr zur verwendeten LDAP-Struktur siehe [rroemhild/docker-test-openldap](https://github.com/rroemhild/docker-test-openldap)
