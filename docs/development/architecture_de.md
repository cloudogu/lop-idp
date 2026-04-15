# LOP-IdP-Architektur

LOP-IdP ist eine Sammelkomponente, um gebündelt Identity-Provider-Mechanismen gegenüber Dogus und Komponenten anzubieten. Damit stellt sie eine wichtige Komponente im Konzept der Cloudogu EcoSystem Low Ops Plattform (CES-LOP) dar.

## Abhängigkeiten

Damit eine gebündelte Identity-Provider-Umgebung geschaffen werden kann, ist die `lop-idp`-Komponente ein Umbrella-Chart, das auf Komponenten unterschiedlicher Art angewiesen ist. Hauptsächlich beruht es auf den im `Chart.yaml` genannten _abhängigen_ Komponenten:
- ldap-mapper
- cas
- ldap (optional, wegen externem LDAP)
- usermgt (optional, wegen externem LDAP)
- k8s-auth-registration-operator

Für diese Abhängigkeiten lassen sich jenseits der `values.yaml`-Einstellmöglichkeiten auch die Werte der genannten Sub-Charts überschreiben. 

Der `k8s-auth-registration-operator` wird als direktes Sub-Chart gemeinsam mit LOP-IdP ausgerollt. 
Er verarbeitet `AuthRegistration`-Custom-Resources und registriert die von LOP-IdP bereitgestellten Authentisierungsendpunkte für andere Komponenten im Cluster.

Dazu kommen implizite Abhängigkeiten, die per Annotation im `Chart.yaml` genannt werden. 
Diese müssen bereits vorher installiert sein. Im Wesentlichen handelt es sich um die [CRD](https://github.com/cloudogu/k8s-auth-registration-lib) des [Authentication-Registration-Operators](https://github.com/cloudogu/k8s-auth-registration-operator), da der Hauptzweck ja Identity Providing also Authentisierung darstellt. 
Die CRD wird also separat vorausgesetzt, während der zugehörige Operator Teil des LOP-IdP-Deployments ist.

Da `lop-idp` selbst eine Komponente ist, muss der [Komponenten-Operator](https://github.com/cloudogu/k8s-component-operator) betriebsbereit sein, um `lop-idp` zu installieren.

## Deploymentbetrachtungen

Dieser Abschnitt beschäftigt sich damit, mit welchen Mitteln LOP-IdP in einen Cluster deployed werden kann und welche Sonderfälle oder weiteren Betrachtungen möglich sind.

### Möglichkeiten des Deployments

`lop-idp` kann für sich selbst deployt werden, also per Component-CR wie in `operations_de.md` beschrieben.

### Besonderheiten bei Deployments

#### Migration von Dogu-LDAP-Daten

Das Sub-Chart `ldap` wird verwendet. Dieses hat im Einsatz als CES-Komponente die Fähigkeit, Dogu-LDAP-Daten zu migrieren und den Dogu-Pod danach zu stoppen. Allerdings ist hierfür die Bedienung des LDAP-Schalters `ldap.migration.enabled = false` nötig.

Für weitere Informationen sollten Informationen aus dem [LDAP](https://github.com.cloudogu/ldap) zurate gezogen werden.

## Zusammenspiel der abhängigen Komponenten in der LOP-IdP

Die Sub-Charts abhängigen Komponenten `ldap-mapper`, `cas`, `ldap`, `usermgt` und `k8s-auth-registration-operator` wurden so zusammengestellt, dass die für LOP-IdP nötigen Kubernetes-Ressourcen konsistent bereitgestellt werden. 
Gemeinsam genutzte Ressourcen (z. B. Namen von `Secrets`) wurden so koordiniert, dass die `values.yaml`-Datei der LOP-IdP nicht unbedingt auf die Sub-Charts angepasst werden müssen. 
Dies ermöglicht eine schnelle und sehr schmale Konfiguration für Standarddeployments der LOP-IdP.

Der `k8s-auth-registration-operator` übernimmt dabei die Verarbeitung der von `cas` und `ldap-mapper` benötigten beziehungsweise bereitgestellten `AuthRegistration`-Ressourcen. 
Dadurch können andere Komponenten die zentral in der LOP-IdP bereitgestellten Login- und Verzeichnisdienste standardisiert referenzieren, ohne die konkrete technische Anbindung der Teilkomponenten selbst kennen zu müssen.

Ausnahmen sind hierbei insbesondere Kubernetes `Services`, die von anderen Dogus oder Komponenten innerhalb des Clusters angesprochen werden. Diese behalten einen einfachen Namen wie `cas`, also ohne Prefix `lop-idp`, um die Adressierung leichter zu gestalten.
