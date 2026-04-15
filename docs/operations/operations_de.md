# LOP-IdP betreiben

Die `lop-idp`-Komponente (Low Ops Platform - Identity Provider) ist eine Sammelkomponente, die die Installation zentraler LOP-Komponenten in einer Cloudogu EcoSystem-Multinode-Instanz bündelt.

Sie löst die Dogu-Varianten der Dogus CAS, LDAP, LDAP-Mapper und User Management ab, indem sie stattdessen zentral angesiedelte Kubernetes-Komponenten anbietet. Dies besitzt deutliche Vorteile hinsichtlich des Rechte-Managements zwischen Dogus und/oder Komponenten.

Dieses Dokument beschreibt übliche Szenarien, wie die `lop-idp`-Komponente installiert werden kann. Alle folgenden Szenarien teilen sich die Voraussetzung, dass eine gewisse Grundinstallation bereits durchgeführt sein muss. D. h. bevor die `lop-idp`-Komponente installiert werden kann, müssen diese Komponenten und CRDs installiert worden und betriebsbereit sein:

- Dogu-Operator `k8s-dogu-operator` inkl. der dazugehörigen CRDs
- Komponenten-Operator `k8s-component-operator` inkl. der dazugehörigen CRDs
- Auth-Registration-CRD `k8s-auth-registration-lib`

Der `k8s-auth-registration-operator` selbst wird hingegen zusammen mit `lop-idp` als Sub-Chart ausgerollt. Separat vorausgesetzt wird nur die zugehörige CRD.

https://github.com/cloudogu/ecosystem-core/blob/develop/docs/operations/configuration_de.md#komponenten-components

Alle Erwähnungen von Werten in der Datei `values.yaml` beziehen sich darauf, in der Komponenten-CR das Feld `spec.valuesYamlOverwrite` mit den entsprechenden Änderungen zu befüllen, also bspw. so:

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

Die genannten Werte werden dann vom Komponenten-Operator entsprechend an die Helm-Bibliothek weitergegeben.

