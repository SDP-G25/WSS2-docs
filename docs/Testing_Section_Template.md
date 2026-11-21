# Testing and evaluation — section template

> **How to use this template.** It is written as Section 8 of the report. Replace every
> `[bracketed]` item with the real value or result, then delete these grey note blocks.
> Facts that are already known (rule penalties, test counts, app messages, design constants) are
> filled in. They come from the code at commit `edcbea7`, so update them if the code changes.
> Table and figure numbers are `[N]`, so Word's captions can number them. What is still needed is
> listed in [`Testing_Section_Requirements.md`](Testing_Section_Requirements.md).

---

# 8. Testing and evaluation

In semester 1 we tested the use cases implemented at that time. In semester 2 we completed the
testing of the whole solution: all five use cases (UC01–UC05), the supporting features (saved
networks, cloud backup, background checks, language), and the seven non-functional requirements of
Section 3.2.

Functional testing was done at four levels:

- **unit testing** of the rule engines and view logic,
- **integration testing** of the components that only work together on a device (the packet
  pipeline, the native VPN bridge, the ONNX model, storage and Firebase),
- **system testing** of every use case on real phones, including a controlled Wi-Fi lab, and
- **acceptance testing** against each use case's post-conditions with end users.

Every test case is specified in Appendix B. The tests were run on build `[commit hash]`
(`[date]`) on the devices in Table [N].

**Table [N]: Test environment**

