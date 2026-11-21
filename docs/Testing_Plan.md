# Manara testing plan

How to test Manara's detection, in three phases, in order:

1. **Checklist** — the on-device walkthrough that already exists.
2. **Rules** — drive every pre-connection and Stage 2/3 rule and confirm the score and verdict.
3. **ML model** — first prove the features are built correctly, then measure real detection in an
   isolated lab.
4. **Non-functional ("performative")** — the seven non-functional requirements: security response
   time, performance, AI accuracy, usability, availability, maintainability and scalability.

Run everything in Phases 2, 3 and 4's security test only on equipment you own, in a lab isolated
from other people's networks and devices. Do not transmit attack or beacon traffic where it can
reach a network you do not control.

The numbers each rule should produce come from [`Stage5_Scoring_Policy.md`](Stage5_Scoring_Policy.md).
Read it alongside this plan: it is the source of truth for points, caps and bands, and this plan
tells you how to make each rule fire on a real device.

Two different scores are involved, and they are not the same thing:

- **List score (0–100 per network):** `PreConnectionScanEngine`, from what a network broadcasts.
  Bands: **75+ Secure, 40–74 Moderate, below 40 Vulnerable.**
- **Connected verdict:** `Stage5AssessmentEngine` → `VerdictMapper`, for the network you are on.
  Levels: **Secure / Moderate / Vulnerable / Unknown.** Vulnerable needs **threat ≥ 25**; exposure
  alone is at most Moderate.

For a network you are connected to, the two can differ. Always write down which one you are
checking.

---

## Phase 1 — Checklist (smoke test)

Use the existing [`Demo_Checklist.md`](Demo_Checklist.md). Treat it as a happy-path smoke test, not
the test plan: it exercises only a subset of rules (PRE-3/4/8/9/11/12, RAP-1, RAP-2) and one benign
traffic test.

Before the device work, run the automated tests. They cover rules you cannot stage live and are the
fallback when a device misbehaves.

```bash
./gradlew :app:testDebugUnitTest
```

```bash
./gradlew :app:connectedDebugAndroidTest
```

The instrumented suite includes `RandomForestDetectorTest`, which confirms the on-device ONNX model
reproduces the reference Python predictions for the bundled samples. If that test fails, stop and
fix it before any ML work in Phase 3 — the model on the phone is not matching the trained model.

**Exit criteria for Phase 1:** unit + instrumented tests green, and the checklist runs end to end on
the real devices.

---

## Phase 2 — Rules

Goal: make each rule fire deliberately, and confirm both the list score and (where the rule feeds
Stage 5) the connected verdict.

### Lab setup

- **A configurable access point** you control: `hostapd` on a Linux laptop or a Raspberry Pi is the
  most flexible, because you can set the SSID, the security mode (Open/WEP/WPA/WPA2/WPA3), WPS,
  hidden SSID and the BSSID. A travel router with a full admin UI also works for most rules.
  Ready-made `hostapd`/`dnsmasq` configs and up/down scripts, with a per-rule change table, are in
  [`lab/`](lab/README.md).
- **A second phone** for the hotspot-based rules (PRE-3/4/8), as in the checklist.
- **Phone A** running the latest `main` build, Location on, Wi-Fi scan throttling off.

For each rule: set up the condition, **write the expected result first** (from the scoring policy),
then scan/connect and compare.

### Pre-connection rules (list score)

Each rule subtracts from 100, at most once per network. Exact penalties and the issue text come from
`PreConnectionScanEngine`.