Weitere Informationen zu einstellbaren Werten befinden sich in den folgenden Repositories:
- [LDAP `values.yaml`](https://github.com/cloudogu/ldap/blob/develop/k8s/helm/values.yaml) - [erklärt](https://github.com/cloudogu/ldap/blob/develop/docs/operations/ldap_component_installation_en.md#4-configuration-valuesyaml-overview)
- [LDAP-Mapper `values.yaml`](https://github.com/cloudogu/ldap-mapper/blob/develop/k8s/helm/values.yaml) - [erklärt](https://github.com/cloudogu/ldap-mapper/blob/develop/docs/operations/ldap_mapper_component_installation_en.md#4-configuration-overview-valuesyaml)
- [CAS `values.yaml`](https://github.com/cloudogu/cas/blob/develop/k8s/helm/values.yaml)
- [User Management `values.yaml`](https://github.com/cloudogu/usermgt/blob/develop/k8s/helm/values.yaml)
- [Auth-Registration-Operator `values.yaml`](https://github.com/cloudogu/k8s-auth-registration-operator/blob/develop/k8s/helm/values.yaml) - [erklärt](https://github.com/cloudogu/k8s-auth-registration-operator/blob/develop/docs/operations/reference/operator_configuration_de.md#helm-values-k8shelmvaluesyaml)


## Installation

`lop-idp` muss als Komponente über den Komponenten-Operator des CES installiert werden.
Dazu muss eine entsprechende Custom-Resource (CR) für die Komponente erstellt werden.

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

Die neue yaml-Datei kann anschließend im Kubernetes-Cluster erstellt werden:

```shell
kubectl apply -f lop-idp.yaml --namespace ecosystem
```

Der Komponenten-Operator erstellt nun die `lop-idp`-Komponente im `ecosystem`-Namespace.

## Upgrade der lop-idp-Komponente

Zum Upgrade muss die gewünschte Version in der Custom-Resource angegeben werden.
Dazu wird die erstellte CR-yaml-Datei editiert (z. B. wie unten) und die gewünschte Version eingetragen.
Anschließend die editierte yaml Datei erneut auf den Cluster anwenden:

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
  version: 0.2.0 # vorher 0.1.0; nur ein Beispiel diese Version gibt es (noch) nicht
```

```shell
kubectl apply -f lop-idp.yaml --namespace ecosystem
```

Es ist notwendig, Dogu- und Blueprint-Operator-Versionen zu betreiben, die bereits kompatibel mit dem Betrieb von Postfix 
als Komponente und Authentication-CRs sind:
- k8s-dogu-Operator: v3.22.0+
- k8s-blueprint-Operator: v3.3.0+

## Konfiguration

### Interner LDAP (Neuinstallation)

Alles sollte schlüsselfertig funktionieren

### Externer LDAP  (Neuinstallation)

LDAP-Zugang als Secret ablegen:
```shell
kubectl -n ecosystem create secret generic \
  external-ldap \
  --from-literal=username=cn=admin,dc=planetexpress,dc=com \
  --from-literal=password=GoodNewsEveryone
```

Dann die `values.yaml`-Datei bzgl. des externen LDAP-Dienstes konfigurieren:

```yaml
lop-idp:
  external-ldap:
    disabled: false # deaktiviert die Nutzung von LDAP und User Management

cas:
  configuration:
    normal: # in config.yaml style
      ldap:
        base_dn: "ou=people,dc=planetexpress,dc=com"
        connection_dn: "cn=admin,dc=planetexpress,dc=com" # der LDAP-Bind-Username nochmal, identisch mit dem im secret
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
        name: external-ldap # Referenz zu dem Secret, das oben generiert wurde 
        key: password
      ldapUsername:
        name: external-ldap
        key: username

ldap-mapper:
  configuration:
    backend:
      type: "external"
      host: "192.168.56.1" # IP-Adresse oder FQDN zum externen LDAP-Service
      port: "10389"        # dazugehöriger Port
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
      name: "external-ldap"  # Referenz zu dem Secret, das oben generiert wurde
      usernameKey: "username"
      passwordKey: "password"
#...
```

### Migration einer Bestandsinstanz



1. Diese Dogus löschen
   - cas `kubectl -n ecosystem delete dogu cas`
   - ldap-mapper `kubectl -n ecosystem delete dogu ldap-mapper`
   - postfix `kubectl -n ecosystem delete dogu postfix`
   - usermgt `kubectl -n ecosystem delete dogu usermgt`
2. `postfix`-Komponente installieren
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
     version: 3.10.8-2 # oder neuer
     valuesYamlOverwrite: |
       configuration:
         normal:
           relayHost: your.mail.relay.host.here
   EOF
   ```
3. Vorbereitungen für die LDAP-Migration treffen
   1. Authentication-CRD einspielen (hier die Version 0.1.1) falls noch nicht geschehen
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
   2. Dogu-Operator einspielen, falls noch nicht geschehen
4. values.yaml der `lop-idp`-Komponente bzgl. einer LDAP-Migration konfigurieren
   - Der Schalter `ldap.migration.enabled` sorgt dafür eine Migration der Daten.
   - Anschließend wird das Dogu automatisch gestoppt. Das Dogu kann nach Abschluss des gesamten Prozesses entfernt werden.
   ```yaml
   #...
   ldap:
     migration:
       enabled: true
   #...
   ```
5. Die `lop-idp`-Komponente auf den Cluster anwenden
   - bestehende LDAP-Daten werden vom LDAP-Migrationsjob übernommen
6. Komponenten und Pods auf evtl. Fehler prüfen
7. Aufräumarbeiten durchführen
   - Relayhost in der `postfix-config` configmap auf den vorherigen Wert setzen
   - Das ldap-Dogu löschen

![Eine Person mit der Rolle "Administrator" löscht von außerhalb des Clusters die Dogus "User Management", "ldap-mapper" und CAS, nicht jedoch das Dogu "LDAP". Daraufhin installiert die Person die "lop-idp"-Komponente. Diese erzeugt die (Unter-)Komponenten-Pendents der gelöschten Dogus. Zusätzlich erzeugt die lop-idp-Komponenten auch eine LDAP-Migration, die das LDAP-Dogu nach der Datenmigration stoppt. Am Rand befinden sich drei notwendige Komponenten "Component Operator", "Dogu Operator" und "Auth Registration Operator" ohne Pfeile, damit Betrachter:innen sich auf die "lop-idp"-Komponente fokussieren können](images/lop-idp-migration-process.drawio.png "Diagramm von Aktionen, die in einer Bestandsinstanz zu einer LDAP-Migration")
