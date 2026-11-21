# Manara Stage 5 scoring policy

This document describes policy version 3 (`Stage5RiskPolicy.VERSION` in
`Stage5AssessmentEngine.kt`). Version 3 adds the pre-connection scan rules (PRE-1 to PRE-15) for
the connected access point and the matching `stage1.scan` coverage check. Version 2 had only the
Stage 1 profile, Stage 2, Stage 3 and Stage 4 inputs.

The scores are heuristic indices, not calibrated probabilities. The weights and cutoffs still need
benign-network and controlled-anomaly evaluation before release.

## Separate outputs

- **Threat suspicion** estimates current-session evidence of identity, DNS, TLS, or traffic manipulation.
- **Security exposure** estimates user exposure, such as open or weak Wi-Fi encryption and observed cleartext HTTP.
- **Connectivity** is reported independently as validated internet, captive portal, no internet, or inconclusive.
- **Assessment coverage** reports how much relevant data is fresh and usable. Not-applicable checks are excluded from the coverage percentage; unavailable, inconclusive, and not-run checks reduce it. Coverage is HIGH at 80% or more completed checks, MEDIUM at 50% or more, and LOW below that.

Each score uses LOW (0–9), GUARDED (10–24), ELEVATED (25–44), HIGH (45–69), and CRITICAL (70–100) bands. A low score means no significant indicators were found by completed checks; it does not mean the network is safe.

Both scores are empty (unavailable) when there is no fresh profile of a Wi-Fi connection.

## Inputs and freshness

Stage 5 uses only observations for the current `networkSessionId`, and only while they are fresh.
A stale observation stays in the assessment as inconclusive and contributes no points.

| Input | Fresh for | Coverage checks |
| --- | ---: | --- |
| Stage 1 network profile | 2 minutes | `stage1.*` per profile field |
| Stage 1 pre-connection scan rules for the connected access point | 2 minutes | `stage1.scan` |
| Stage 2 access-point identity rules (RAP-1 to RAP-6) | 5 minutes | one per rule, or `stage2.session` |
| Stage 3 connectivity and trust probes | 2 minutes | one per probe finding, or `stage3.session` |
| Stage 4 traffic capture (VPN) | 5 minutes | `stage4.http`, `stage4.model`, `stage4.sensitive`, `stage4.arp` |

The pre-connection rules run on a Wi-Fi scan, not on the connection. Stage 5 uses their results
only when the scan included the access point the phone is connected to (matched by BSSID). Otherwise
`stage1.scan` is not run (no scan included the access point) or inconclusive (the BSSID is
unavailable, belongs to another access point, or the scan is older than 2 minutes).

## Evidence multipliers and aggregation

| Evidence confidence | Multiplier |
| --- | ---: |
| Low | 0.25 |
| Medium | 0.50 |
| High | 0.75 |
| Confirmed | 1.00 |

Unavailable, inconclusive, candidate-only, stale, and untimestamped observations contribute zero.
Points are rounded from `base points × evidence multiplier`. Repeated findings are deduplicated by
session, stage, rule, and check.

Related findings share a session-scoped **incident**. Only the strongest threat finding and the
strongest exposure finding in an incident count. This is how one problem seen by two stages is
counted once:

- An open network is seen by the profile (S1.OPEN_WIFI, 15) and by the scan rules (PRE-11, 12). Both
  are in the Wi-Fi exposure incident, so it counts 15.
- An open copy of a protected network is seen by Stage 2 (RAP-2, 8) and by the scan rules (PRE-12,
  26). Both are in the identity incident, so it counts 26.

Category caps are applied before the global 0–100 cap. Threat caps are 30 for access-point
identity and profile evidence (RAP-* and every PRE-* rule), 40 for DNS/TLS/portal trust evidence,
40 for non-AI traffic evidence, and 10 for AI evidence. Exposure is capped at 100 overall. No benign
finding subtracts points. No independent-source bonus is applied, because the observations do not
yet carry reliable incident-level independence metadata. The final per-finding contributions are
kept in the in-memory assessment, so the displayed score can be reconstructed.

## Rules currently scored

