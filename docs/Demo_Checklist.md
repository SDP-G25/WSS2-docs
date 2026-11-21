# Manara demo checklist

Rehearse this at least once on the real devices before the presentation. Each step says what to do,
what Manara should show, and what to check if it doesn't.

**Devices**

- **Phone A**: the demo phone running Manara (Galaxy S21).
- **Phone B**: a second **Android** phone that shares a hotspot. iPhones can't share an open
  (no-password) hotspot, so Phone B must be Android.
- **Home router**: your normal password-protected Wi-Fi, called `HomeNet` below.

## The day before

- [ ] Install the latest `main` build on Phone A (Android Studio → Run, or `adb install -r app-debug.apk`).
- [ ] On Phone A, turn on **Location**. Android won't return Wi-Fi scan results without it.
- [ ] Open Manara, tap **Allow location**, and choose **Precise**. That's the only permission
      Manara asks for at the start.
- [ ] Phone A → Developer options → turn **off "Wi-Fi scan throttling"**. Otherwise Android allows
      only 4 scans every 2 minutes, and the list stops updating partway through the demo.
- [ ] Run one traffic test (scene 2) on Phone A, so Android's VPN permission is already granted.
- [ ] Remove or disconnect any other VPN on Phone A. The traffic test replaces it.
- [ ] Install Manara on Phone B too. On both phones, turn on Bluetooth, then Manara → Settings →
      **Share warnings anonymously**, and allow **Nearby devices** and **notifications** when Android
      asks. Phone B shows the "… may be unsafe" notification only if notifications
      are allowed.
- [ ] On Phone A, open any network's details, tap **Locate**, and allow **Nearby devices** if
      Android asks (Android 13+, phones with Wi-Fi RTT). The radar then measures distance with
      Wi-Fi RTT where the router supports it.
- [ ] Check that `firestore.rules` is published (Firebase console → Firestore Database → Rules).
      Without it, Settings says "Couldn't reach your backup (PERMISSION_DENIED)".
- [ ] On Phone A, sign in and turn on Settings → **Report dangerous networks online**. Sign in on
      Phone B with a **different** account.
- [ ] Run the unit tests (`./gradlew :app:testDebugUnitTest`). They cover every rule, including
      cases you can't recreate live. This is your fallback if a device misbehaves.
- [ ] Charge both phones.

## During the demo, remember

- Manara rechecks the connected network whenever you open its details. If a result looks old,
  tap **Check again** or pull the Networks list down to scan.
- The connection check turns grey ("couldn't check enough") after about 2 minutes without a
  check. That's intentional: old results don't count.
- In the network details, **Pre-scan** rescans and reruns the scan rules, and **Post-scan** runs all
  five stages on the connected network (including the 30-second traffic test). **Save** works
  when signed in (History → Saved Networks), and turns into **Unsave** once the network is saved.
  **Locate** opens the radar for that one network; it keeps scanning while open, so tap **Exit**
  before the other scenes.
- **Connected** follows the router address *and* the network name. On campus access points that
  broadcast several names (for example `eduroam` and a guest network), it stays on the one you're
  actually on, even if Android briefly reports the other name's address.

## Scene 1: Before connecting (nearby networks)

Phone B hotspot: **off**. Phone A: connected to `HomeNet`.

- [ ] Pull the Networks list down to scan.
  - **Expect:** `HomeNet` pinned at the top with a **Connected** badge and a high score (usually
    90–100; WPS on the router takes 10 off). Other networks have their own scores; open ones show
    an **OPEN** badge and score 70 or lower.
- [ ] Turn on a Phone B hotspot named **`City Hotel Free WiFi`**, with a password. Pull down to scan
  and open it.
  - **Expect:** score **47, Moderate**. Its details show "This network uses an organization-style
    name but looks like a hotspot…" and one hotspot warning. Its issues include the "Free" name.
    - **Samsung or Apple Phone B:** "This is a hotspot. Proceed only if you trust it.", the issue
      "Mobile Hotspot Detected (Samsung)" (or Apple), and **Maker: … (hotspot address)** in Basic
      info. These phones make the hotspot address from their own by setting the locally
      administered bit (a Galaxy S21 broadcasts `2A:C2:1F…` for Samsung's `28:C2:1F…`, even with
      **Phone MAC** chosen), and Manara recognises the maker underneath.
    - **Fully random address, or another maker:** "This looks like a hotspot. Proceed only if you
      trust it." and **Maker: Randomized**.
  - **If it scores 77 with "This is a hotspot…" and no organization-name warning:** Phone B
    broadcasts its real Samsung or Apple address with the bit off, so the organization-name rule
    (random addresses only) doesn't apply.
  - **If it scores 92 with no hotspot warning:** Phone B uses its real address from a maker that
    also builds routers, so Manara can't tell it's a phone. Pick a different Phone B for the demo.
