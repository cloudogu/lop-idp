# Lokale Entwicklung von LOP-IdP-Komponenten

Da die Unterkomponenten (ldap, cas, usermgt, ldap-mapper, k8s-auth-registration-operator) nicht als eigenständigen CES-Komponenten installiert werden, sondern zum Helm-Release der LOP-IdP gehören, können sie nicht per `make component-apply` in ihren eigenen Repos deployt werden.
Um eine Unterkomponente im Kontext der LOP-IdP zu testen, muss die LOP-IdP selbst mit einem lokalen Entwicklungsstand der Unterkomponente ausgebracht werden.

## Automatisierter Dev-Workflow (empfohlen)

### Einrichtung

Im Root des Repos liegt eine `.env.template`-Datei als Vorlage. Sie einmalig kopieren und anpassen:

```bash
cp .env.template .env
```

In der `.env` die Pfade zu den lokal ausgecheckten Unterkomponenten eintragen, die entwickelt werden sollen. Alle anderen bleiben auskommentiert:

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

> **Hinweis:** Komponenten-Namen mit Bindestrichen werden in den Variablennamen zu Unterstrichen  
> (z. B. `ldap-mapper` → `DEV_DIR_ldap_mapper`).

### Deployment

```bash
# Deployment über den Component Operator (Standard)
make dev-component-apply

# Direktes Helm-Deployment (schnellere Iteration, kein Component Operator)
make dev-component-helm-apply
```

Alle Unterkomponenten, für die ein `DEV_DIR_*`-Eintrag in der `.env` gesetzt ist, werden gebaut und in der LOP-IdP ausgetauscht.
Alle nicht gesetzten Komponenten bleiben auf ihrem Release-Stand.

### Was passiert intern

1. Für jede gesetzte `DEV_DIR_<name>`-Variable wird im jeweiligen Unterkomponenten-Repo `make helm-package image-import STAGE=development` ausgeführt. Das erzeugt das Dev-Chart und pusht das Dev-Image in die lokale Registry.
2. Die Chart-Abhängigkeiten der LOP-IdP werden auf die lokal gebauten Charts umgebogen (`file://`-Referenz in `Chart.yaml`).
3. Die fest eingetragenen Image-Overrides für die betroffenen Unterkomponenten werden aus der generierten `values.yaml` entfernt, damit die korrekten Dev-Image-Referenzen aus den Sub-Charts angezogen werden.
4. `helm dependency update` löst die umgebogenen Abhängigkeiten auf.
5. Die LOP-IdP wird deployt (`component-apply` oder `helm-apply`).

---

## Manueller Workflow (Hintergrundwissen)

Der automatisierte Workflow führt im Wesentlichen die folgenden manuellen Schritte aus. Sie sind hier für das Verständnis oder für Sonderfälle dokumentiert.

1. **In den Sub-Chart-Repos:** `make helm-generate helm-package`
   - Erzeugt Chart-Versionen mit der aktuellen Version (statt `0.0.0-replaceme`)
   - Nötig damit Upgrades funktionieren (Downgrades werden i. d. R. unterbunden)
2. **Dev-Image in die lokale Registry pushen:** `make image-import STAGE=development RUNTIME_ENV=k3d`
3. **Im `lop-idp`-Repo – `Chart.yaml` anpassen:**
   - `version` auf die Major-Version nullen (z. B. `^7.0.0-0` für CAS `7.2.3-1`)
   - `repository` per `file://`-Referenz auf das lokale Sub-Chart umbiegen
4. **Sub-Charts auflösen:** `make helm-update-dependencies`
5. **LOP-IdP deployen:** `make component-apply`

Beispiel-`Chart.yaml` nach manueller Anpassung:

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