| Rule | How to stage it | List penalty | Issue text to look for |
| --- | --- | ---: | --- |
| PRE-1 weak encryption | AP set to WEP, or WPA1-only (TKIP, no WPA2/WPA3) | −30 | "Weak Encryption (WPA/WEP)" |
| PRE-2 WPS | Enable WPS on the AP | −10 | "WPS Enabled (Vulnerable)" |
| PRE-3 random MAC | Hotspot from a maker Manara can't tie to a phone, or a privacy address | −15 | "Random MAC Address (Possible Hotspot)" |
| PRE-4 org name on random MAC | Hotspot/AP on a random MAC with an org-style SSID (e.g. `Airport WiFi`, `City Hotel`) | −30 | "Hotspot network + Organization-like SSID (Possible Spoofed Network)" |
| PRE-5 same name **and** MAC twice | Two scan entries, same SSID and BSSID (see caveat) | −70 | "Duplicate Network Name & MAC Address Detected" |
| PRE-6 >50 networks | 50+ networks in range | 0 (warning) | "more than 50 networks nearby" |
| PRE-7 same name, unrelated MACs | Two APs, same SSID, BSSIDs far apart (> 5 numeric) | −10 | "Same Name Broadcast by Unrelated Devices" |
| PRE-8 phone-maker MAC | Samsung/Apple/Nothing hotspot (incl. locally-administered bit set) | −15 | "Mobile Hotspot Detected (Samsung)", "(Apple)" or "(Nothing)" |
| PRE-9 "Free" in name | SSID containing `free` | −8 | "SSID Contains 'Free' (Possible Bait Network)" |
| PRE-10 hidden name | Hidden SSID | −10 | "Hidden SSID" |
| PRE-11 open network | Open AP (no password); OWE is **not** open | −30 | "Open Network (No Encryption)" |
| PRE-12 open copy of protected | Open AP with the same SSID as a nearby password-protected one | −50 | "Open Copy of a Protected Network (Possible Evil Twin)" |
| PRE-13 address used by two devices | A clone on the real AP's BSSID with different security, band or hardware, both on air (see caveat) | −70 | "Router Address Used by Two Devices (Possible Evil Twin)" |
| PRE-14 different hardware on a known address | A clone on the BSSID of an AP Manara saved while connected (Android 11+) | −50 | "Router Address With Different Hardware (Possible Evil Twin)" |
| PRE-15 signal jump while still | Phone on a table, connected; an AP of that network gets > 5 dB stronger than its strongest reading since the phone settled | −15 | "Signal Rose While the Phone Was Still" |

Notes while testing:

- **PRE-3 vs PRE-8 are mutually exclusive.** A network gets one, never both. A Samsung/Apple hotspot
  takes PRE-8 (−15); any other random MAC takes PRE-3 (−15). Confirm the **Maker** line in Basic
  info names the maker for PRE-8 and says **Randomized** for PRE-3.
- **PRE-1 security parsing** is in `Stage2SecurityNormalizer`. A bare `WPA-PSK` (no `WPA2`/`RSN`)
  reads as legacy WPA and triggers PRE-1; `WPA2`/`RSN` does not. Set the AP mode precisely.
- **PRE-5 (clone) may not be stageable live.** Android usually keeps one scan entry per BSSID, so a
  real clone and the original collapse into one. Try once with a hostapd clone on a duplicated
  BSSID; if PRE-5 never fires on-device, record that and rely on the unit test. (It's listed in the
  checklist's "Can't be shown live".)
- **PRE-13 is that clone seen across scans.** With the hostapd clone on the real AP's BSSID, make
  it open (or put it on the other band) and leave both on for a few minutes. The single entry has
  to switch, then switch back, within 10 minutes (`SharedAddressMonitor.WINDOW_MICROS`), so it
  needs at least three scans that include the BSSID, Android's own included. Changing one AP's
  security once must **not** fire it, nor must a 5 GHz channel change. If Android always shows
  the same one of the two, it can't fire; record that and rely on the unit tests.
- **PRE-14 needs a saved fingerprint first.** Connect to the real AP with a fresh scan (Android
  11+) so Manara saves its fingerprint, then bring up the hostapd clone on its BSSID with the
  same SSID, security and band, and scan. Expect −50 and a warning naming what differs (Wi-Fi
  generation, capability elements, maker fields). Restarting the real AP or changing its channel
  must not fire it.
- **PRE-15 needs the phone still.** Lay Phone A flat on a table, connected, and leave it for two
  scans (Android's own scans while the screen is on, or a pull to scan). Then bring the AP, or a phone
  hotspot serving the network, closer so its signal rises by more than 5 dB on the next scan.
  Expect −15 and "rose from X to Y dBm". The same jump while holding the phone must not fire it.

### Connected-network rules (Stage 2/3 → verdict)

These need Phone A **connected** to the staged network. Open the connected network's details (runs
Stages 1→2→3→5).

**RAP-1 trusted-profile downgrade.** In the connected network's details, **Trust this network**
(Trust section, below the connection check) while on the protected network. Then reconfigure the
same SSID to weaker security (e.g. drop the password) and reconnect.
- Same BSSID as the trusted profile, now open → strong evidence, **26 threat → Vulnerable.**
- Different/missing BSSID → incomplete, **15 threat → Moderate.**
- The downgrade ladder is in `materiallyWeaker`: WPA3→WPA2→WPA→WEP→Open each count as weaker.

**RAP-1 without trust (security history).** Don't trust the network. Connect to the protected
network on 2 separate connections (reconnect, or force-stop and reopen Manara, in between), then
drop the password and reconnect.
- Weaker than a mode seen on ≥ 2 earlier connections → Medium confidence, **15 threat → Moderate**,
  reason "weaker than on your earlier connections". The Trust section offers **Trust the new
  settings**; after confirming, RAP-1 compares with the trusted open profile and clears.
- Seen on only 1 earlier connection → RAP-1 stays inconclusive (no points).
- On Android 10/11 the security comes from the connected AP's scan result (Advanced Detection → Stage 1
  shows the source "Wi-Fi scan"). If the latest scan doesn't include the AP, security is
  unavailable and RAP-1 and trusting wait; tap **Scan Now**.