- [ ] In its details, tap **Pre-scan**.
  - **Expect:** "Pre-scan: scanning nearby networks...", then "Pre-scan finished. The score and
    issues above come from a new scan." The score stays the same.
  - **If it says Android didn't run a new scan:** scan throttling is still on (see the day before).

## Scene 2: The connected network and the traffic test (AI model)

Phone B hotspot: **off**. Phone A: connected to `HomeNet`.

- [ ] Tap `HomeNet` to open its details.
  - **Expect:** a **Connection check** section with "Manara finished N of M checks". It shows
    either **Secure, "Nothing suspicious found."** or **Unknown (grey)**, "Manara couldn't check
    enough to judge this network". Unknown is the honest answer when too few checks finished,
    which is common on a first visit.
- [ ] In **Traffic test**, tap **Run traffic test**. Wait 30 seconds. You don't need to browse.
  - **Expect while it runs:** "Testing. Manara is sending its own test requests…" and a key icon
    in the status bar. The **Connected** badge leaves the list for those 30 seconds (the VPN hides
    the Wi-Fi details), but the connection check keeps its last result.
  - **Expect afterwards:** "The model checked about 20–30 connections. None looked unusual.", with
    the note that it's an experimental model trained on the CICIDS2017 lab dataset. The checks
    count goes up by 2. With nothing suspicious found, the connection check can now turn
    **Secure, "Nothing suspicious found."**
  - **If it says "No connections could be checked":** the internet wasn't working during the test.
    Check `HomeNet`'s internet connection, then tap **Run again**.
- [ ] Tap **Post-scan**. It reruns the whole check in order: the connection checks, then the
  traffic test, then the verdict.
  - **Expect:** "Post-scan: checking the connection (stages 1–3)...", then "running the traffic
    test (stage 4, about 30 seconds)...", then "Post-scan finished. All five stages ran, and the
    connection check above shows the result."
  - **If it says it couldn't start the traffic test:** tap **Run traffic test** instead.
- [ ] Optional: rotate Phone A during a test. The results should still be there afterwards.
- [ ] Optional, for a technical audience: Settings → **Advanced Detection** → Stage 4 card shows the raw
  counts ("Flow vectors: N built…, generic model labels: …").

## Optional scene: Find the router with the radar

Phone A: connected to `HomeNet`. Stand a few metres from the router.

- [ ] Open `HomeNet`'s details and tap **Locate**.
  - **Expect:** the radar shows **only `HomeNet`** ("Only HomeNet is shown"), your orange arrow in
    the middle, and a panel with the distance, an **RSSI** or **Wi-Fi RTT** label saying how the
    distance was measured, and **"Next reading in N s"** with a bar.
- [ ] Hold the phone in front of you and **turn slowly in a full circle**, pausing for each reading.
  - **Expect:** after the second reading, green arrows point the way and the panel says "Walk
    straight ahead", "Turn left/right about N°, then walk" or "Turn around, then walk". As you turn,
    the arrows turn to keep pointing at the same spot.
  - **If readings are slow ("Android allows 4 scans every 2 minutes"):** scan throttling is still
    on (see the day before). The countdown shows the real wait either way.
  - **If the label says Wi-Fi RTT:** both the phone and the router support it, so the distance is
    measured, not estimated, and the countdown repeats every 1.5 s. A router that doesn't advertise
    Wi-Fi RTT is asked anyway (Android 13+): if it answers, the panel says "This router doesn't
    advertise Wi-Fi RTT, but it answered when Manara asked."
  - **If the label says RSSI:** the panel says why: the phone doesn't support Wi-Fi RTT, the router
    doesn't advertise it, or it didn't answer when Manara asked.