| Item | Details |
| --- | --- |
| Phone A (main test device) | Samsung Galaxy S21 (SM-G991B), Android 15 (API 35), Wi-Fi RTT: [yes/no] |
| Phone B (second device) | [Model], Android [version], Wi-Fi RTT: [yes/no] |
| Other devices (availability tests) | [Model, Android version], [Model, Android version] |
| Build under test | `main` at `[commit hash]`, debug build, `[date]` |
| Lab access point | Linux laptop ([distribution]) with a [chipset] 802.11ac USB adapter running `hostapd` and `dnsmasq` (configuration in the repository's `docs/lab/`) |
| Real networks used | [N] networks: [home, Qatar University, café, mall, …] |
| Unit / integration tools | JUnit 4, MockK, Turbine, kotlinx-coroutines-test, AndroidX Test, Espresso |
| Measurement tools | Android Studio Profiler, `adb shell dumpsys meminfo`, `adb shell top`, Perfetto, `adb logcat` |
| ML evaluation tools | Python [version], ONNX Runtime [version], the CICIDS2017 held-out test set |
| Backend tools | Firebase console (Firestore, Authentication), [Firebase emulator, if used] |
| Testers | [Names], between [start date] and [end date] |

---

## 8.1 Functional testing

### 8.1.1 Unit testing

Most of Manara's security logic is in pure Kotlin rule engines with no Android dependency:
`PreConnectionScanEngine`, `AccessPointIdentityRules`, `ConnectivityTrustRules`,
`Stage5AssessmentEngine` and `VerdictMapper`. This let us unit-test every rule, including cases
that cannot be recreated with real hardware, such as two scan entries with the same name and the
same router address (PRE-5). Collaborators were replaced with MockK mocks, and coroutine and Flow
behaviour was tested with kotlinx-coroutines-test and Turbine. The tests are run with
`./gradlew :app:testDebugUnitTest`.

The suite has **355 unit tests in 46 test classes**. Table [N] groups them by the use case they
verify.

**Table [N]: Unit tests by use case**

| Use case | Test classes (number of tests) | Tests |
| --- | --- | ---: |
| UC01 Pre-connection scanning | `PreConnectionScanEngineTest` (25), `NetworkGroupsTest` (14), `ScanActionsTest` (9), `SharedAddressMonitorTest` (9), `SecurityLabelTest` (8), `ScanQuotaTest` (7), `StillSignalMonitorTest` (7), `RadioFingerprintsTest` (5), `BasicInfoTest` (4), `GetScannedNetworksUseCaseTest` (4), `StillnessDetectorTest` (3), `RadioFingerprintMapperTest` (2), `LocationAccessTest` (2) | 99 |
| UC02 Post-connection scanning | `AccessPointIdentityRulesTest` (28), `Stage5AssessmentEngineTest` (25), `VerdictMapperTest` (25), `ConnectivityTrustRulesTest` (21), `ObservableTrafficAnalyzerTest` (10), `ConnectedNetworkTest` (7), `NetworkTrustTest` (7), `TrafficTestMapperTest` (7), `SecurityHistoryTest` (4), `UpstreamProviderParsingTest` (4), `ProviderHistoryTest` (3), `Stage4TrafficSnapshotTest` (3), `CaptureTrafficGeneratorTest` (2) | 146 |
| UC03 Locate access point (radar) | `ApRadarViewModelTest` (15), `NextReadingTest` (6), `SelectAccessPointForLocateUseCaseTest` (6), `RadarGeometryTest` (5), `MeasurementSourceTest` (4), `RttProbeTest` (4), `LocateDirectionTest` (3), `EstimateDistanceUseCaseTest` (2), `RttSupportTest` (2), `ObserveNearbyAccessPointsUseCaseTest` (1) | 48 |
| UC04 P2P warnings | `NearbyWarningRulesTest` (8), `NearbyReportsTest` (3) | 11 |
| UC05 Online reports | `CommunityReportRulesTest` (9) | 9 |
| Supporting features | `SaveNetworkUseCaseTest` (10), `SavedNetworkRulesTest` (10), `BackgroundAlertPolicyTest` (7), `LightCharacteristicTest` (6), `ThemeModeTest` (5), `CloudBackupManagerTest` (2), `SavedNetworkActionsTest` (2) | 42 |
| **Total** | **46 classes** | **355** |

Examples of what these tests verify:

- **Each pre-connection rule fires once, with its exact penalty.** For example, a WPA-only network
  loses 30 points (PRE-1), and an open network named like a protected one nearby loses 50 more
  (PRE-12). A rule is never counted twice for the same network.
- **The clone case, and the rules that catch it on a real phone.** Two scan entries with the same
  SSID and BSSID get PRE-5 (−70). On a real phone, though, Android merges entries that share a
  BSSID, so a perfect copy appears as a single entry. Three rules were added to catch it anyway:
  PRE-13 flags an address that keeps switching between two security modes, bands or radio
  fingerprints within a few minutes (−70); PRE-14 flags an address whose radio fingerprint (Wi-Fi
  generation, radio capabilities and chip-maker codes) differs from the one saved when the user
  connected (−50); and PRE-15 flags a sudden signal rise while the phone lies still (−15). Unit
  tests cover each rule, including the 24-hour window that stops a firmware update from being
  flagged.
- **The security-downgrade ladder (RAP-1).** WPA3 → WPA2 → WPA → WEP → Open each count as weaker
  than the trusted profile.
- **The AI model has its own card.** On a connected network's details, the AI model's result
  appears in a separate **Traffic Test** card, next to the connection check card that holds the
  rule-based verdict (Secure / Moderate / Vulnerable). After an optional 30-second test, the card
  reports how many connections the model checked and how many looked unusual, for example "The
  model checked 24 connections. None looked unusual." The two are kept apart on purpose: the model
  was trained on CICIDS2017, a lab dataset of network attacks, not on public Wi-Fi traffic, so
  adding its result to the score could raise false alarms on safe networks and would make the
  verdict harder to explain. Showing it on its own card gives the user the model's view without
  weakening the rules. Unit tests check both sides: the card's wording for each model result,
  and that the model's result stays on its card and doesn't change the verdict.
- **Score bands.** 75–100 maps to Secure, 40–74 to Moderate and 0–39 to Vulnerable.

**Results.** On 20 November 2026, on commit `edcbea7`, **all 355 tests passed**: 0 failures,
0 errors and 0 skipped, in 2.9 seconds of test time (Figure [N]). This means that every rule,
score and piece of view logic in these classes gives the expected result for every case tested,
including the cases that can't be staged with real hardware. Unit tests can't show that Android
gives the app these inputs on a real phone; Sections 8.1.2 and 8.1.3 cover that.

> Figure [N]: screenshot of the Gradle test report
> (`app/build/reports/tests/testDebugUnitTest/index.html`) showing the totals.

[Optional: the unit tests cover [N]% of the lines in the `domain` package (JaCoCo report,
Figure [N]).]

### 8.1.2 Integration testing

Integration tests check that components work together on a real device. They run with
`./gradlew :app:connectedDebugAndroidTest`, or by hand where the test spans two phones or
Firebase.

**Table [N]: Integration tests**

| ID | Components integrated | Method | Expected | Actual | Pass/Fail |
| --- | --- | --- | --- | --- | --- |
| IT-01 | IPv4 packet parser on raw packets | `Ipv4PacketParserTest` (6 tests, on device) | TCP and UDP packets parsed with their ports and TCP flags; non-IPv4, truncated and bad-header-length packets rejected; a non-first fragment gets no invented ports | As expected (6 of 6) | Pass |
| IT-02 | Packet parser → flow aggregator | `FlowAggregatorTest` (4 tests) | Packets in both directions join one flow and RST ends it; a new flow starts after the idle timeout; fragments are skipped; flushing returns and clears all flows | As expected (4 of 4) | Pass |
| IT-03 | Flow aggregator → feature builder | `FlowFeatureBuilderTest` (4 tests) | Exactly 28 CICFlowMeter-style features, in the order the model expects; flows with one packet, zero duration or inconsistent packet counts rejected | As expected (4 of 4) | Pass |
| IT-04 | Feature vector → ONNX Runtime → Random Forest model | `RandomForestDetectorTest` (1 test, 3 sample flows) | On the phone, the model gives the same probabilities as the Python model (within 0.0001), the same label unless the prediction is a tie, and probabilities that sum to 1 | As expected (1 of 1) | Pass |
| IT-05 | Kotlin → JNI → native zdtun bridge | `ZdtunNativeTest` (1 test) | The native library loads through JNI and zdtun initializes | As expected (1 of 1) | Pass |
| IT-06 | DataStore + Android Keystore (saved networks) | [New instrumented test / manual] | Saved data round-trips; decrypting with another user ID fails | [result] | [P/F] |
| IT-07 | App → Firestore security rules | [Firebase emulator / console Rules Playground] | Valid report accepted; duplicate report, invalid BSSID and writes to another user's data rejected | [result] | [P/F] |
| IT-08 | Phone A → Nearby Connections → Phone B | Two phones, manual | Warning delivered, validated and stored in Phone B's History | [result] | [P/F] |
| IT-09 | App → Firebase Authentication → cloud backup | Two phones, one account, manual | Saved networks and settings restored on the second phone | [result] | [P/F] |

**Results.** On 20 November 2026, on commit `7963998`, the five automated integration tests
(IT-01 to IT-05, **16 tests**) **all passed** on a Samsung Galaxy S21 (SM-G991B) running
Android 15, with 0 failures, 0 errors and 0 skipped (Figure [N]). This means that the capture
pipeline works end to end on a real phone. Raw packets are parsed and grouped into flows, each flow
is turned into the 28 features in the right order, the model on the phone scores them exactly as
the Python model does, and the native VPN bridge loads.

IT-04 shows that the model on the phone *matches* the Python model. It does not show that the model
is accurate: one of its three samples (`A54`) is a real attack that the model scores 50/50, which
the test treats as a tie. Accuracy is measured separately in Section 8.2.3.

Of the four manual integration tests (IT-06 to IT-09), [N] passed. This means that [the storage
and Firebase integrations enforce their rules / describe any failure].

> Figure [N]: screenshot of the instrumented test report
> (`app/build/reports/androidTests/connected/debug/index.html`) showing 16 tests passed on
> SM-G991B.

### 8.1.3 System testing

System tests run each use case end to end on a real phone, through the user interface. There is
one test case for each main success scenario and for each alternative flow in Appendix A. The full
step-by-step specification of each test case is in Appendix B. The tables below summarise them.

For detection we used a controlled Wi-Fi lab. A Linux laptop ran `hostapd` with an 802.11ac USB
adapter, so the network name, security mode, WPS, hidden name and router address (BSSID) could be
set exactly. A second phone provided real phone hotspots. All lab networks were our own, at low
transmit power, and turned off after each test.

#### 8.1.3.1 UC01 — Start pre-connection scanning

**Table [N]: UC01 test cases**

| Test case | Scenario | Expected result | Actual result | Pass/Fail |
| --- | --- | --- | --- | --- |
| TC-01-01 | Main flow: pull the Networks list down to scan | Nearby networks listed with a score of 0–100 and a label; the connected network pinned at the top with a **Connected** badge; networks with the same name grouped; details show the issues | [result] | [P/F] |
| TC-01-02 | 4.a Location permission not granted | Manara asks for location; choosing **Precise** allows the scan | [result] | [P/F] |
| TC-01-03 | 4.b Location services off | The lighthouse shows a broken beam ("Location is off") and asks to turn location on; no scan results | [result] | [P/F] |
| TC-01-04 | 4.c Scan throttling on (more than 4 scans in 2 minutes) | **Pre-scan** reports that Android didn't run a new scan; the last results stay | [result] | [P/F] |
| TC-01-05 | 8.a A network scores below 40 | Classified **Vulnerable**, with its issues shown | [result] | [P/F] |
| TC-01-06 | 8.b Sharing or online reporting on | A network below 40 is shared with nearby phones (UC04) and/or reported online (UC05) | [result] | [P/F] |
| TC-01-07 | Rule by rule in the lab (Table [N]) | Each PRE rule gives the expected issue and score | [result] | [P/F] |
| TC-01-08 | Real-network baseline (Table [N]) | Legitimate networks are not classified Vulnerable | [result] | [P/F] |

For TC-01-07, each rule was triggered on its own by changing one setting of the lab access point.
Rules PRE-13 to PRE-15 compare scans over time, so they were staged as described in the testing
plan.

**Table [N]: Pre-connection rules in the lab (score starts at 100)**

| Rule | How it was staged | Penalty | Expected issue | Expected score / label | Actual score / label | Pass/Fail |
| --- | --- | ---: | --- | --- | --- | --- |
| — | Baseline: WPA2-Personal, registered BSSID | 0 | none | 100 / Secure | [ ] | [ ] |
| PRE-1 | WPA1 with TKIP only | −30 | "Weak Encryption (WPA/WEP)" | 70 / Moderate | [ ] | [ ] |
| PRE-2 | WPS enabled | −10 | "WPS Enabled (Vulnerable)" | 90 / Secure | [ ] | [ ] |
| PRE-3 | Locally administered BSSID (`02:…`) | −15 | "Random MAC Address (Possible Hotspot)" | 85 / Secure | [ ] | [ ] |
| PRE-4 | Random BSSID + SSID `City Hotel` | −30 (+ PRE-3) | "Hotspot network + Organization-like SSID (Possible Spoofed Network)" | 55 / Moderate | [ ] | [ ] |
| PRE-5 | Same SSID and BSSID seen twice | −70 | "Duplicate Network Name & MAC Address Detected" | 30 / Vulnerable — **unit test only** (Android keeps one entry per BSSID) | [ ] | [ ] |
| PRE-6 | More than 50 networks nearby | warning | "more than 50 networks nearby" | unchanged | [ ] | [ ] |
| PRE-7 | Two APs, same SSID, unrelated BSSIDs | −10 | "Same Name Broadcast by Unrelated Devices" | 90 / Secure | [ ] | [ ] |
| PRE-8 | Phone hotspot from Samsung, Apple or Nothing | −15 | "Mobile Hotspot Detected ([maker])" | 85 / Secure | [ ] | [ ] |
| PRE-9 | SSID `Free Lab WiFi` | −8 | "SSID Contains 'Free' (Possible Bait Network)" | 92 / Secure | [ ] | [ ] |
| PRE-10 | Hidden SSID | −10 | "Hidden SSID" | 90 / Secure | [ ] | [ ] |
| PRE-11 | Open network | −30 | "Open Network (No Encryption)" | 70 / Moderate | [ ] | [ ] |
| PRE-12 | Open copy of our WPA2 network | −50 (+ PRE-11, PRE-7) | "Open Copy of a Protected Network (Possible Evil Twin)" | 10–20 / Vulnerable (the copy) | [ ] | [ ] |
| PRE-13 | Clone on the real AP's BSSID with different security or band | −70 | "Router Address Used by Two Devices (Possible Evil Twin)" | 30 / Vulnerable | [ ] | [ ] |
| PRE-14 | Clone on the BSSID of an AP saved while connected (Android 11+) | −50 | "Router Address With Different Hardware (Possible Evil Twin)" | 50 / Moderate | [ ] | [ ] |
| PRE-15 | Connected AP gets > 5 dB stronger while the phone lies still | −15 | "Signal Rose While the Phone Was Still" | 85 / Secure | [ ] | [ ] |

[N] of the 15 rules gave the expected issue and score. This means that [Manara's pre-connection
analysis flags every condition it was designed to detect / rule `[PRE-x]` did not fire because
`[reason]`, which we `[fixed in commit … / recorded as a limitation]`]. In particular, the open
Evil Twin copy (PRE-12) scored [score], **Vulnerable**, before any device joined it. This shows
that Manara warns about the attack in Section 1.1 *before* the user connects.

**Table [N]: Real-network baseline (false-positive check)**

| Network (type) | Security | Pre-connection score / label | Connected verdict | Issues reported | Reasonable? |
| --- | --- | --- | --- | --- | --- |
| [Home router] | [WPA2] | [ ] | [ ] | [ ] | [Yes/No] |
| [Qatar University (eduroam)] | [WPA2-Enterprise] | [ ] | [ ] | [ ] | [ ] |
| [QU guest] | [ ] | [ ] | [ ] | [ ] | [ ] |
| [Café, open] | [Open] | [ ] | [ ] | [ ] | [ ] |
| [Mall] | [ ] | [ ] | [ ] | [ ] | [ ] |
| [Phone hotspot] | [ ] | [ ] | [ ] | [ ] | [ ] |
| [… at least 10 networks] | | | | | |

[N] of the [N] legitimate networks were classified Vulnerable. This means that
[Manara does not raise false alarms on ordinary networks / the false positives on `[network]` were
caused by `[rule]`, which we discuss in Section 8.3].

#### 8.1.3.2 UC02 — Start post-connection scanning

**Table [N]: UC02 test cases**

| Test case | Scenario | Expected result | Actual result | Pass/Fail |
| --- | --- | --- | --- | --- |
| TC-02-01 | Main flow: **Post-scan** on a legitimate network with internet | "Post-scan: checking the connection (stages 1–3)...", then "running the traffic test (stage 4, about 30 seconds)...", then "Post-scan finished. All five stages ran…"; verdict **Secure, "Nothing suspicious found."** with the checks completed and a separate AI result | [result] | [P/F] |
| TC-02-02 | 4.a Not connected to Wi-Fi | **Post-scan** is not available | [result] | [P/F] |
| TC-02-03 | 6.a Connectivity checks can't finish (lab AP without internet) | Missing evidence recorded, coverage lower; **Unknown**, "Manara couldn't check enough to judge this network" | [result] | [P/F] |
| TC-02-04 | 7.a VPN permission denied | No traffic test; verdict from the other stages, traffic stage "not run", lower coverage | [result] | [P/F] |
| TC-02-05 | 7.b Another VPN active | [As in UC02: the traffic test can't run until the other VPN is off / record what Android does: it may ask to replace the other VPN] | [result] | [P/F] |
| TC-02-06 | 11.a Results out of date (no check for about 2 minutes) | The connection check turns grey, **Unknown** | [result] | [P/F] |
| TC-02-07 | 11.b Connected to the open Evil Twin copy (lab) | **Vulnerable, "This network may not be what it claims. Avoid using it."**, first reason: "A nearby network with this name has a password, but the one you're connected to doesn't…" | [result] | [P/F] |
| TC-02-08 | Special: the AI result doesn't decide the verdict | The AI result is shown separately and marked experimental (trained on CICIDS2017); the verdict doesn't change with it | [result] | [P/F] |
| TC-02-09 | Special: no packet payloads stored | App storage holds no packet contents after a traffic test; only flow statistics | [result] | [P/F] |
| TC-02-10 | Connected-network rules in the lab (Table [N]) | Each RAP rule and Stage 3 probe gives the expected result | [result] | [P/F] |

**Table [N]: Connected-network rules and probes in the lab**

| Rule / probe | How it was staged | Expected | Actual | Pass/Fail |
| --- | --- | --- | --- | --- |
| RAP-1 (trusted) | Trust the WPA2 network, then remove its password and reconnect (same BSSID) | 26 threat → **Vulnerable**, "This network's security is weaker than when you marked it as trusted." | [ ] | [ ] |
| RAP-1 (history) | Connect twice with WPA2 (no trust), then remove the password | 15 threat → **Moderate**, "…weaker than on your earlier connections to it." | [ ] | [ ] |
| RAP-2 | Two live APs, same SSID, one protected, one open | 8 threat (PRE-12 dominates when on the open one) | [ ] | [ ] |
| RAP-3 | Move to a second AP with the same SSID, different BSSID | Context only, 0 points | [ ] | [ ] |
| RAP-4 | (disabled in code) | "Not applicable", 0 points | [ ] | [ ] |
| RAP-5 | Same BSSID as the previous connection, new gateway or DNS | 10 threat → **Moderate**, "Same router address, different network behind it" | [ ] | [ ] |
| RAP-6 | Same SSID served from a hotspot on another internet provider | 15 threat → **Moderate**, naming both providers (25 → **Vulnerable** together with RAP-5) | [ ] | [ ] |
| Captive portal (HTTP 204) | Lab portal on `connectivitycheck.gstatic.com/generate_204` | Portal reported; 0 points by design | [ ] | [ ] |
| TLS certificate check | Interception with an untrusted certificate, after Android validates | 3 threat → **Moderate**, or inconclusive if validation breaks | [ ] | [ ] |
| DNS consistency | Lab DNS answers `example.com` differently from Cloudflare DNS over HTTPS (Private DNS off) | 5 threat → **Moderate** | [ ] | [ ] |

[N] of the 10 connected-network checks gave the expected result. This means that [describe].
Connecting to the open copy of our network (TC-02-07) was classified [verdict], which means that
[Manara also protects a user who has already joined an Evil Twin / describe what was lacking].

#### 8.1.3.3 UC03 — Locate access point using radar

**Table [N]: UC03 test cases**

| Test case | Scenario | Expected result | Actual result | Pass/Fail |
| --- | --- | --- | --- | --- |
| TC-03-01 | Main flow: **Locate** → move → **Exit** | Radar opens for the chosen AP with a distance estimate, the method used (signal strength or Wi-Fi RTT) and guidance ("Turn slowly, then walk toward the signal."); **Exit** closes it and stops scanning | [result] | [P/F] |
| TC-03-02 | 5.a Wi-Fi RTT not supported | Distance from signal strength, and the method shown as signal strength | [result] | [P/F] |
| TC-03-03 | RTT supported (phone and router support 802.11mc) | Distance from Wi-Fi RTT, updated about every 1.5 s | [result] | [P/F] |
| TC-03-04 | 5.b Scan throttling | The next reading waits until Android allows a scan | [result] | [P/F] |
| TC-03-05 | 7.a Not enough signal history | No direction yet; guidance asks the user to turn slowly | [result] | [P/F] |
| TC-03-06 | 8.a AP turned off during the radar | No new reading for that AP | [result] | [P/F] |

**Table [N]: Radar distance accuracy (tape-measured, line of sight)**

| True distance | Signal-strength estimate | Error | Wi-Fi RTT estimate | Error |
| ---: | ---: | ---: | ---: | ---: |
| 1 m | [ ] m | [ ] m | [ ] m | [ ] m |
| 3 m | [ ] | [ ] | [ ] | [ ] |
| 5 m | [ ] | [ ] | [ ] | [ ] |
| 10 m | [ ] | [ ] | [ ] | [ ] |
| 15 m | [ ] | [ ] | [ ] | [ ] |

The mean error was [X] m from signal strength and [X] m from Wi-Fi RTT. This means that
[RSSI-based distance is approximate, as UC03's special requirements state, and RTT is accurate
enough to walk to the router / RTT could not be tested because no available router supports
802.11mc].

#### 8.1.3.4 UC04 — Share and receive P2P security warnings

**Table [N]: UC04 test cases**

| Test case | Scenario | Expected result | Actual result | Pass/Fail |
| --- | --- | --- | --- | --- |
| TC-04-01 | Main flow: Phone A finds a network below 40 | Settings on both phones: "On. Connected to 1 nearby phone with Manara."; Phone B gets "[SSID] may be unsafe"; Phone B's History → **Warnings From Nearby Phones** lists it with "Not checked by your phone."; Phone A's History → **Warnings You Shared** lists it | [result] | [P/F] |
| TC-04-02 | 7.a No network below 40 | No warning sent | [result] | [P/F] |
| TC-04-03 | 8.a No other Manara phone nearby | Nothing delivered | [result] | [P/F] |
| TC-04-04 | 10.a Malformed or outdated warning | Rejected by the receiver (verified by `NearbyWarningRulesTest`, as it can't be crafted through the app) | [result] | [P/F] |
| TC-04-05 | 10.b Sender exceeds 50 messages | Further warnings from that sender ignored (unit test) | [result] | [P/F] |
| TC-04-06 | 11.a Notifications not allowed on Phone B | Warning stored in History with no notification | [result] | [P/F] |
| TC-04-07 | 11.b Relay: A → B → C → D → E | Received by B, C and D (3 hops), not by E | [result] | [P/F] |
| TC-04-08 | Special: the same network on the same day | Shared once a day only | [result] | [P/F] |
| TC-04-09 | Special: received warnings don't change scores | Phone B's own score for that network is unchanged | [result] | [P/F] |
| TC-04-10 | Special: works without internet | Both phones in airplane mode with Bluetooth and Wi-Fi on; warning still delivered | [result] | [P/F] |

[N] of 10 passed. The warning reached the second phone in [X] seconds on average (n = [N]). This
means that [nearby users are warned without any internet connection / describe].

#### 8.1.3.5 UC05 — Report dangerous networks online

**Table [N]: UC05 test cases**

| Test case | Scenario | Expected result | Actual result | Pass/Fail |
| --- | --- | --- | --- | --- |
| TC-05-01 | Main flow: signed-in Phone A, reporting on, network below 40 | Details show "You reported this network to Manara's shared list..."; Firestore `dangerousNetworks` has a document named after the BSSID with `reportCount: 1`; another account near it sees "Reported as dangerous by 1 Manara user" | [result] | [P/F] |
| TC-05-02 | 7.a Network scores 40 or more | Not reported | [result] | [P/F] |
| TC-05-03 | 9.a No internet | The report isn't submitted; [record what the app shows or whether it retries] | [result] | [P/F] |
| TC-05-04 | 10.a Same user, same network again | Rejected; `reportCount` stays 1 | [result] | [P/F] |
| TC-05-05 | 10.b Invalid BSSID | Rejected by the Firestore rules (Rules Playground or emulator) | [result] | [P/F] |
| TC-05-06 | 13.a No reports for a network | No community count shown | [result] | [P/F] |
| TC-05-07 | 13.b Report older than 7 days | Expired; not counted (unit test, or timestamp changed in the console) | [result] | [P/F] |
| TC-05-08 | Special: not signed in / default state | Reporting is off by default and needs sign-in; local scores never change because of reports | [result] | [P/F] |

[N] of 8 passed. This means that [describe].

#### 8.1.3.6 Supporting features

**Table [N]: Supporting-feature test cases**

| Test case | Feature | Expected result | Actual result | Pass/Fail |
| --- | --- | --- | --- | --- |
| TC-S-01 | Save a network (signed in) | **Save** becomes **Unsave**; the network is listed in History → **Saved Networks** | [result] | [P/F] |
| TC-S-02 | Cloud backup and restore | "Saved networks and settings are backed up to this account."; after signing in on Phone B with the same account, the saved network and theme appear | [result] | [P/F] |
| TC-S-03 | Unsave | "… removed from your saved networks."; doesn't return after signing out and in | [result] | [P/F] |
| TC-S-04 | Background check alert (Manara closed, joins the open copy) | "Something suspicious on [SSID]" within about a minute; no repeat within 6 hours | [result] | [P/F] |
| TC-S-05 | Background check, harmless network | No notification | [result] | [P/F] |
| TC-S-06 | Arabic | Settings → Language → العربية: the app reopens right to left, with translated findings and advice | [result] | [P/F] |
| TC-S-07 | Advanced Detection | A card per stage with the raw findings, rule by rule | [result] | [P/F] |

### 8.1.4 Acceptance testing

Acceptance testing checked each use case against its post-conditions (Appendix A) with
[N] end users and [the project supervisor]. Each user did the use case without help, and we
recorded whether every post-condition held.

**Table [N]: Acceptance criteria and results**

| Use case | Acceptance criteria (from the post-conditions) | Accepted by | Result |
| --- | --- | --- | --- |
| UC01 | Nearby networks displayed; each has a score and label; issues shown; same names grouped | [N/N users] | [Accepted / Not accepted] |
| UC02 | Five-stage check runs; verdict and reasons shown; AI result separate; coverage shown | [ ] | [ ] |
| UC03 | Radar shows distance, method and direction; stops on exit | [ ] | [ ] |
| UC04 | Warning delivered to nearby phones and stored in History; scores unchanged | [ ] | [ ] |
| UC05 | Report stored online; other users see the count; scores unchanged | [ ] | [ ] |

All [N] use cases were accepted. This means that [the delivered system meets the functional
requirements as end users experience them / UC0x was not accepted because …].

### 8.1.5 ML model on live traffic (experimental)

The on-device Random Forest analyses the flows captured in the 30-second traffic test. Manara's VPN
only sees IPv4 flows that the phone itself starts. The native forwarder also rebuilds the reply
packets, which changes most of the backward-direction features. We therefore tested the model on
live traffic separately from its test-set accuracy (Section 8.2.3), by generating attack-like
traffic from the phone in our isolated lab and comparing two captures of the same traffic:
Manara's VPN and a full packet capture.

**Table [N]: Live detection results**

| Traffic type | Flows | Flagged by Manara (VPN capture) | Flagged on the full capture | Notes |
| --- | ---: | ---: | ---: | --- |
| Normal browsing | [N] | [N] ([%]) | [N] ([%]) | [ ] |
| [Attack-like traffic type 1] | [N] | [N] ([%]) | [N] ([%]) | [ ] |
| [Attack-like traffic type 2] | [N] | [N] ([%]) | [N] ([%]) | [ ] |

The model flagged [X]% of the attack-like flows and [X]% of the normal flows. This means that
[the model adds a useful signal / the model does not detect these attacks on live traffic, which is
why Manara presents it as experimental and leaves it out of the verdict].

### 8.1.6 Defects found and fixed

**Table [N]: Defect log**

| ID | Found by | Description | Fix (commit) | Retest |
| --- | --- | --- | --- | --- |
| D-01 | [TC-xx-xx] | [What went wrong] | [`commit` — what changed] | [Pass] |
| D-02 | [ ] | [ ] | [ ] | [ ] |
| D-03 | [ ] | [ ] | [ ] | [ ] |

Testing found [N] defects, and [N] were fixed and retested. The [N] remaining ones are
[listed in Section 8.3 as limitations].

### 8.1.7 Discussion of functional results

[N] of [N] test cases passed. The tests show that [summary: all five use cases work end to end;
every pre-connection rule fires in the lab; the Evil Twin copy is flagged before and after
connecting]. What is lacking:

- **PRE-5** can't be shown live, because Android keeps one scan entry per BSSID, so it is verified
  by unit tests only. The same attack is covered live by PRE-13 and PRE-14 (Table [N]).
- **The ML model** [result from 8.1.5].
- [Any failed test case and its reason.]

---

## 8.2 Non-functional testing

### 8.2.1 Security (data protection)

**Target:** saved network data is encrypted with AES-GCM, and the keys are managed by the Android
Keystore.

**Method.** We inspected the code, then checked the stored data on the device.

- **Code inspection.** `SavedNetworkCipher` encrypts each user's saved networks with
  **AES-256-GCM** (`AES/GCM/NoPadding`): a fresh 12-byte IV per write and a 128-bit authentication
  tag. The **user ID is bound as associated data**, so one user's data can't be decrypted as
  another's. The key (`manara_saved_networks_key`) is generated inside the **Android Keystore**,
  so the key material never leaves it. The file is excluded from Android backups.
- **On the device.** On a debug build we read the DataStore file `manara_saved_networks` with
  `adb shell run-as com.wss.manara`, after saving a network named `[test SSID]`.

**Results.** The stored value was [Base64 ciphertext; the SSID `[test SSID]` did not appear in the
file] (Figure [N]). Decrypting with another user ID [failed with an authentication error]. This
means that the data-protection target was **[met / not met]**.

**Scope.** Manara stores no account passwords: Firebase Authentication keeps its own sign-in
token. Other local data are not encrypted: the received-warnings table, network baselines,
settings and background-check state. They hold [no credentials; describe what they hold].

### 8.2.2 Performance

**Targets:** average CPU below 40% during scanning, RAM below 300 MB, and ONNX model inference
below 4 seconds.

**Method.** Phone [model], build `[commit]`, scan throttling off. We measured CPU with the Android
Studio Profiler and `adb shell top`, and memory (PSS) with
`adb shell dumpsys meminfo com.wss.manara`. Inference time was taken from log timestamps around
each model call. Each scenario was repeated [N] times.

**Table [N]: Performance results**

| Metric | Scenario | Target | Measured (mean ± SD, n = [N]) | Met? |
| --- | --- | --- | --- | --- |
| CPU | Pre-scan (scan + rules) | < 40% | [X]% ± [X] | [Yes/No] |
| CPU | Post-scan (stages 1–5, including the 30 s traffic test) | < 40% | [X]% ± [X] | [ ] |
| RAM (PSS) | At rest, Networks tab | < 300 MB | [X] MB | [ ] |
| RAM (PSS) | During the traffic test (model loaded) | < 300 MB | [X] MB | [ ] |
| Inference time | Per flow | < 4 s | [X] ms | [ ] |
| Inference time | All flows of one traffic test ([N] flows) | < 4 s | [X] ms | [ ] |

The traffic test always lasts **30 seconds**. That is a fixed capture window by design, not
processing time, so it isn't counted as inference time. The results mean that the performance
target was **[met / not met]**: [describe, for example "peak CPU of X% only during …"].

> Figure [N]: Profiler CPU and memory graph over one post-scan.

### 8.2.3 Reliability (AI accuracy)

**Targets:** false-negative rate below 7% and false-positive rate below 7%.

**Method.** We tested the bundled Random Forest model (`CICIDS2017_RandomForest_model.onnx`,
28 features) on a held-out CICIDS2017 test set that it did not train on: [N] benign flows and
[N] attack flows. We ran the same samples through the model on the phone (an extended
`RandomForestDetectorTest`) and through ONNX Runtime in Python, and checked that the labels
matched.

**Table [N]: Confusion matrix (held-out test set)**

| | Predicted benign | Predicted attack |
| --- | ---: | ---: |
| **Actual benign** | TN = [N] | FP = [N] |
| **Actual attack** | FN = [N] | TP = [N] |

- **False-positive rate** = FP / (FP + TN) = [X]% (95% CI [X]–[X]%)
- **False-negative rate** = FN / (FN + TP) = [X]% (95% CI [X]–[X]%)
- Phone and Python labels agreed on [N] of [N] samples.

**Repeatability.** Running the same [N] samples [N] times gave identical labels in [all] runs, so
the model makes the same decision from the same data.

The FPR of [X]% and FNR of [X]% mean that the reliability target was **[met / not met]**. This
figure describes the model on lab data, which is an upper bound. On live traffic the model does
worse (Section 8.1.5), and it is excluded from the user's verdict.

### 8.2.4 Usability

**Target:** a new user can understand and use Manara within 8–10 minutes, without guidance.

**Semester 1 survey (previous interface).** 21 testers used the app and answered a survey:

- 90% found the interface "Extremely easy" or "Somewhat easy" to navigate, with no negative
  answers.
- 67% reached their destination in two clicks or fewer, and 29% needed two to four.
- 95% found the layout intuitive without a tutorial.
- 67% said the buttons behaved as expected; 33% met some confusion.
- 91% rated speed and responsiveness "Excellent" or "Good".

> Keep Figures [N]–[N] (the survey charts) from the semester 1 draft here.

**Semester 2 timed test (current interface).** The survey did not measure time, so we ran a timed
test on the redesigned app. [N] participants who had not used Manara before did four tasks with no
help: (1) scan and find the most dangerous network, (2) open a network and explain its verdict,
(3) run a post-scan on the connected network, (4) find a warning in History. We timed each
participant and noted where they hesitated.

**Table [N]: Timed usability results**

| Participant | Time to finish all tasks | Tasks finished unaided | Hesitations / comments |
| --- | ---: | ---: | --- |
| P1 | [mm:ss] | [N/4] | [ ] |
| P2 | [ ] | [ ] | [ ] |
| … P[N] | | | |
| **Median** | **[mm:ss]** | | |

[Optional: mean SUS score [X] / 100.]

The median time of [X] minutes means that the usability target was **[met / not met]**.
[Describe the main issues found, for example "Unknown" being mistaken for "Secure", and what we
changed.]

### 8.2.5 Availability

**Target:** core scanning and assessment work without internet and without cloud services, on
different Android devices.

**Table [N]: Availability results**

| Test | Expected | Actual | Met? |
| --- | --- | --- | --- |
| Wi-Fi on, no internet (lab AP without uplink): scan | Networks scored as normal | [ ] | [ ] |
| Same, open a network's details | Rules and verdict shown; checks that need internet marked as not run, verdict possibly **Unknown** | [ ] | [ ] |
| Airplane mode with Wi-Fi on | Scanning works | [ ] | [ ] |
| Firebase unreachable (signed in) | Clear message (for example "Couldn't reach your backup"); no crash; local features work | [ ] | [ ] |
| Device matrix: [Model / Android version] × [N] | Installs, scans and assesses | [ ] | [ ] |

This means that the availability target was **[met / not met]**. Online features (sign-in, online
reports, backup) depend on Firebase, which is their single point of failure. They fail with a
clear message instead of stopping the app.

### 8.2.6 Maintainability

**Target:** a new feature can be added within 3 weeks.

**Method.** From the git history, we measured the time from the first commit to the merge for
representative features added this semester.

**Table [N]: Time to add features**

| Feature | First commit | Merged | Duration | Within 3 weeks? |
| --- | --- | --- | ---: | --- |
| [Arabic language support] | [date] | [date] | [N] days | [Yes/No] |
| [Background checks and alerts] | [ ] | [ ] | [ ] | [ ] |
| [Wi-Fi RTT discovery for unadvertised routers] | [ ] | [ ] | [ ] | [ ] |
| [Unsaving networks] | [ ] | [ ] | [ ] | [ ] |

All [N] features were added within [N] days, so the maintainability target was **[met / not
met]**. The design explains this: the rule engines are pure Kotlin with unit tests, and Clean
Architecture keeps each change local. The native VPN bridge and the ONNX integration are the
hardest parts to change.

### 8.2.7 Scalability

**Assessment by design review.** Manara has no server of its own, so there is no endpoint to
load-test.

- **On-device work scales with the number of phones.** Scanning, scoring, the five-stage check and
  the AI model all run on each phone, so the load per user stays the same however many users there
  are.
- **Firebase is the only shared resource.** Google scales it, within the project's quotas and the
  limits set in `firestore.rules`.
- **One risk.** Online reports are stored as one Firestore document per BSSID, with a shared
  `reportCount`. Firestore allows about one sustained write per second per document, so many users
  reporting the **same** network at once would be slowed down. [Sharded counters would remove this
  limit / we accept it because reports of one network are rare.]

This means that Manara scales with its number of users, apart from the per-network report count
described above.

### 8.2.8 Summary of non-functional results

**Table [N]: Non-functional requirements — targets and results**

| Requirement | Target | Measured | Met? | Comment |
| --- | --- | --- | --- | --- |
| Security (data protection) | AES-GCM encryption, Keystore keys | [AES-256-GCM, ciphertext on disk] | [Yes/No] | [ ] |
| Performance — CPU | < 40% average | [X]% | [ ] | [ ] |
| Performance — RAM | < 300 MB | [X] MB | [ ] | [ ] |
| Performance — inference | < 4 s | [X] ms | [ ] | [ ] |
| Reliability — FPR | < 7% | [X]% | [ ] | [Model only, on test data] |
| Reliability — FNR | < 7% | [X]% | [ ] | [ ] |
| Usability | 8–10 min unaided | median [X] min | [ ] | [ ] |
| Availability | Core features offline, several devices | [ ] | [ ] | [ ] |
| Maintainability | New feature < 3 weeks | [X] days (max) | [ ] | [ ] |
| Scalability | Design review | Per-device work; one Firestore hotspot | [ ] | [ ] |

---

## 8.3 Overall evaluation: was the problem solved?

The problem was that users can't tell whether a Wi-Fi network is safe before connecting, which
exposes them to Evil Twin and man-in-the-middle attacks (Section 1.1). Table [N] links each project
objective to the tests that show it was achieved.

**Table [N]: Objectives and evidence**

| Objective (Section 1.2) | Evidence | Achieved? |
| --- | --- | --- |
| Wi-Fi scanning module that collects network data | TC-01-01, unit tests for UC01 | [Yes / Partly / No] |
| Pre-connection analysis that spots rogue access points | Lab results (Table [N]): PRE-12 to PRE-14 flag the Evil Twin before joining | [ ] |
| A clear risk score for each network | TC-01-07, score bands verified | [ ] |
| Real-time alerts | TC-S-04 (background alerts), TC-04-01 (nearby warnings) | [ ] |
| P2P warnings without the cloud | TC-04-01, TC-04-10 (works offline) | [ ] |
| A user-friendly interface | Section 8.2.4 | [ ] |
| Tested on different networks for reliability, performance and accuracy | Table [N] (real networks), Sections 8.2.2 and 8.2.3 | [ ] |

**What is lacking, and why.**

- **Deauthentication detection** isn't implemented. Stock Android doesn't give apps 802.11
  management frames, so it would need root and monitor mode.
- **The AI model is experimental.** It was trained on CICIDS2017 lab traffic, sees only flows the
  phone starts, and works on rebuilt reply packets. [Live result from Section 8.1.5.] For this
  reason it is reported separately and never decides the verdict.
- **The scores are hand-tuned heuristics, not probabilities.** The real-network baseline
  (Table [N]) is a first calibration; more public networks are needed.
- **Android limits** affect timing: 4 scans every 2 minutes unless throttling is off, one every
  30 minutes in the background, and Doze can delay background checks.
- [Any requirement marked "not met" above, with its reason.]

[Concluding paragraph: overall degree to which the requirements were satisfied.]

---

# Appendix B – Test cases specification

> One table per test case, in the course format. The five main-success test cases are drafted
> below. Copy the format for each alternative-flow test case in Section 8.1.3 (TC-01-02 …
> TC-05-08, TC-S-01 … TC-S-07).

### TC-01-01

| Test case # | TC-01-01 | Associated use case ID | UC01 |
| --- | --- | --- | --- |
| Test designed by | [Name] | Test design date | [DD/MM/YYYY] |
| Executed by | [Name] | Execution date | [DD/MM/YYYY] |
| Test case name | Start pre-connection scanning | | |
| Short description | Scan nearby networks and check that each one is scored, labelled and grouped correctly | | |

**Pre-conditions:** Location on and allowed (Precise); Wi-Fi on; scan throttling off; the lab AP
`ManaraLab` broadcasting WPA2 (baseline); Phone A connected to `[home network]`.

| Step | Test step | Expected system response | Actual result | Pass/Fail | Comment |
| ---: | --- | --- | --- | --- | --- |
| 1 | Open Manara on the Networks tab | The network list is shown | [ ] | [ ] | |
| 2 | Pull the list down to scan | A new scan runs | [ ] | [ ] | |
| 3 | Look at the connected network | Pinned at the top with a **Connected** badge and a score | [ ] | [ ] | |
| 4 | Find `ManaraLab` | Score **100, Secure**, no issues | [ ] | [ ] | |
| 5 | Find an open network | **OPEN** badge, score 70 or lower | [ ] | [ ] | |
| 6 | Open `ManaraLab`'s details | Score, label, Basic info (Maker) and an empty issues list | [ ] | [ ] | |
| 7 | Tap **Pre-scan** | "Pre-scan: scanning nearby networks...", then "Pre-scan finished. The score and issues above come from a new scan." | [ ] | [ ] | |
| 8 | Check post-condition 1 | | | | |

**Post-conditions:** 1. Every nearby network is displayed with a score (0–100) and a label
(Secure 75–100, Moderate 40–74, Vulnerable 0–39), its issues are shown, and networks with the same
name are grouped.

### TC-02-01

| Test case # | TC-02-01 | Associated use case ID | UC02 |
| --- | --- | --- | --- |
| Test designed by | [Name] | Test design date | [DD/MM/YYYY] |
| Executed by | [Name] | Execution date | [DD/MM/YYYY] |
| Test case name | Start post-connection scanning | | |
| Short description | Run all five stages on a legitimate connected network | | |

**Pre-conditions:** Phone A connected to `ManaraLab` (WPA2, with internet); VPN permission already
granted; no other VPN active.

| Step | Test step | Expected system response | Actual result | Pass/Fail | Comment |
| ---: | --- | --- | --- | --- | --- |
| 1 | Tap the connected network | Details open with a **Connection check** section, "Manara finished N of M checks" | [ ] | [ ] | |
| 2 | Tap **Post-scan** | "Post-scan: checking the connection (stages 1–3)..." | [ ] | [ ] | |
| 3 | Wait | "…running the traffic test (stage 4, about 30 seconds)...", with a key icon in the status bar | [ ] | [ ] | |
| 4 | Wait about 30 s | "Post-scan finished. All five stages ran, and the connection check above shows the result." | [ ] | [ ] | |
| 5 | Read the verdict | **Secure, "Nothing suspicious found."**, with the checks completed | [ ] | [ ] | |
| 6 | Read the traffic test | "The model checked about 20–30 connections. None looked unusual.", marked experimental | [ ] | [ ] | |
| 7 | Settings → **Advanced Detection** | One card per stage with the raw findings; Stage 4 shows the flow vectors built | [ ] | [ ] | |
| 8 | Check post-conditions 1–2 | | | | |

**Post-conditions:** 1. All five stages ran and a verdict with its reasons and coverage is shown.
2. The AI result is shown separately and didn't decide the verdict.

### TC-03-01

| Test case # | TC-03-01 | Associated use case ID | UC03 |
| --- | --- | --- | --- |
| Test designed by | [Name] | Test design date | [DD/MM/YYYY] |
| Executed by | [Name] | Execution date | [DD/MM/YYYY] |
| Test case name | Locate access point using radar | | |
| Short description | Open the radar for one AP, walk toward it, then exit | | |

**Pre-conditions:** Location and Wi-Fi on; Nearby devices permission granted (Android 13+); the
lab AP visible.

| Step | Test step | Expected system response | Actual result | Pass/Fail | Comment |
| ---: | --- | --- | --- | --- | --- |
| 1 | Open the AP's details and tap **Locate** | The radar opens for that AP | [ ] | [ ] | |
| 2 | Read the distance | A distance estimate, and the method (signal strength or Wi-Fi RTT) | [ ] | [ ] | |
| 3 | Turn slowly in place | Guidance "Turn slowly, then walk toward the signal."; then a direction | [ ] | [ ] | |
| 4 | Walk toward the AP | The distance goes down as new readings arrive | [ ] | [ ] | |
| 5 | Tap **Exit** | The radar closes | [ ] | [ ] | |
| 6 | Check post-condition 1 | | | | |

**Post-conditions:** 1. The radar showed distance and direction for the selected AP, and scanning
stopped on exit.

### TC-04-01

| Test case # | TC-04-01 | Associated use case ID | UC04 |
| --- | --- | --- | --- |
| Test designed by | [Name] | Test design date | [DD/MM/YYYY] |
| Executed by | [Name] | Execution date | [DD/MM/YYYY] |
| Test case name | Share and receive P2P security warnings | | |
| Short description | Phone A finds a dangerous network and warns Phone B without internet | | |

**Pre-conditions:** Both phones: Bluetooth, Wi-Fi and location on; **Share warnings anonymously**
on; Nearby devices and notification permissions granted. Lab: the open copy of `ManaraLab` is
broadcasting. The network hasn't been shared today.

| Step | Test step | Expected system response | Actual result | Pass/Fail | Comment |
| ---: | --- | --- | --- | --- | --- |
| 1 | Open Settings on both phones | "On. Connected to 1 nearby phone with Manara." (can take up to a minute) | [ ] | [ ] | |
| 2 | Phone A: pull down to scan | The open copy scores below 40, **Vulnerable** | [ ] | [ ] | |
| 3 | Phone B: wait | Notification "ManaraLab may be unsafe" | [ ] | [ ] | |
| 4 | Phone B: History → **Warnings From Nearby Phones** | The network with its score and "Not checked by your phone." | [ ] | [ ] | |
| 5 | Phone A: History → **Warnings You Shared** | The network is listed | [ ] | [ ] | |
| 6 | Phone B: scan the same network | Phone B's own score, not changed by the warning | [ ] | [ ] | |
| 7 | Check post-conditions 1–3 | | | | |

**Post-conditions:** 1. The warning was delivered to the nearby phone. 2. It is stored in History.
3. The receiver's own score for the network didn't change.

### TC-05-01

| Test case # | TC-05-01 | Associated use case ID | UC05 |
| --- | --- | --- | --- |
| Test designed by | [Name] | Test design date | [DD/MM/YYYY] |
| Executed by | [Name] | Execution date | [DD/MM/YYYY] |
| Test case name | Report dangerous networks online | | |
| Short description | A signed-in user's dangerous network is reported, and another user sees the report | | |

**Pre-conditions:** Phone A signed in, internet available, **Report dangerous networks online**
on; Phone C signed in with a different account; `firestore.rules` published; the open copy of
`ManaraLab` is broadcasting.

| Step | Test step | Expected system response | Actual result | Pass/Fail | Comment |
| ---: | --- | --- | --- | --- | --- |
| 1 | Phone A: pull down to scan | The open copy scores below 40 | [ ] | [ ] | |
| 2 | Phone A: open its details | "You reported this network to Manara's shared list..." | [ ] | [ ] | |
| 3 | Firebase console → Firestore → `dangerousNetworks` | A document named after the copy's BSSID, `reportCount: 1` | [ ] | [ ] | |
| 4 | Phone C: scan near the copy and open it | "Reported as dangerous by 1 Manara user" | [ ] | [ ] | |
| 5 | Phone A: scan again | No second report; `reportCount` stays 1 | [ ] | [ ] | |
| 6 | Check post-conditions 1–3 | | | | |

**Post-conditions:** 1. The report is stored in Firestore. 2. Other users see the report count.
3. Neither phone's score for the network changed because of the report.