| Observation | Threat | Exposure | Incident | Notes |
| --- | ---: | ---: | --- | --- |
| Open Wi-Fi (S1.OPEN_WIFI) | 0 | 15 | Wi-Fi exposure | Current Stage 1 security observation; link privacy exposure only. |
| WEP security (S1.WEP) | 0 | 26 | Wi-Fi exposure | Only when Stage 1 explicitly reports WEP. |
| RAP-1 security downgrade | 15–26 | 0 | Identity | Strong evidence (user-trusted profile, same BSSID) uses 35 base points at High confidence; an incomplete comparison uses 30 at Medium. Without a trusted profile, RAP-1 compares with security seen on at least 2 earlier connections, always at Medium (15). Same SSID alone is not a malicious verdict. |
| RAP-2 scan-only security discrepancy | 8 | 0 | Identity | 10 base points at High confidence. |
| RAP-3 unfamiliar BSSID alone | 0 | 0 | Identity context | Context only. |
| RAP-4 RSSI anomaly | 0 | 0 | Signal | Repeated-sample validation is not implemented. |
| RAP-5 gateway, DNS, or profile change | 3 | 0 | Profile change | 4 base points at High confidence. Compared with the previous connection, so it lasts for the whole connection. Supporting observation; mainly a reason to refresh Stage 3. |
| RAP-5 same router address, different network behind it | 10 | 0 | Profile change | 20 base points at Medium confidence. The connected BSSID is the previous connection's, but its IPv4 gateway or DNS servers changed. IPv6 is left out (it changes with the provider's prefix), and so are Enterprise and Passpoint networks (certificate-checked, VLANs per user). |
| RAP-6 different internet provider | 15 | 0 | Upstream | 30 base points at Medium confidence. The connection's provider (autonomous system) wasn't seen on any earlier connection to this network, while another one was seen on at least 2. Its own incident, so with RAP-5's same-address finding it reaches 25 (Vulnerable). |
| PRE-1 weak encryption (WEP, or WPA without WPA2/WPA3) | 0 | 15 | Wi-Fi exposure | 20 base points at High confidence. With WEP, S1.WEP (26) wins the incident. |
| PRE-2 WPS enabled | 0 | 0 | Wi-Fi exposure | A risk to the network owner, not to this connection. |
| PRE-3 random (locally administered) MAC | 6 | 0 | Hotspot | 8 base points at High confidence. Phone hotspots use random MACs, but so do some enterprise and mesh access points. Not raised when PRE-8 is. |
| PRE-4 organization-style name on a random MAC | 10 | 0 | Hotspot | 20 base points at Medium confidence. Wins over PRE-3 in the same incident. |
| PRE-5 same name and same MAC seen twice | 26 | 0 | Identity | 35 base points at High confidence. Possible clone. |
| PRE-7 same name from unrelated access points | 0 | 0 | Identity context | Normal for campuses, airports and mesh systems. |
| PRE-8 MAC from a phone maker (Apple, Samsung) | 6 | 0 | Hotspot | 8 base points at High confidence. Also raised for a locally administered MAC whose prefix, with that bit cleared, is a phone maker's (phones derive hotspot addresses that way); PRE-3 is then not raised. |
| PRE-9 "Free" in the name | 1 | 0 | Lure name | 4 base points at Low confidence. |
| PRE-10 hidden name | 0 | 0 | Other | No action needed for a hidden network the user chose. |
| PRE-11 open network | 0 | 12 | Wi-Fi exposure | 16 base points at High confidence, below S1.OPEN_WIFI so the profile's 15 wins. |
| PRE-12 open copy of a password-protected network | 26 | 0 | Identity | 35 base points at High confidence. Classic evil twin; wins over RAP-2 in the same incident. |
| PRE-13 one name and MAC used by two devices | 26 | 0 | Identity | 35 base points at High confidence. The address's security or band switched and switched back within 10 minutes of scans. The same evidence as PRE-5 across scans, so a network gets one of them. |
| PRE-14 known address with different radio hardware | 15 | 0 | Identity | 30 base points at Medium confidence. Compared with the fingerprint saved while connected to this network (Android 11+). Medium, because a replaced or updated router looks the same until its new fingerprint is adopted a day later. |
| PRE-15 signal more than 5 dB stronger while the phone lay still | 3 | 0 | Signal | 12 base points at Low confidence. Only the connected network's access points, only new readings while still, against the strongest earlier reading of that still period. People moving nearby can cause it too. |
| Captive portal / ordinary redirect | 0 | 0 | Portal | Updates connectivity and shows a warning; portal identity and credential handling checks are not implemented. |
| One genuine TLS certificate, hostname, or validity failure | Up to 3 | 0 | TLS | Only when Stage 3 has a validated-network context and a typed certificate validation failure. Timeouts and generic TLS errors score zero. |
| One low-confidence DNS answer mismatch | Up to 5 | 0 | DNS answer | Not evidence of rewriting; repeated multi-name confirmation is not implemented. |
| Candidate TCP port without parsed HTTP | 0 | 0 | Cleartext | Does not establish HTTP or content exposure. |
| Parsed ordinary HTTP request | 0 | Up to 5 | Cleartext | Content sensitivity is unknown; request payloads are not kept. |
| Generic flow model, one attack-like flow | Up to 1 | 0 | Flow AI | A traffic-pattern signal only, never an access-point verdict. |
| Generic flow model, at least three attack-like flows | Up to 3 | 0 | Flow AI | Needs at least three built feature vectors, with rejected vectors no more than half of the built ones, in one capture window. |

PRE-6 (more than 50 networks nearby) is a warning in the network list only. It describes the area,
not the access point, so Stage 5 does not use it.