- [ ] Tap **Exit**. The radar closes and scanning stops.
- **Point to make:** Wi-Fi only hints at direction (the signal is strongest when you face the
  router, because your body blocks some of it), so the arrows are a best guess that improves as
  you turn.

## Scene 3: A fake copy appears nearby

Phone A: connected to `HomeNet`.

- [ ] On Phone B, start a hotspot named **exactly `HomeNet`** (same capitals) with **no password**
  (Security: None / Open).
- [ ] On Phone A, pull the Networks list down to scan.
  - **Expect:** two `HomeNet` cards, because their security differs.
    - The real one (connected) loses 10 points ("Same Name Broadcast by Unrelated Devices") but
      stays Secure.
    - The fake one scores **0–10, Vulnerable**, with **OPEN**, and its issues include "Open Copy
      of a Protected Network (Possible Evil Twin)".
  - **Point to make:** Manara flags the fake before anyone joins it.
- [ ] Look at the real `HomeNet`'s details.
  - **Expect:** **Moderate, "Use this network with care."**, with "Another router nearby uses this
    network's name with different security. One of them may be a copy."
- [ ] Nearby warnings: Phone A has just found the fake `HomeNet` scoring below 40, so it warns Phone B.
  - **Before:** Settings on both phones says "On. Connected to 1 nearby phone with Manara." Finding
    each other can take up to a minute.
  - **Expect on Phone B:** a "HomeNet may be unsafe" notification (tapping it opens the
    network's details), and History →
    **Warnings From Nearby Phones** lists `HomeNet` with its score and "Not checked by your phone."
  - **Expect on Phone A:** History → **Warnings You Shared** lists the fake `HomeNet`.
  - **If Phone B gets nothing:** each network is shared once a day. If you rehearsed today, Phone B
    already has the warning in History but won't be notified again.
- [ ] Online reports: on Phone A, open the fake (**OPEN**) `HomeNet`'s details.
  - **Expect:** "You reported this network to Manara's shared list...". In the Firebase console,
    Firestore → `dangerousNetworks` has a document named after the fake's router address, with
    `reportCount: 1`.
  - A phone signed in to another account that scans near the fake shows "Reported as dangerous by
    1 Manara user". Phone B can't, because it's the hotspot.

## Optional scene: Backup and restore

- [ ] On Phone A, save a network (details → **Save**). Settings shows "Saved networks and settings
  are backed up to this account."
- [ ] On Phone B, sign out and sign in with **Phone A's account**.
  - **Expect:** History → **Saved Networks** lists the network saved on Phone A, and Phone A's
    theme is applied. Sign Phone B back in to its own account afterwards.
- [ ] Unsave: open the network from History → **Saved Networks** and tap **Unsave**.
  - **Expect:** "… removed from your saved networks.", the button turns back into **Save**, and the
    network leaves the list. Signing out and back in doesn't bring it back.
  - **Limitation:** another phone that was signed in to the same account and still has the network
    saved backs it up again the next time it signs in to that account (Phone B, after this scene).

## Scene 4: Connected to the fake copy

- [ ] On Phone A, open Android's Wi-Fi settings and tap the **open** `HomeNet` (the one without a
  lock). Android treats it as a different network, so you have to pick it by hand.
