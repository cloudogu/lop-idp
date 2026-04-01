# k8s-lop-idp betreiben

## Installation

`k8s-lop-idp` muss als Komponente über den Komponenten-Operator des CES installiert werden.
Dazu muss eine entsprechende Custom-Resource (CR) für die Komponente erstellt werden.

```yaml
apiVersion: k8s.cloudogu.com/v1
kind: Component
metadata:
  name: k8s-lop-idp
  labels:
    app: ces
spec:
  name: k8s-lop-idp
  namespace: TODO_PLEASE_FIX_ME
```

Die neue yaml-Datei kann anschließend im Kubernetes-Cluster erstellt werden:

```shell
kubectl apply -f k8s-lop-idp.yaml --namespace ecosystem
```

Der Komponenten-Operator erstellt nun die `k8s-lop-idp`-Komponente im `ecosystem`-Namespace.

## Upgrade

Zum Upgrade muss die gewünschte Version in der Custom-Resource angegeben werden.
Dazu wird die erstellte CR yaml-Datei editiert und die gewünschte Version eingetragen.
Anschließend die editierte yaml Datei erneut auf den Cluster anwenden:

```shell
kubectl apply -f k8s-lop-idp.yaml --namespace ecosystem
```

## Konfiguration

TODO
