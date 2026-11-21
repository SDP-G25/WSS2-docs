# Testing and evaluation — what the report section needs

This file lists what Section 8 (Testing and evaluation) of the project report must contain to meet
the course requirement, what the current draft already has, and what is missing. The section itself
is drafted in [`Testing_Section_Template.md`](Testing_Section_Template.md).

**Compared against:** `ProjectS262625-InterimRevisedReport.docx` (19 Nov 2026), the repository at
`edcbea7`, and [`Testing_Plan.md`](Testing_Plan.md).

---

## 1. What the requirement actually asks for

The course text, together with the ToDo notes in Section 8 and Appendix B of the report template,
asks for:

1. **The whole solution tested in semester 2**, not only the use cases built in semester 1.
2. **Functional testing per use case** (UC01–UC05), at four levels at least: **unit**,
   **integration**, **system** and **acceptance**.
3. **Test cases with expected and actual results**, run and reported, written in **Appendix B**
   using the course's test-case table (test case #, use case ID, designed/executed by, dates, steps,
   expected response, actual result, pass/fail, post-conditions).
4. **Evidence**: tables, graphs, diagrams and screenshots.
5. **Defects found → fixed → retested**, and improvements identified.
6. **Non-functional testing with one subsection per requirement** from Section 3.2, plus a
   **summary table** of each requirement, its target, the measurement, and met / not met.
7. **Proof that the solution solves the stated problem**: rating Wi-Fi networks before connecting,
   and spotting MITM and Evil Twin attacks (Section 1.1).
8. **An honest discussion**: if a requirement isn't met, say what is lacking and why.

---

## 2. What the current draft has

| Required item | Current state | Gap |
| --- | --- | --- |
| Unit testing | 3 tests of `WifiViewModel` (semester 1) | **Outdated.** Scoring moved to `PreConnectionScanEngine`, and the `VERY_WEAK` label no longer exists (the bands are now Secure / Moderate / Vulnerable). The repo now has **355 unit tests in 46 classes** (all passing on 20 Nov 2026) and **16 instrumented tests in 5 classes** (all passing on a Galaxy S21, 20 Nov 2026), and none of them are reported. |
| Integration testing | — | **Missing.** |
| System testing | — | **Missing.** `Demo_Checklist.md` and `Testing_Plan.md` describe procedures, but no results are recorded. |
| Acceptance testing | — | **Missing.** |
| Test cases per use case | — | **Missing.** There are no test cases for UC01–UC05. |
| Appendix B | Only the course's ATM example | **No Manara test cases.** |
| Evidence that the problem is solved | — | **Missing.** There are no detection results from the lab or from real networks. |
| Defect log | — | **Missing.** |
| NFR: Security | — | **Missing.** |
| NFR: Performance | — | **Missing.** |
| NFR: Reliability (AI accuracy) | — | **Missing.** |
| NFR: Usability | 21-person survey (5 charts) | **Doesn't measure the target.** The target is "use the app within 8–10 minutes without guidance", but no times were recorded. The survey was also run on the semester-1 UI, before the redesign merged on 16 Nov. |
| NFR: Availability | — | **Missing.** |
| NFR: Maintainability | — | **Missing.** |
| NFR: Scalability | — | **Missing** (and it has no target, see §3). |
| NFR summary table | — | **Missing.** |
| Figure references | Text cites Figures 58–64, captions say 44–50, and "Figure 44" appears twice | **Broken cross-references.** Use Word's *Insert Caption* / *Cross-reference* so they renumber themselves. |

---

## 3. Fix these in the requirements first

Results can only be judged against requirements that are consistent and measurable. These issues
would make a test fail, or leave nothing to test against.

1. **Seven NFRs or six?** Section 3.2 says "seven" but lists six: Security, Performance,
   Reliability, Usability, Availability and Scalability. Table 6 also has six, with
   **Maintainability instead of Scalability**. Put all seven in both places.
2. **Scalability has no target.** Either give it one, or say it is assessed by a **design review**
   (the plan in `Testing_Plan.md` §4.7). With no custom server, a load test has nothing to call.
