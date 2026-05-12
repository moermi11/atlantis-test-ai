# ADR-0006: Initial Shell Strategy

- Status: accepted
- Date: 2026-04-21

## Context

Atlantis needs a shell path for the first boot attempt, but Sprint 1 is not the time to build a full Atlantis-specific UI.

The shell decision must:

- provide a realistic path to a visible session
- avoid spending Sprint 1 on custom UI engineering
- keep Atlantis ownership boundaries clear
- allow replacement later without redesigning the package layout

The main alternatives were:

### Option A: build a custom Atlantis shell immediately

Advantages:

- maximum product ownership from day one

Disadvantages:

- highest engineering cost before boot is even proven
- would delay the first real boot attempt
- mixes product UX ambition with basic bring-up risk

### Option B: use upstream Phosh as the initial shell behind an Atlantis integration package

Advantages:

- proven mobile-oriented upstream shell stack
- shortens the path to a visible session
- keeps Atlantis in control of package boundaries and later replacement strategy

Disadvantages:

- early UX is constrained by upstream Phosh behavior
- Atlantis branding and shell-specific behavior stay intentionally limited at first

### Option C: avoid a shell entirely for first bring-up

Advantages:

- simplest possible userspace target

Disadvantages:

- weak validation of the actual mobile user-session path Atlantis ultimately needs
- delays shell integration problems instead of isolating them

## Decision

Choose Option B.

Sprint 1 uses upstream Phosh as the initial Atlantis shell. Atlantis owns:

- the `atlantis-shell` package boundary
- session integration decisions
- Atlantis branding handoff
- the future replacement path

Atlantis does not own upstream Phosh internals in Sprint 1.

## Boundaries

Upstream-owned in Sprint 1:

- Phosh shell implementation
- compositor/session pieces pulled in by the upstream package stack
- upstream mobile-shell runtime behavior unless Atlantis explicitly overrides it later

Atlantis-owned in Sprint 1:

- whether Phosh is present at all
- which Atlantis package depends on it
- shell-related documentation and test strategy
- the rule that no device-specific logic belongs in the shell package

## Consequences

Positive:

- the first boot path can target a visible shell without inventing a new UI stack
- shell ownership remains explicit and replaceable
- generic shell integration stays separate from device enablement

Tradeoffs:

- Atlantis branding is limited until later sprints
- future shell replacement needs disciplined compatibility work at the package boundary

## Long-Term Impact

- `atlantis-shell` becomes the stable integration seam between Atlantis and the current shell implementation
- a future Atlantis-specific shell can replace Phosh by changing that package boundary, not by rewriting the core OS layout
- Sprint 1 work remains useful even after Phosh is replaced

## Follow-Up

- define the nested desktop Phosh smoke-test path
- add Atlantis-specific session defaults only when needed for boot and validation
- delay custom Atlantis shell implementation until the boot path is proven
