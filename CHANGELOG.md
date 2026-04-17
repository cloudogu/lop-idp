# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v1.1.0] - 2026-04-17
### Changed
- [#3] Update components with new label `k8s.cloudogu.com/backup-scope` to include necessary k8s ressources in the backup.
  - This enables lop-idp and its components to be backed up by the `k8s-backup-operator`.

## [v1.0.0] - 2026-04-15
### Added
- [#1] Initial release of `lop-idp` as an umbrella component for bundled identity provider services in the LOP.
  - Bundled deployment of `cas`, `ldap-mapper`, `ldap`, `usermgt`, and the `k8s-auth-registration-operator`.
  - Support for installations with internal LDAP, external LDAP, and migration of existing LDAP-Dogu data into the component-based setup.