3. **"Security (Threat Detection)" measures data encryption, not threat detection.** Either rename
   it *Security (Data protection)*, or keep both:
   - **S1 Data protection:** the current Table 6 row.
   - **S2 Threat detection:** a measurable target on detection, for example "every PRE/RAP rule
     fires in the lab, and the lab Evil Twin is flagged Vulnerable". The problem statement is about
     Evil Twin and MITM, so detection needs a measurable target somewhere.
4. **"Local credentials … must be encrypted using AES-GCM" isn't what the code does.** Manara
   stores no passwords; Firebase Authentication keeps its own sign-in token. What *is* encrypted is
   **saved network data**: `SavedNetworkCipher` uses AES-256-GCM with a 12-byte IV and a 128-bit
   tag, a non-exportable Android Keystore key (`manara_saved_networks_key`), and the user ID bound
   as associated data. Other local stores are **not** encrypted: the `warnings` Room table, network
   baselines (DataStore), and settings and background-check state (SharedPreferences). Reword the
   target to "saved network data", or the test fails as written.
5. **Reliability: 100 + 100 samples is too few for a 7% target.** With 100 samples, the 95%
   confidence interval around 7% is about **±5 points**, so 5% and 9% can't be told apart. Use a
   held-out set of **≥ 1,000 flows per class** and report the interval. It must be data the model
   **did not train on**; check what `Manara_RandomForest_Model_Summary.docx` used as its split. The
   description also promises "no different recommendations from the same data", which needs a
   **repeatability test**: the same input, N runs, the same output.
6. **Performance targets need definitions.** "During scanning" should say which scan: a pre-scan
   (scan + rules) or a post-scan (stages 1–5). "ONNX inference < 4 s" should say whether that is
   **per flow** or per batch. The 30-second capture is a fixed design window, not inference time.
7. **Availability: "across Qatar" can't be tested as written.** Make it "on N Android devices
   (Android X–Y)" plus "core features work with no internet".
8. **The use-case text is behind the code.** UC01 says rules PRE-1 to PRE-12, but the code has
   **PRE-1 to PRE-15**. UC02 should mention the RAP rules (now RAP-1 to RAP-6). UC01's trigger
   names a **Scan Now** button, but the redesigned app scans when you **pull the Networks list
   down**. UC01's preconditions also require "location allowed all the time" and a
   battery-optimisation exclusion, which only background checks need; a foreground scan needs
   **precise location** only.
9. **Implemented features with no use case.** Several features can't be traced to a use case:
   saved networks and cloud backup, sign-in, background checks and alerts, History, Settings /
   Advanced Detection, and Arabic. Either add use cases (at least **UC06 Save a network and back it
   up** and **UC07 Background checks and alerts**, which is the "real-time alert system" of
   objective 4), or list them as supporting features tested under UC01/UC02.
10. **`Testing_Plan.md` Phase 4 follows the older `PerformativeTesting.docx`.** It tests threat
    response time and a "warning display < 7 s" target that the revised Table 6 no longer has.
    Update Phase 4 to the report's Table 6, or the other way round, so plan and report agree.

---

## 4. What is needed to satisfy the requirement

### A. Test environment (one table, at the start)
- [ ] Devices: model, Android version, and whether each supports Wi-Fi RTT (at least 2, ideally 3+
      makers).
- [ ] The build under test: commit hash and date.
- [ ] Lab equipment: the `hostapd` laptop and USB NIC (see [`lab/`](lab/README.md)), the second
      phone, routers.
- [ ] Tools: JUnit 4, MockK, Turbine, AndroidX Test, Android Studio Profiler, `adb`, Perfetto,
      Python + ONNX Runtime, Firebase console / emulator.
- [ ] Who ran what, and when.

### B. Unit testing
- [x] Run `./gradlew :app:testDebugUnitTest`. **Done on 20 Nov 2026 on `edcbea7`: 355 of 355
      passed** (0 failures, 0 errors, 0 skipped). Gradle needs JDK 17 or newer, for example
      Android Studio's bundled `jbr` set as `JAVA_HOME`.
- [ ] Screenshot the HTML report (`app/build/reports/tests/testDebugUnitTest/index.html`) for the
      figure.
- [ ] A table mapping each test class to its use case, with the test count (drafted in the
      template).
