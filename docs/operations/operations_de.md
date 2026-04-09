# lop-idp betreiben

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
  namespace: TODO_PLEASE_FIX_ME
```

Die neue yaml-Datei kann anschließend im Kubernetes-Cluster erstellt werden:

```shell
kubectl apply -f lop-idp.yaml --namespace ecosystem
```

Der Komponenten-Operator erstellt nun die `lop-idp`-Komponente im `ecosystem`-Namespace.

## Upgrade

Zum Upgrade muss die gewünschte Version in der Custom-Resource angegeben werden.
Dazu wird die erstellte CR yaml-Datei editiert und die gewünschte Version eingetragen.
Anschließend die editierte yaml Datei erneut auf den Cluster anwenden:

```shell
kubectl apply -f lop-idp.yaml --namespace ecosystem
```

Es ist sinnvoll, Dogu- und Blueprint-Operator-Versionen zu betreiben, die bereits kompatibel mit dem Betrieb von Postfix 
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
   - postfix `kubectl -n ecosystem delete dogu postfix`
   - cas `kubectl -n ecosystem delete dogu cas`
   - ldap-mapper `kubectl -n ecosystem delete dogu ldap-mapper`
2. Authentication-CRD einspielen (hier die version 0.1.1)
```shell
cat <<EOF | kubectl -n ecosystem apply -f -  
apiVersion: k8s.cloudogu.com/v1
kind: Component
metadata:
  name: k8s-auth-registration-crd
spec:
  name: k8s-auth-registration-crd
  namespace: k8s
  version: 0.1.1
EOF
```
3. values.yaml bzgl. einer LDAP-Migration konfigurieren
```yaml
#...
ldap:
  migration:
    enabled: true
#...
```
4. Die lop-idp-Komponente auf den Cluster anwenden
   - bestehende LDAP-Daten werden vom LDAP-Migrationsjob übernommen