- [ ] Back in Manara, pull down to scan, then open the connected `HomeNet`.
  - **Expect:** **Vulnerable (red), "This network may not be what it claims. Avoid using it."**
    The reasons, in this order:
    1. "A nearby network with this name has a password, but the one you're connected to doesn't.
       It may be a fake copy."
    2. "This network looks like someone's phone hotspot."
    3. "This Wi-Fi has no password, so people nearby can see anything that isn't encrypted."
  - If Phone A had joined the real `HomeNet` on 2 separate connections before, a reason naming the
    two internet providers (Phone B's mobile carrier and the home ISP) can also appear.
  - **If it shows Moderate instead:** the latest scan didn't include the real `HomeNet`, or is
    more than 2 minutes old. Tap **Check again**.
- [ ] Reconnect Phone A to the real `HomeNet` and turn off Phone B's hotspot. After a pull to scan,
  the fake disappears, and the real network loses the "Another router…" reason.

## Optional scene 5: A trusted network gets weaker

Try this in rehearsal first. The result depends on whether Phone B keeps its hotspot address
when its security changes.

- [ ] Phone B: hotspot **`DemoNet`** with a password. Connect Phone A to it.
- [ ] In Manara, open `DemoNet`'s details and tap **Post-scan**. When the connection check finds
  nothing suspicious, the **Trust** section below it offers **Trust this network**. Tap it.
  - **Expect:** "You trust this network. Manara warns you if its security gets weaker…"
  - **If the button isn't there:** the check found a sign of a fake network, or couldn't finish.
    Tap **Check again**.
- [ ] Phone B: change `DemoNet` to **no password**, keeping the name. Connect Phone A to the open
  `DemoNet`. In Manara, open its details.
  - **Expect:** the reason "This network's security is weaker than when you marked it as
    trusted." The level is **Vulnerable** if Phone B kept the same hotspot address, and
    **Moderate** if it changed it. The Trust section offers **Trust the new settings**.
- **Without trusting:** skip the Trust step, but connect Phone A to the protected `DemoNet`
  twice (turn Phone A's Wi-Fi off and on in between). The open `DemoNet` then gives "This
  network's security is weaker than on your earlier connections to it." (**Moderate**).

## Optional scene: An alert while Manara is closed

Set this up before Scene 4, on Phone A.

- [ ] Settings → **Background checks** on, location **Allow all the time**, notifications allowed.
  Settings reads "On".
- [ ] In Scene 4, press Home on Phone A **before** joining the open `HomeNet`, then join it from
  Android's Wi-Fi settings.
  - **Expect:** within about a minute, a notification "Something suspicious on HomeNet" saying a
    nearby network with this name has a password but this one doesn't. Tapping it opens Manara.
  - Doing it again within 6 hours doesn't notify again: that's the limit that keeps alerts rare.

## Optional scene: Arabic

- [ ] Settings → **Language** → **العربية**. The app reopens in Arabic, laid out right to left.
  Open a network's details to show the translated findings and advice. Switch back with
  **English**.

## Can't be shown live

- **Two networks with the same name *and* the same router address (rules 5, 13 and 14):** this
  needs a device that can copy a router's address, such as a laptop running hostapd; phone
  hotspots can't. It's covered by the unit tests.
- **Signal jump while still (rule 15)** can be shown, but slowly: lay Phone A flat on a table
  while connected to Phone B's hotspot, wait for two scans (a minute or two), then bring Phone B
  much closer. The next scan flags "Signal Rose While the Phone Was Still". Rehearse it first; it
  depends on when Android scans.
- **Note for scene 5:** turning `DemoNet`'s password off once doesn't trigger rule 13. Switching it
  off and on again within 10 minutes looks like two devices taking turns, and can.
- **The traffic model flagging connections:** normal traffic shouldn't trigger it, and the
  result is experimental by design.
- **Live Wi-Fi RTT on the radar:** it needs a phone and a router that both support Wi-Fi RTT
  (802.11mc), such as a Pixel with a Google Nest Wifi point. Without them the radar uses signal
  strength and its label says why. It's covered by the unit tests.

## If someone asks

- **"Why isn't the AI result part of the verdict?"** The model was trained on lab attack traffic
  (CICIDS2017), not on public Wi-Fi, so Manara reports it separately as an experimental signal.
- **"Why grey instead of green?"** Manara only says "Nothing suspicious found" when enough checks
  finished. A quiet result from a thin check isn't evidence of safety.
- **"Can someone send fake warnings?"** Any nearby phone can connect and send one. Manara rejects
  malformed, out-of-range or day-old warnings, ignores a phone that sends more than 50, shows the
  rest as unconfirmed reports, and never lets them change a network's score.
- **"Why doesn't WPS, a hidden name, or many routers with one name change the connection
  check?"** They describe most home routers and campus networks. They still lower the scan score
  in the list.
- **"How does the radar know the distance and direction?"** Distance comes from signal strength
  (a path-loss model, so it's rough), or from Wi-Fi RTT when both sides support it (accurate to
  about 1–2 m). Direction is the compass heading where the signal was strongest in the last minute.
- **"Why does the radar wait between readings?"** Android lets an app start only 4 Wi-Fi scans
  every 2 minutes. Manara schedules each scan for when Android allows it and shows the wait.