- [ ] 3–5 named example tests that matter. For example, the PRE-5 clone case that can't be staged
      live, the RAP-1 downgrade ladder, and "VerdictMapper drops ML.FLOW".
- [ ] Optional: a coverage percentage. No coverage tool is set up yet; enabling
      `enableUnitTestCoverage = true` on the debug build type gives a JaCoCo report.
- [ ] Remove or replace the semester-1 `WifiViewModel` figures.

### C. Integration testing
- [x] Run `./gradlew :app:connectedDebugAndroidTest` on a real phone. These tests chain parts
      together: packet parser → flow aggregator → feature builder → ONNX model, and the native zdtun
      bridge through JNI. **Done on 20 Nov 2026 on a Galaxy S21 (Android 15): 16 of 16 passed.**
      Add `-Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true`, or Gradle uninstalls
      the app after the run and wipes its data on the phone.
- [ ] Screenshot the instrumented test report
      (`app/build/reports/androidTests/connected/debug/index.html`) for the figure.
- [ ] **Saved-network encryption round trip** on a device (DataStore + Keystore): encrypt → store →
      read → decrypt, and a different user ID must fail. No such instrumented test exists yet.
- [ ] **Firestore rules** (UC05): duplicate report rejected, invalid BSSID rejected, a user can't
      write another user's data. No rules tests exist; use the Firebase emulator, or record manual
      console tests with screenshots.
- [ ] **Nearby Connections between two phones** (UC04): a warning sent, received, stored in
      History, and forwarded up to 3 hops.

### D. System testing (Appendix B)
- [ ] One test case per **main success scenario** and per **alternative flow** of UC01–UC05.
      There are about 30, and the template drafts all of them.
- [ ] Each one run on a real device, with the actual result, pass/fail and a screenshot.
- [ ] **Rule-by-rule lab results**: PRE-1 to PRE-15 and RAP-1 to RAP-6 from `Testing_Plan.md`
      Phase 2, with the expected score next to the actual one.
- [ ] **False-positive baseline**: Manara's results on ≥ 10 real, legitimate networks (home, QU,
      café, mall). This is the main evidence that the scores are sensible.

### E. Acceptance testing
- [ ] Acceptance criteria for each use case, taken from its **post-conditions**.
- [ ] Run them with end users (they can share the usability session) and/or the supervisor, and
      record accepted / not accepted.

### F. Evidence that the problem is solved
- [ ] The lab Evil Twin scenarios (PRE-12, PRE-13, PRE-14, and RAP rules on the connected clone)
      detected, with screenshots.
- [ ] The ML model's real-detection results (`Testing_Plan.md` Phase 3B), reported honestly,
      including "the model did not detect X".
- [ ] A short table linking each **project objective** (Section 1.2) to the test that shows it was
      met. The Conclusion needs this too.

### G. Non-functional testing
- [ ] One subsection per NFR: method, tool, scenario, measurements (table or chart), and met / not
      met with the reason.
- [ ] **Usability:** a new **timed** session on the current build. Record how long each
      participant took to finish the core tasks unaided, and keep the semester-1 survey as
      supporting data.
- [ ] **Reliability:** a confusion matrix, FPR, FNR and their confidence intervals, plus the
      repeatability test.
- [ ] The summary table (drafted in the template).

### H. Defect log
- [ ] Defects found while testing: ID, the test that found it, description, the fix commit, and
      the retest result. Recent fix commits in the git history are a good source.

### I. Discussion and limitations
- [ ] For each requirement that isn't (fully) met, the reason. The known items: deauthentication
      detection isn't implemented, the ML model is experimental and excluded from the verdict, PRE-5
      can't be staged live, the VPN sees only phone-originated IPv4 flows, RSSI distance is
      approximate, and Android throttles scans.

---

## 5. Suggested order

1. Fix the requirement wording (§3). It changes what the tests must show.
2. Run the unit and instrumented tests and capture the reports. This is quick, and fixes the
   outdated unit-testing section.
3. Finish Appendix B from the template, then run the system tests: the checklist, then the lab
   (Phase 2).
4. Take the NFR measurements: profiler, offline test, model test set, timed usability session.
5. Write the acceptance results, the defect log, the summary tables and the discussion.