**RAP-2 same-name security discrepancy.** Two live APs with the same SSID, one protected and one
open, with Phone A on one of them. Needs a **fresh scan** (< ~30 s; throttling off). Contributes
**8 threat**, but when the open copy is the connected AP, PRE-12 (26) wins the shared identity
incident, so the verdict is driven by PRE-12.

**RAP-3 new BSSID for a known SSID.** Connect, let the baseline record, then move Phone A to a
second AP broadcasting the same SSID (different BSSID). Context only — **0 points**, diagnostic.

**RAP-5 profile change.** After a baseline exists, change the gateway/DNS/security and reconnect.
It compares with the previous connection, so it shows for the whole connection, not just its
first reading.
- A change on another AP of the network (roaming) → **3 threat**, "Network profile changed".
- **Same BSSID as the previous connection, new IPv4 gateway or DNS** (e.g. change the AP's LAN
  subnet, or a clone on the real AP's BSSID with its own DHCP) → **10 threat, Moderate**, "Same
  router address, different network behind it". IPv6-only DNS changes and Enterprise/Passpoint
  networks must stay at the plain change.

**RAP-6 different internet provider.** Connect to a network on 2 separate connections (reconnect
or restart Manara in between) so its provider is learned. Then serve the same SSID from a hotspot
whose uplink is another provider, e.g. Phone B on mobile data, and join it. Manara looks the
provider up once per connection, after Android validates internet (no portal, no VPN).
- Provider never seen on this network, another seen on ≥ 2 connections → **15 threat, Moderate**,
  naming both providers.
- With RAP-5's same-address finding as well → **25, Vulnerable**.
- A provider seen on at least one earlier connection (a café with two lines) → no finding.
- Advanced Detection → Stage 2 shows RAP-6 as "not applicable" until 2 connections exist, and inconclusive
  until the lookup has run.

**RAP-4** is disabled in code (`RAP4_ENABLED = false`) — expect "not applicable", no points.

### Stage 3 probes — the ones to scrutinise

These are the "theoretical" detections that need the closest reading, because in practice they top
out low:

- **TLS interception (H2.1).** Manara verifies TLS to `www.google.com/generate_204` using Android's
  system trust store only (both a public untrusted CA and a user-installed CA should fail
  verification). Key points to verify:
  - Best case is **3 threat → Moderate.** It can never reach Vulnerable (DNS/TLS/portal cap is 40,
    but the base is 12 × 0.25 = 3).
  - It only scores while Android still reports the network as **validated** and **no captive
    portal** (`ConnectivityTrustRules`/`Stage5`). Interception that breaks validation makes Manara
    report **inconclusive / 0**, not a threat.
  - Test procedure: connect, let Android validate, **then** enable interception, then **Check
    again**. Record whether you see the 3 points or an inconclusive result — both are findings about
    the design, not just the test.
- **DNS answer mismatch (H5.2).** Manara compares the system resolver against Cloudflare DoH for
  **`example.com`** only. To trigger, redirect that name on your lab resolver. Requirements:
  - Set the phone's **Private DNS to Off**, or Android may bypass the lab resolver.
  - Needs validated internet + no captive portal to even run.
  - Caps at **5 threat → Moderate.**
- **Captive portal (H3.1).** Scores **0** by design. Verify the message and connectivity state, not
  a score.

### False-positive baseline (do not skip)

The scoring policy explicitly says the weights still need benign-network calibration. For a scanner,
false alarms matter as much as detection.

- Scan and connect on several **ordinary** networks: a home router, a campus/eduroam network, a
  café. Record the list score and the connected verdict for each.
- Expected: real home/campus networks land **Secure/Moderate**, not Vulnerable; a legitimate open
  café network is **Moderate** (exposure), never Vulnerable.
- Any benign network that reaches Vulnerable is a false positive worth filing against the weights.

### Background checks and alerts

Turn on Settings → **Background checks** and allow location **All the time** (and notifications).
Settings must read "On". Close Manara (Home) for each case: no check runs while it's on screen.
Follow the worker with `adb logcat -s BackgroundCheck`. To run a check now, turn Background checks
off and on, then press Home within 45 seconds: the network you're on gets a check. (Forcing the
hourly job early with `cmd jobscheduler run` doesn't work: WorkManager just reschedules it.)

| Case | Do | Expect |
| --- | --- | --- |
| Network change | Join a protected network with Manara closed. | A check about 45 s later; no notification for an ordinary network. |
| First check, harmless finding | Join a phone hotspot (PRE-8, 6 points). | No notification: findings under 8 points never alert. |
| New suspicious finding | Join the open copy of a protected network (PRE-12). | "Something suspicious on HomeNet" with the PRE-12 reason, within about a minute. |
| Score drop | A network whose next check scores ≥ 20 lower, or falls below 40. | "HomeNet's score dropped", from the old score to the new. |
| Quiet period | Repeat a case for the same network within 6 h. | No second notification, unless the new one is more serious (red level after a score drop). |
| Daily cap | Cause alerts on 4 different networks in a day. | The 4th is dropped, unless it's the red level. |
| Missing permission | Set location back to "While using the app". | Settings shows *Needs location "Allow all the time"* with **Allow**; the log shows the check skipped. |
| Turned off | Turn Background checks off. | No more checks, and network changes don't start one. |

The alert rules themselves (new findings, drops, quiet period, daily cap) are covered by
`BackgroundAlertPolicyTest`.

### Language

- Settings → **Language** → **العربية**. The screen reopens in Arabic, right to left: the tabs, a
  network's details (findings, verdict, advice), the radar and the Settings tab. Advanced
  Detection's cards stay in English by design.
- A background check alert and a nearby warning arrive in Arabic too.
- **Phone's language** follows the phone; **English** returns everything to English.

---

## Phase 3 — ML model

Two sub-phases, in order: **(A) features accurate**, then **(B) real detection**. Do not interpret
detection results until A passes, or you will blame the model for a measurement problem.

### How Manara captures traffic (read this first)

The constraints below shape every ML test:

- The Stage 4 VPN (`VpnCaptureService`) routes **only IPv4**, with no per-app filter, so it sees
  every app's outbound connections. It establishes `10.77.0.1/32` with a default `0.0.0.0/0` route
  and **no IPv6**, so IPv6 is blocked during the 30-second test and apps fall back to IPv4.
- It only sees connections an app **on the phone** opens. Traffic another device sends *to* the
  phone (a scan or flood aimed at the phone, ARP spoofing) arrives on the Wi-Fi interface and never
  enters the VPN, so the model never sees it.
- Reply packets are **rebuilt by zdtun**, not taken from the wire (`send_client_callback` in
  `vpn_bridge.c`). Forward (phone→server) packets are the app's real packets; backward packets'
  sizes/timing/flags come from zdtun. Of the 28 features (`FlowFeatureBuilder.FEATURE_NAMES`): 7 are
  forward-only (real), 6 are backward-only (zdtun), and 15 mix both directions (including all five
  flag counts), so most features depend at least partly on zdtun.
- Flows close on FIN-both/RST or a **5-second idle timeout**, and all open flows are flushed when
  the capture stops.

### A. Feature accuracy

Prove the 28 features Manara builds match what the training pipeline (CICFlowMeter-style) would
compute for the same traffic.

1. On the lab server, capture the same session with `tcpdump` and run it through CICFlowMeter (or
   your training pipeline) to get reference feature vectors.
2. On the phone, read Manara's built vectors from **Settings → Advanced Detection → Stage 4** ("Flow vectors: N built…")
   and `Log.d` output (`adb logcat`, tag `VpnCaptureService` / `FlowFeatureBuilder`).
3. Compare **forward-only features separately from backward-only features.**
   - Forward-only (Total Fwd Packets, Fwd lengths/IAT/rate, Destination Port) should match closely.
   - Backward-only (the six Bwd features) are the ones zdtun can distort — expect and quantify any
     gap here.
   - Mixed features (duration, Flow IAT, packet-length stats, flag counts, Flow Bytes/Packets/s)
     inherit any backward distortion.

**Pass criterion:** forward features match within tolerance; you have a documented, quantified
explanation (zdtun) for any backward/mixed deviation. A high **rejected-vector** count
(`FeatureBuildRejection`) is a feature-builder problem, not a detection result — resolve it here.

### B. Real detection

The question: does the model actually detect attacks, or is it decorative?

Because the VPN only sees flows the phone **originates**, put the phone in the attacker role against
a lab target you own, on the isolated subnet. This matches CICIDS2017's orientation, where the
labelled flows come from the attacking host — exactly the classes a phone can generate as the
source:

| CICIDS2017 class | Generate from Phone A, during the 30 s window, against your lab host | Model should flag |
| --- | --- | --- |
| Port scan | connect/SYN scan of the lab host | the scan flows |
| DoS (slow) | slow-header / slow-body load on your lab web server | the many half-open flows |
| DoS (flood) | high-rate request loop on your lab web server | the request flows |
| Brute force | repeated login attempts to your lab SSH/FTP | the auth flows |
| **Benign (control)** | ordinary browsing + Manara's own test requests | **nothing** |

Run each class **twice**, with two capture paths, to separate "bad model" from "bad capture":

1. **Rooted capture from the Wi-Fi interface** (e.g. a root libpcap helper / PCAPdroid root mode) —
   real packets, including attacks aimed at the phone. This removes the zdtun distortion and is the
   fairest test of the model itself.
2. **Manara's own VPN capture** — what users actually get, with the zdtun caveat.

**Record per run** (counts are in Advanced Detection → Stage 4: vectors built, vectors rejected, attack vs
benign labels):

| Run | Capture path | Flows generated | Attack-labelled | Benign-labelled | Rejected | Detection rate | Notes |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| | | | | | | | |

Compute:
- **Detection rate** = attack-labelled ÷ attack flows generated, per class.
- **False-positive rate** = attack-labelled flows during the benign control run (target ≈ 0).

Interpretation:
- Misses attacks **even with rooted capture** → the **model** is weak for this use.
- Catches with root but misses through the VPN → the **capture path** (zdtun / phone-origin limit)
  is the problem, not the model.
- Keep this separate from the app's verdict: even perfect detection is capped at **≤ 3 threat** and
  is left out of the user verdict (`VerdictMapper` drops `ML.FLOW`). This phase measures the model's
  raw quality, not its effect on the score.

---

## Phase 4 — Non-functional ("performative") testing

This phase covers the seven non-functional requirements from Table 6 of the project's requirements
document. The targets are the team's; this plan says how to measure each one against Manara **as it
is actually built**, and flags where a target assumes something the app does not do.

Measure on a real device (the demo Galaxy S21), on the latest `main` build, Location on, scan
throttling off. Record the device model and Android version with every number — CPU, memory and
radio behaviour all vary by device.

### 4.1 Security — threat response time

**Target:** detect and alert for an Evil Twin (and, later, deauthentication) in under 10 seconds.

- **Evil Twin / rogue AP — measurable now.** Manara detects this (PRE-12, and the connected-network
  verdict). It is **scan-driven and pull-based**, so define the clock precisely: start it when a
  Wi-Fi scan that includes the rogue AP completes (or when you tap **Scan Now** with throttling
  off), and stop it when the warning/verdict appears. Measure from `adb logcat` timestamps or a
  screen recording.
  - **Caveat to record:** without scan throttling off, Android allows only 4 scans per 2 minutes,
    so the real-world latency depends on when the next scan is permitted, not on Manara's speed. The
    phone-to-phone "nearby warning" path is separate and can take up to ~1 minute to propagate; test
    and report it on its own, not against the 10-second target.
- **Deauthentication — kept as a target, not yet supported.** The current build has **no deauth
  detection**: stock Android does not expose 802.11 management frames to an app, so there is no way
  to see a deauth frame without root, monitor mode and a capable chipset. Keep this row as planned
  work. When it is implemented, test it in the isolated lab by running the deauth tooling your Table
  6 names against your own AP and measuring detection latency the same way. For this build, record
  the result as **"not yet supported"** rather than a time.

**Pass:** the Evil-Twin alert appears within the target once a scan including the rogue AP runs, with
the clock definition stated; deauth recorded as pending.

### 4.2 Performance

**Target:** CPU < 40% average during scanning, RAM < 300 MB, AI analysis < 4 s, warning display
< 7 s.

**Tools (Android, not desktop):** Android Studio Profiler for CPU and memory, `adb shell dumpsys
meminfo com.wss.manara` for PSS, `adb shell top -m 10` for live CPU, and Perfetto for a full trace.
(The table's "CPU-Z / Activity Monitor" are desktop tools — Activity Monitor is macOS — so swap
them out.)

Define each measurement against what the code actually does:

| Metric | How to measure | Note from the code |
| --- | --- | --- |
| CPU < 40% avg | Average over a full scan + Stage 1–3 cycle | Rule engines are pure Kotlin; expect low CPU except during the traffic test |
| RAM < 300 MB | PSS from `dumpsys meminfo` at rest and during a scan | ONNX Runtime loads the model on first inference; measure during the traffic test too |
| AI analysis < 4 s | Per-flow model inference latency (log timestamps around `RandomForestDetector.predict`) | This is milliseconds per flow. It is **not** the traffic test, which is a fixed **30 s** window (`MAX_CAPTURE_MS`) by design — don't score the 30 s as a performance failure |
| Warning display < 7 s | Time from scan completion to the verdict/warning rendered | Stages 1, 2, 3 and 5 are fast; the 30 s traffic test is Stage 4 only and is excluded from this metric |

**Pass:** all four targets met, with the 30-second capture window called out as a design constant,
not a latency failure.

### 4.3 Reliability — AI accuracy (ML flow model on a test set)

**Target:** false-positive rate < 7% and false-negative rate < 7%, measured on the **Random Forest
flow model** against a held-out CICIDS2017 test set.

1. Build a held-out test set from CICIDS2017 that the model did **not** train on, with hundreds of
   labelled flows per class (far more than the 3 bundled `rf_android_test_sample_*.json` files).
2. Run it two ways and confirm they agree:
   - **On-device**, by extending `RandomForestDetectorTest` with the larger sample set, so the
     numbers are from the real ONNX model on the phone.
   - **Off-device**, with the same ONNX model, for fast bulk scoring.
3. Build the confusion matrix and compute **FPR = FP / (FP + TN)** and **FNR = FN / (FN + TP)**.

**Caveats to state next to the numbers:**
- This measures the model **in isolation** on lab-distribution data, which is an **upper bound**.
  Phase 3's live capture will do worse because of the zdtun reply packets and the phone-origin
  limit. Report this reliability figure separately from Phase 3's live detection rate.
- The flow model is experimental and is **excluded from the user verdict** (`VerdictMapper` drops
  `ML.FLOW`), so this number describes the model, not Manara's decisions.

**Pass:** FPR and FNR both < 7% on the held-out set, reported as a model-only figure.

### 4.4 Usability

**Target:** a new user can understand and use the app within 8–10 minutes, unaided.

- Recruit 8–10 participants who have not seen Manara. Give them the app with no walkthrough.
- Set a few core tasks: run a scan, open a network and read its verdict, find a flagged network,
  open History. Record time-to-first-successful-task and where people hesitate or misread a term
  (e.g. "Unknown" vs "Secure", the experimental AI note).
- Collect a short questionnaire (a SUS form works well) and free-text feedback.

**Pass:** the median participant completes the core tasks within the target, with the usability
issues logged for follow-up.

### 4.5 Availability

Reframe this for an app that does its core work **on the device**:

- **Core scanner (scan, score, five-stage check, ML):** runs fully **offline**. Put the phone in a
  state with Wi-Fi but no internet and confirm scanning and verdicts still work. This is the part
  that must be "always available".
- **Backend features (sign-in, online dangerous-network reports, cloud backup):** depend on
  Firebase. "Works in Qatar" means Google Play services and Firebase are reachable; confirm on a
  Qatar network. "No single point of failure" is **not** true for these — Firebase is the single
  dependency — so the real test is **graceful degradation**: block Firebase (airplane mode, or deny
  the app network) and confirm the app shows a clear message (e.g. "Couldn't reach your backup")
  and keeps the on-device features working, rather than crashing.

**Pass:** core scanning works with no internet; backend features fail soft with a clear message, and
the Firebase dependency is documented as the known single point for online features.

### 4.6 Maintainability

**Target:** a new feature can be added within 3 weeks.

- Measure from history, not a lab test: track the actual time for one or two representative changes
  (an issue or PR from start to merge).
- Back it with a short structure review: the rule engines are pure-Kotlin, unit-tested, and separated
  by Clean Architecture, which is what makes a bounded change feasible. Note any area that is harder
  to change (the native VPN bridge, the ONNX integration).

**Pass:** a representative change lands within the target, with the architectural reasons recorded.

### 4.7 Scalability — design review only

Manara has **no server of its own**, so there is no endpoint for JMeter and "1000 concurrent users"
is not a load test you can run directly. Assess it by architecture instead:

- **On-device work scales per device.** Scanning, scoring, the five stages and the ML model all run
  locally, so per-user load is constant regardless of how many users exist. There is nothing to
  contend for.
- **Firebase is the only shared resource.** Its scaling is Google-managed and bounded by the
  project's quotas and by `firestore.rules` (one report per user per network, format validation).
- **Point to examine:** the online dangerous-network reports are keyed by router address (BSSID),
  with a shared `reportCount` on each network's document. Check whether many users reporting the
  **same** network at once would contend on that single document, since Firestore limits sustained
  writes per document. If so, note it as the scaling risk and a design item (e.g. sharded counters),
  rather than a pass/fail number.

**Pass:** a written scaling analysis that separates per-device work (scales freely) from the Firebase
dependency, and identifies any Firestore write-contention risk. No load test is run.

---

## What "pass" means overall

- **Phase 1:** automated tests green; checklist runs on device.
- **Phase 2:** every rule fires on cue with the scored points/verdict from the policy; the
  design-limited rules (fraudulent-CA/TLS → Moderate at best, DNS → Moderate at best, PRE-5 maybe
  not live) are documented with what you actually observed; benign networks do not reach Vulnerable.
- **Phase 3:** features validated (forward exact, backward/zdtun gap quantified); detection and
  false-positive rates recorded per class for both capture paths, with a defensible conclusion on
  whether the model earns its place.
- **Phase 4:** each non-functional target measured with the right tool and the result recorded,
  including the honest ones — Evil-Twin response time with a stated clock (deauth pending),
  performance with the 30-second capture called out as a design constant, model FPR/FNR as a
  model-only figure, offline availability with graceful Firebase degradation, and scalability as a
  written design review rather than a load test.
