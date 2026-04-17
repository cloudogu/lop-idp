# LOP-IdP Architecture

LOP-IdP is a container component designed to provide bundled identity provider mechanisms to Dogus and other components. As such, it represents a key component of the Cloudogu EcoSystem Low Ops Platform (CES-LOP) concept.

## Dependencies

To create a bundled identity provider environment, the `lop-idp` component is an umbrella chart that relies on various types of components. It primarily depends on the components listed in `Chart.yaml`:
- ldap-mapper
- cas
- ldap (optional, due to external LDAP)
- usermgt (optional, due to external LDAP)
- k8s-auth-registration-operator

For these dependencies, the values of the listed sub-charts can be overridden in addition to the configuration options in `values.yaml`.

The `k8s-auth-registration-operator` is deployed as a direct sub-chart together with LOP-IdP. 
It reconciles `AuthRegistration` custom resources and registers the authentication endpoints provided by LOP-IdP for other components in the cluster.

There are also implicit dependencies specified via annotations in `Chart.yaml`. 
These must already be installed beforehand. 
Essentially, these are the [CRDs](https://github.com/cloudogu/k8s-auth-registration-lib) of the [Authentication-Registration-Operator](https://github.com/cloudogu/k8s-auth-registration-operator), since the main purpose is identity provisioning, i.e., authentication. 
The CRD is therefore required separately, while the corresponding operator itself is part of the LOP-IdP deployment.

Since `lop-idp` is a component itself, the [Component Operator](https://github.com/cloudogu/k8s-component-operator) must be operational in order to install `lop-idp`.

## Deployment Considerations

This section discusses the methods available for deploying LOP-IdP in a cluster and any special cases or additional considerations that may apply.

### Deployment Options

`lop-idp` can be deployed on its own, i.e., via a Component-CR as described in `operations_de.md`.

### Special Considerations for Deployments

#### Migration of Dogu LDAP Data

The `ldap` sub-chart is used. When deployed as a CES component, it has the ability to migrate Dogu LDAP data and then stop the Dogu pod. However, this requires setting the LDAP switch `ldap.migration.enabled = false`.

For further information, please refer to the [LDAP](https://github.com.cloudogu/ldap) documentation.

## Interaction of Dependent Components in the LOP-IdP

The subcharts for the dependent components `ldap-mapper`, `cas`, `ldap`, `usermgt`, and `k8s-auth-registration-operator` are composed so that the Kubernetes resources required by LOP-IdP are provided consistently. Shared resources (e.g., names of `Secrets`) have been coordinated so that the LOP-IdP’s `values.yaml` file does not necessarily need to be adapted to the sub-charts. This enables a quick and very minimal configuration for standard deployments of the LOP-IdP.

In this setup, the `k8s-auth-registration-operator` is responsible for reconciling the `AuthRegistration` resources required or provided by `cas` and `ldap-mapper`. This allows other components to reference the centrally provided login and directory services of LOP-IdP in a standardized way without needing to know the concrete technical wiring of the individual sub-components.

Exceptions to this include, in particular, Kubernetes `Services` that are accessed by other Dogus or components within the cluster. These retain a simple name such as `cas`, i.e., without the `lop-idp` prefix, to simplify addressing.
