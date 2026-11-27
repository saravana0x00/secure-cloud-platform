# Post-mortem: storage protections disabled for three days (simulated)

**This is a fictional tabletop exercise.** It was written to practise incident analysis against the risks in
`threat-model.md`. No real incident, customer or data is involved. Names are roles, not people.

Status: complete. Severity: medium (exposure window, no confirmed data access). Format: blameless.

## Summary

During troubleshooting, an engineer removed the public access block from a storage bucket holding internal exports.
The block stayed off for three days. A scheduled review found it. Logs showed no confirmed outside access, but access
logging on that bucket was incomplete, so the absence of access could not be proven.

## Impact

- One bucket exposed to anyone who guessed its name for about 72 hours.
- Contents: internal exports, no payment data, some internal identifiers.
- Customer impact: none confirmed. Exposure impact: not provable either way, which is itself a finding.

## Timeline (illustrative)

| Time | Event |
|---|---|
| Day 1, 10:05 | An export job fails with an access error. An engineer removes the bucket's public access block to rule it out as the cause |
| Day 1, 10:20 | The job succeeds for an unrelated reason (a permissions fix). The block is never restored |
| Day 1 to 3 | No alert fires. Nothing checks the setting automatically |
| Day 4, 09:30 | A manual configuration review notices the missing block |
| Day 4, 09:45 | Block restored by the on-call engineer. Incident declared |
| Day 4, 10:30 | Log review begins. Access logging on this bucket shows gaps |
| Day 5 | Post-mortem held |

## Root cause analysis

**Trigger:** a person disabled a safety setting while debugging, then forgot to restore it.

**Root causes (system level):**

1. **Nothing prevented the change.** Any engineer with bucket permissions could remove the block. The setting was
   protected only by habit.
2. **Nothing detected the change.** The drift tool existed but ran only when someone ran it, and no alert was wired
   to configuration changes.
3. **Nothing proved what happened afterwards.** Access logs were incomplete, so the team could not show that nobody
   read the data.

**Contributing factors:** the fix for the original failure was unrelated, so the engineer had no reason to revisit the
setting; there was no ticket or checklist for temporary changes.

**What was not the cause:** individual carelessness. Anyone debugging under time pressure could do the same, so the fix
must not rely on people remembering.

## What went well

- The configuration review did find the problem, and restoring the block took 15 minutes.
- Encryption was still on, so the data was not stored in the clear.
- The team declared an incident and ran a review instead of quietly fixing it.

## What went badly

- Three days of exposure with no alert.
- No way to prove whether the data was read.
- The only detection was a manual review, which is luck, not a control.

## Corrective actions

| # | Action | Type | Closes | Owner (role) | Priority |
|---|---|---|---|---|---|
| 1 | Add a preventive guardrail so the public access block cannot be removed except through the approved change pipeline | Prevent | Root cause 1 | Platform security | High |
| 2 | Alert on any change to bucket protection settings, routed to the on-call engineer | Detect | Root cause 2 | Platform security | High |
| 3 | Run the drift tool on a schedule, and fail loudly when it finds drift | Detect | Root cause 2 | Platform engineering | High |
| 4 | Make access logging mandatory on every bucket and check it in the pipeline | Prove | Root cause 3 | Platform engineering | Medium |
| 5 | Protect logs from tampering and deletion | Prove | Root cause 3 | Security operations | Medium |
| 6 | Add a "temporary change" process: any manual change to a protection setting gets a ticket with an expiry | Process | Contributing factor | Engineering management | Medium |

**Ordering rationale:** prevention (1) comes first because it removes the whole class of problem. Detection (2, 3)
is second because it limits the exposure window when prevention fails. Proof (4, 5) matters because during this
incident the team could not answer the first question anyone asks: was the data accessed?

## Mapping to this repository

| Action | Status in `secure-cloud-platform` |
|---|---|
| 3 | Partly built: `automation/s3_remediate.py` detects and repairs drift, but runs on demand only |
| 4 | Partly built: Terraform enables access logging and Checkov checks for it, but only for resources defined as code |
| 1, 2, 5, 6 | Not built. Listed in the threat model residual risks |

## Lessons

- A control that relies on memory will eventually be forgotten. Make the safe state the one that needs no effort.
- Detection is not the same as proof. Logging has to be in place before the incident, because it cannot be added after.
- Measure the exposure window, not just whether a fix happened. Here it was 72 hours.