The AI policy does not keep flow identifiers or correlate separate capture windows. Because the
current model is not validated for rogue-AP detection, it cannot produce a high or critical result
by itself. BENIGN labels never subtract points.

### Worked example: connected to an open copy of a home network

A phone hotspot named `HomeNet` with no password, next to the real password-protected `HomeNet`:

| Incident | Findings | Counted |
| --- | --- | ---: |
| Identity | PRE-12 (26), RAP-2 (8) | threat 26 |
| Hotspot | PRE-3 or PRE-8 (6) | threat 6 |
| Wi-Fi exposure | S1.OPEN_WIFI (15), PRE-11 (12) | exposure 15 |

Threat is 26 + 6 = 32, capped at 30 by the identity cap: ELEVATED. Exposure is 15: GUARDED.

## What the user sees

`VerdictMapper` turns the assessment into one of four levels for the connected network. The
flow model (ML.FLOW) is left out, because it is exploratory.

| Level | When |
| --- | --- |
| Unknown (grey) | No fresh Wi-Fi profile, or nothing was found but coverage is not HIGH. A quiet result from a thin check is not shown as safe. |
| Vulnerable (red) | Threat points of 25 or more (the ELEVATED band). |
| Moderate (amber) | Any smaller threat, or any exposure. Exposure alone never gives Vulnerable: an open network is not a hostile one. |
| Secure (green) | HIGH coverage and no points. The headline is "Nothing suspicious found", never "safe". |

In the worked example the user sees Vulnerable, with the open-copy reason first.

## Unsupported or unimplemented evidence

- Stage 4 does not inspect HTTP headers or bodies for passwords, cookies, tokens, or other sensitive values. Sensitive-data exposure scoring and critical secret-leak findings are therefore unavailable; no payload is stored for scoring.
- The VPN TUN path does not expose ordinary Ethernet ARP frames. Gateway IP-to-MAC conflict scoring remains unavailable.
- Persistent or reproduced DNS manipulation, independent TLS interception confirmation, portal impersonation, and cross-window AI corroboration are not implemented.
- Stage 3 probes are skipped while any VPN is active, including the traffic test, because Manara cannot bind them to the Wi-Fi network underneath. Post-scan therefore runs them before the traffic test.
- Public endpoint blocks, timeouts, no internet, missing permissions, unavailable fields, private resolver addresses, ordinary BSSID changes, and unsupported observations do not raise threat or exposure scores.

Findings stay in memory; first- and last-seen times reflect the source observation kept for each
rule, not a persisted event history.

## The pre-connection list score

The network list shows a separate 0–100 score for every scanned network, from the pre-connection
rules alone (`PreConnectionScanEngine`). It starts at 100 and loses these points; each rule counts
at most once per network:

| Rule | Points |
| --- | ---: |
| PRE-1 weak encryption | 30 |
| PRE-2 WPS enabled | 10 |
| PRE-3 random MAC (unless PRE-8 applies) | 15 |
| PRE-4 organization-style name on a random MAC | 30 |
| PRE-5 same name and same MAC seen twice | 70 |
| PRE-6 more than 50 networks nearby | 0 (warning only) |
| PRE-7 same name from unrelated access points | 10 |
| PRE-8 MAC from a phone maker, directly or with the locally administered bit set | 15 |
| PRE-9 "Free" in the name | 8 |
| PRE-10 hidden name | 10 |
| PRE-11 open network | 30 |
| PRE-12 open copy of a password-protected network | 50 |
| PRE-13 one name and MAC used by two devices (not with PRE-5) | 70 |
| PRE-14 known address with different radio hardware | 50 |
| PRE-15 signal more than 5 dB stronger while the phone lay still | 15 |

The list uses the same bands as the app: 75 or more Secure, 40–74 Moderate, below 40 Vulnerable.
This score describes what an access point broadcasts before joining it. Stage 5 describes the
connection, so for the connected network the two can differ.

## How each stage is started

| Action | Stages it runs |
| --- | --- |
| Scan Now, or opening the connected network's details | 1, 2, 3 (then 5) |
| Check again | 1, 2, 3 (then 5) |
| Pre-scan (network details) | A new Wi-Fi scan and the pre-connection rules for every network in it |
| Post-scan (connected network only) | 1, 2 and 3, then the traffic test (4), then 5 |
| Run traffic test | 4 (then 5) |

Stage 5 also reruns every 30 seconds, so old evidence ages out while a result is on screen.

## Release calibration still required

The weights have not been statistically calibrated. Before release, collect representative
known-good network results and controlled anomaly cases, measure false-positive and detection
rates, check the policy on supported Android versions and devices, evaluate AI-only and combined
cases, and tune the thresholds against a holdout set. The pre-connection base points in particular
were chosen by hand and should be tuned on real public networks. VPN forwarding, network-change, and
live-capture behaviour also remain device-validation tasks.
