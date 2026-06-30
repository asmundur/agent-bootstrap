# Precise Scaffold Hydration Messaging

## Goal

Make scaffold refresh output accurately report whether `/bootstrap` is needed, without changing scaffold usage, rendered template output, or `.agent-scaffold.json` schema.

## Behavior

- First scaffold adoption still prompts the user to run `/bootstrap`.
- Refreshes with unresolved adoption conflicts still point to `/resolve-adopted-artifacts`.
- Refreshes with definitely generic required values list the exact variable names that still need hydration.
- Refreshes with concrete required values state that `/bootstrap` is not needed for that refresh.
- Command values of `not configured` remain valid and do not trigger hydration guidance.

## Implementation Notes

- Add a bash helper in `scripts/scaffold.sh` that checks only required scaffold identity/context values:
  - `PROJECT_NAME`
  - `PROJECT_DESCRIPTION`
  - `TECH_STACK`
  - `MAIN_LANGUAGE`
  - `SOURCE_DIR`
  - `ARCHITECTURE_PATTERN`
- Keep build, test, run, typecheck, lint, and browser verification commands out of the hydration-needed classifier.
- Preserve existing CLI arguments and state file shape.

## Verification

- Update scaffold cadence smoke coverage for first apply, refresh with generic required values, and refresh with concrete required values.
- Run `scripts/smoke-test-scaffold.sh`.
