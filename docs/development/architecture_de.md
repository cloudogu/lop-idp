# LOP-IdP-Architektur

LOP-IdP ist eine Sammelkomponente, um gebündelt Identity-Provider-Mechanismen gegenüber Dogus und Komponenten anzubieten. Damit stellt sie eine wichtige Komponente im Konzept der Cloudogu EcoSystem Low Ops Plattform (CES-LOP) dar.

## Abhängigkeiten

Damit eine gebündelte Identity-Provider-Umgebung geschaffen werden kann, ist die `lop-idp`-Komponente ein Umbrella-Chart, das auf Komponenten unterschiedlicher Art angewiesen ist. Hauptsächlich beruht es auf den im `Chart.yaml` genannten _abhängigen_ Komponenten:
- ldap-mapper
- cas
- ldap (optional, wegen externem LDAP)
- usermgt (optional, wegen externem LDAP)

Für diese Abhängigkeiten lassen sich jenseits der `values.yaml`-Einstellmöglichkeiten auch die Werte der genannten Sub-Charts überschreiben. 

Dazu kommen implizite Abhängigkeiten, die per Annotation im `Chart.yaml` genannt werden. Diese müssen bereits vorher installiert sein. Im Wesentlichen handelt es sich um die [CRD](https://github.com/cloudogu/k8s-auth-registry-lib) des [Authentication-Registration-Operators](https://github.com/cloudogu/k8s-auth-registry-operator), da der Hauptzweck ja Identity Providing also Authentisierung darstellt. Zur CRD gehört auch der Authentication-Registration-Operator selbst, der die AuthRegistration-CRs behandelt.

Da `lop-idp` selbst eine Komponente ist, muss der [Komponenten-Operator](https://github.com/cloudogu/k8s-component-operator) betriebsbereit sein, um `lop-idp` zu installieren.

## Deploymentbetrachtungen

Dieser Abschnitt beschäftigt sich damit, mit welchen Mitteln LOP-IdP in einen Cluster deployed werden kann und welche Sonderfälle oder weiteren Betrachtungen möglich sind.

### Möglichkeiten des Deployments

`lop-idp` kann für sich selbst deployt werden, also per Component-CR wie in `operations_de.md` beschrieben.

TODO: Sollte man das überhaupt erwähnen, wenn es noch kein Fakt ist?
Alternativ soll es zukünftig möglich sein, `lop-idp` über die [ecosystem-core-Komponente](https://github.com/cloudogu/ecosystem-core/) zu installieren.

### Besonderheiten bei Deployments

#### Migration von Dogu-LDAP-Daten

Das Sub-Chart `ldap` wird verwendet. Dieses hat im Einsatz als CES-Komponente die Fähigkeit, Dogu-LDAP-Daten zu migrieren und den Dogu-Pod danach zu stoppen. Allerdings ist hierfür die Bedienung des LDAP-Schalters `ldap.migration.enabled = false` nötig.

Für weitere Informationen sollten Informationen aus dem [LDAP](https://github.com.cloudogu/ldap) zurate gezogen werden.

## Zusammenspiel der abhängigen Komponenten in der LOP-IdP

Die Sub-Charts abhängigen Komponenten `ldap-mapper`, `cas`, `ldap` und `usermgt` wurden so optimiert, dass die meisten Kubernetes-Ressourcen ein 'lop-idp'-Prefix erhalten. Gemeinsam genutzte Ressourcen (z. B. Namen von `Secrets`) wurden so koordiniert, dass die `values.yaml`-Datei der LOP-IdP nicht unbedingt auf die Sub-Charts angepasst werden müssen. Dies ermöglicht eine schnelle und sehr schmale Konfiguration für Standarddeployments der LOP-IdP. 

Ausnahmen sind hierbei insbesondere Kubernetes `Services`, die von anderen Dogus oder Komponenten innerhalb des Clusters angesprochen werden. Diese behalten einen einfachen Namen wie `cas`, also ohne Prefix `lop-idp`, um die Adressierung leichter zu gestalten.
