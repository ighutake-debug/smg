# API Stability Policy

This policy defines which parts of SMG are compatibility contracts, how a change
to a contract is classified, and what an intentional break requires. It is the
single prose policy; the checks that enforce it own their own implementation
details and are tracked in [#2287](https://github.com/smg-project/smg/issues/2287).

## Public boundary

Every regular package under `crates/**` is a workspace member, inherits the
workspace lints, and passes the repository's formatting, Clippy, and test gate
described in [CONTRIBUTING.md](../CONTRIBUTING.md). That quality bar applies to
every package. Whether a package also carries a *public API promise* depends on
its category below.

| Category | What is the contract | What is not |
| --- | --- | --- |
| **Published Rust crate** (any workspace crate that is published to crates.io) | The crate's public Rust API for its documented feature profiles, under Rust SemVer. | Items behind `#[doc(hidden)]`, unstable features, and anything documented as internal. |
| **`smg-client`** (`clients/rust`) | Public Rust SDK: types, builders, and the endpoint surface it declares. Governed as a public SDK under Rust SemVer even while pre-1.0. | Internal HTTP plumbing. |
| **`model_gateway`** (the `smg` binary) | External HTTP routes and the generated OpenAPI document, CLI flags, configuration keys and defaults, released artifacts (crate, wheel, container image, Helm chart), and documented operational behavior such as health, readiness, and draining. | Its internal Rust modules. `model_gateway` is not a library contract and may be refactored freely as long as the external surfaces above are preserved. |
| **Bindings** (`bindings/python`, `bindings/golang`) | Quality and integration compatibility with the core version they are locked to. | An independent Rust API promise. A binding's Rust crate is an implementation detail. |
| **Quality-only crates** (workspace crates with `publish = false`, such as `mock-worker`) | Build, lint, and test cleanliness like every other package. | Any public API promise. They may change freely between releases. |
| **Engine and mesh protobuf** (`crates/grpc_client/proto`, `crates/mesh/src/proto`) | The wire schema and the supported generated consumers (Rust, Python, Go). | Unreleased or explicitly experimental messages. |

For HTTP, the contract is each supported route's method, path, required inputs,
response shape, error shape and codes, streaming media types, and authentication
behavior. Routes that are preview or internal must say so in the OpenAPI document
and are not covered until they are reclassified as stable.

For the CLI and configuration, the contract is each supported flag and key, its
type and accepted values, its default, exit behavior, and any output that is
machine-consumed.

## Change classification

Every change to a contract is one of:

- **Additive.** Adds capability while every existing supported consumer continues
  to compile or import, send, parse, and operate as before.
- **Deprecated-compatible.** Introduces a documented replacement and keeps the old
  behavior working for the full deprecation window below.
- **Breaking.** Removes, restricts, reinterprets, or observably changes a
  supported contract, including any change that makes an existing supported
  consumer fail to compile, import, send, parse, or operate as before.

Contract-specific rules:

- **Published Rust crates.** Follow [Rust SemVer](https://doc.rust-lang.org/cargo/reference/semver.html).
  At **1.x**, a breaking public API change requires the next **major** release;
  patch and minor releases are compatible. **Pre-1.0**, a patch release is
  compatible and a breaking change requires the next **minor** release.
  Enabling a feature must never remove or change items exposed without it.
- **Protobuf.** Field numbers and their meaning are immutable. Removed fields and
  enum values keep their names and numbers `reserved`. A new field, message, enum
  value, or RPC is additive only when supported generated consumers still build or
  import, parse the expanded schema, and operate correctly with it. A change an
  existing consumer cannot accept is a versioned replacement (new message, RPC, or
  package), not an in-place edit.
- **HTTP / OpenAPI.** A new route, a new optional request field, or a new response
  field is additive. Removing a route or method, making an optional input
  required, narrowing accepted input, or changing a response, error, streaming
  media type, or authentication semantic is breaking. The OpenAPI document must
  describe exactly the mounted routes; a route that is not in the document is not
  supported.
- **CLI / configuration.** A new flag or key is additive only when its default
  preserves existing behavior and output. Removing, renaming, retyping, making
  required, narrowing accepted values, or changing the meaning of a flag or key is
  breaking, as is changing a default, exit behavior, or machine-consumed output.
- **Released artifacts and operational behavior.** Changing an artifact's name,
  coordinates, supported platforms, or documented lifecycle behavior (health,
  readiness, draining, signal handling) is breaking unless the previous behavior
  is retained for the deprecation window.

## Deprecation

A deprecated contract keeps working, is marked deprecated where its consumers will
see it (`#[deprecated]` for Rust, `deprecated: true` in OpenAPI, `[deprecated =
true]` in protobuf, a startup warning for CLI and configuration), and its
documentation names the replacement and the migration path.

Minimum window before removal:

| Contract | Window |
| --- | --- |
| Published Rust crate, `smg-client` | Two minor releases **and** 90 days, whichever is later. |
| HTTP / OpenAPI, CLI, configuration, operational behavior | Two minor `model_gateway` releases **and** 90 days, whichever is later. |
| Protobuf | Never removed in place; superseded by a versioned replacement. The old message or RPC stays served for at least two minor releases of the owning crate and 90 days. |
| Bindings | Track the core `model_gateway` window. |

A security fix may shorten a window only when the pull request records the
reason, the affected versions, the approvers, and the replacement path.

## Intentional breaking changes

An intentional break is allowed when it is deliberate, owned, approved, and
migratable. The pull request must:

1. **Name the contract and classify the change** in the description, using the
   categories above.
2. **State the version or release action** the surface requires: the major (or
   pre-1.0 minor) bump for a Rust crate, the versioned replacement for protobuf,
   or the `model_gateway` release the break ships in.
3. **Carry the `api-break-approved` label**, applied by an approver, not the
   author.
4. **Include release notes and a concrete migration path** that an affected
   consumer can follow without reading the diff.
5. **Have an accountable owner and two approvals**: the applicable code owner from
   [`.github/CODEOWNERS`](../.github/CODEOWNERS) and a Core Maintainer acting as
   release owner. If one person holds both roles, a second Core Maintainer
   approves.

A **compatibility exception**, where an enforcing check is told to accept a
specific finding, must be narrow (one finding, one surface), documented in the
check's own configuration with the reason and owner, and must expire within 90
days or at the next major release of the affected crate, whichever is sooner.
Broad waivers, disabling a check, or weakening it repository-wide are not
exceptions and require a change to this policy.

## Enforcement

The pre-PR gate in [CONTRIBUTING.md](../CONTRIBUTING.md#the-pre-pr-gate) enforces
package quality for every workspace member today. The direct compatibility
checks, inventory coverage, Rust and SDK SemVer, protobuf wire and consumer
builds, and HTTP/OpenAPI parity, are delivered by the workstreams tracked in
[#2287](https://github.com/smg-project/smg/issues/2287).

A check enforces this policy only when its result blocks merge in the
pull-request workflow's final gate. A job that merely runs, or that the final job
depends on without inspecting its result, is informational. The list of enforced
checks lives in the workflow, not here.

## Changes to this policy

This document is governed like [GOVERNANCE.md](../GOVERNANCE.md): changes are
proposed by pull request and require approval from the Core Maintainers.
