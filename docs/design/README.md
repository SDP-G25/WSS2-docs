# Manara redesign: design notes

Status: design direction agreed, and most of it is now implemented. The section [Implementation](#implementation) lists what's built, the decisions made while building it, and what's left.

The mockups are in [mockups/](mockups/). Open any of the HTML files in a browser. The list of files is [at the end](#mockups).

## Logo
- System: concept C ("signal of light") is the app icon and mark, and concept B ("beam meets boat") is the hero scene.
  - C: navy tile #0B1A2E. A faint amber beam wedge sits behind three Wi-Fi arcs: inner warm white #FAEEDA, middle gold #FAC775, outer light blue #85B7EB. The lantern (amber glass #EF9F27, brick cap #A32D2D) is the dot, sitting on a cream and brick tower stub.
  - A monochrome C (arcs plus lantern) is used for the themed icon and the notification small icon.
  - B: lighthouse at the left, beam crossing the sea, and the connected boat with its masthead lantern lit. Used on the Permission screen (replacing lighthouse.gif) and as the lantern room scan (replacing ScanAnimation/ScanningOverlay).
- Lockup: tile + "Manara" in Fraunces 500 + "منارة" in Aref Ruqaa 400. Arabic in amber: #FAC775 at night, #854F0B by day.
- Home (Networks tab): no header and no "Manara" text. The C mark (wedge, three arcs, lantern) sits centred at the top of the tower list as the lighthouse's lantern room. Its stub rests on the gallery railing, and the gallery card under it holds the connected network. The only things above it are the avatar and a small "Pull down to scan" hint.
- Other tabs (Debugging, History, Settings): no logo tile. Each header is just a Fraunces 500 title at 22px on the left with the avatar on the right, and an optional 11px subtitle in secondary text. In the app, the brand mark only appears on home (as the lantern), on the loading screen, and on the Settings about card.
- Loading screen (shown when the app opens): the large mark, with "منارة" in Aref Ruqaa as the main wordmark and a small Fraunces "Manara" under it. The three arcs light up from inner to outer while it loads. The day version uses the day signal code for the arcs (navy inner, #BA7517 middle, #378ADD outer) with a navy gallery bar. The Android 12 system splash still shows only the icon, so this is the in-app screen that comes after it.
- In-app Arabic text: El Messiri 400/500. Use a line height of about 1.6 for Arabic. Isolate SSIDs, dBm values and "Fl(2) 4s" as left-to-right runs inside right-to-left layouts.
- Fonts in the build: turn the wordmark (Fraunces + Aref Ruqaa) into vector outlines in a VectorDrawable, so Aref Ruqaa doesn't have to ship as a runtime font. El Messiri (and Fraunces, if screen titles use it) go in res/font. All of them are SIL OFL.
- Mocked screens: launcher, splash, permission, sign in, networks (tower list), lantern room scan, network detail, locate radar (drawn as C's fan), history (logbook), debugging, settings (about card), edit profile.

## Danger language (verdicts and reports), first proposal
- Uses the app's real levels from SecurityLevel: Secure (75+), Moderate (40 to 74), Vulnerable (below 40), Unknown. The earlier history mockup's "Trusted / Caution / Unsafe" labels were placeholders. Those levels replace them.
- Each level has its own shape as well as a colour, taken from buoyage topmarks: Secure is one ball (safe water, #5DCAA5), Moderate is a cone (#EF9F27), Vulnerable is two stacked balls (isolated danger, #E24B4A), and Unknown is an unlit ring (#B4B2A9) that is never green or "safe".
- Networks tower: every band gets a round navy "porthole" at its right end that holds the mark, so the mark reads the same on cream and brick bands. This also stops the brick bands being read as danger. The subline starts with the level word, then the most serious fact (for example "Vulnerable · no password" or "Moderate · 1 report"). Saved networks keep the amber window on the left.
- Reports from other people (Firestore community reports and nearby P2P warnings) are always drawn dashed in pale red #F09595: a dashed ring inside the porthole, dashed report cards on the detail screen, and a dashed ring around the boat in the lantern room. Solid means your phone checked it, dashed means someone else said so. This matches NearbyWarningRules, where a received warning never changes the score.
- Detail screen: the verdict leads, drawn as a sector light. A lantern glows from the panel corner in the level's colour, with a Fraunces level word, "Score 28 of 100" and the one-sentence headline. "What Manara found" with its advice comes next, then any dashed report cards. "Fl(2) 4s" moves into the header under the name.
- Lantern room: a Vulnerable boat gets a small isolated-danger buoy beside it (red with a navy band and two pale balls). A reported boat gets a dashed ring.
- Nearby warning notification: the small icon becomes the monochrome C mark tinted red with setColor, instead of android.R.drawable.stat_sys_warning. The title names the network ("Corniche may be unsafe") and the body is short ("A nearby phone scored it 31. Yours hasn't checked it yet."), with an action called "View network" that opens its detail. Today's text is longer, and opening the notification only launches the app.
- Portholes stay navy in day mode as well (like the icon tile), so the mark colours don't change between modes.

## Bottom nav icons (set A, nautical, chosen)
- Today DashboardBottomNav uses Material Search, BugReport, AutoMirrored List and Settings.
- Set A, nautical (chosen): Networks is the lighthouse tower, Debugging is a spyglass, History is a logbook with a ribbon, Settings is a ship's wheel that still reads like a gear. Each has an outline version for idle and a filled version for selected, following the Material 3 pattern. The selected tower also throws two small rays from its lamp.
- Set B, conventional (not chosen; kept only as a fallback if testers don't recognise set A): the logo's arcs and lantern, a clipboard check, a clock winding back and a plain gear, drawn in the same stroke and used for both states.
- Specs: 24 dp grid, 1.8 dp round strokes. Holes in the filled versions (logbook lines and ribbon, the spyglass band, the wheel's rim) are evenOdd subpaths, so each icon is a single VectorDrawable. Colours: night idle #85B7EB, selected #FAC775 on a pill at 18% #FAC775. Day idle #185FA5, selected #854F0B on a pill at 40% #FAC775. Labels always stay visible, which is what makes the nautical shapes safe to use.
- Code shape: NavigationBarItem icon = if (selected) filled else outline, two drawables per tab. None of set A's icons need mirroring in Arabic.

## Empty and error states, first proposal
- What the code does today: Wi-Fi off, location off, no signals, scan throttled and permission missing are only handled on the radar (ApRadarUiState and the ap_radar_* strings). The Networks tab has no empty state: an empty scan shows an empty list, and the "No ... networks in this scan" text only covers the filters. WifiRepositoryImpl knows when Android refused a scan ("cached results may be stale or throttled"), but the main list never shows it. History category sheets use the plain-text messages from getEmptyMessageForCategory.
- Pattern: home always keeps the tower, and each part reports one thing.
  - The lantern (C mark) shows the radio. Lit is normal. Broken beam (arcs dotted and faded) means location services are off, because Android hides scan results. Out (grey arcs and glass, dimmed brick) means Wi-Fi is off.
  - The gallery card under the lantern reports the connection. It shows the network you're on, "Not connected" with a hollow dot (amber dot only when connected), or it grows to hold a Wi-Fi off or location off message with one amber button.
  - The tower reports the list. Ghost bands (dark navy stripes, pale blue by day) mean no data. An empty tower with "No Wi-Fi in range", a hint to try another room or a window, and an outline "Scan again" button means the scan found nothing.
  - The "Pull down to scan" hint turns into "Next scan in 1 min" while Android's scan limit applies. If the user pulls anyway, a snackbar says "Android limits how often apps scan. This is your 9:38 scan." The list stays as the last scan.
- Buttons open Android's own controls: Settings.Panel.ACTION_WIFI (Android 10+, since apps can't switch Wi-Fi on themselves) and the location settings screen. One action at most per state. Copy says what's wrong, then what to do, with no error codes. Only add a privacy line to the location message ("Manara doesn't save where you are") if that's confirmed true.
- Lists (History categories and the like): a blank logbook page. The logbook icon drawn large in #378ADD, a Fraunces title ("No warnings yet"), one or two sentences, and a button only when the user can fix it (for example "Turn on in Settings" when nearby warnings are off). Without a fix there's no button ("No warnings from nearby phones yet.").
- The radar reuses the same lamp states and copy for its WifiOff, LocationServicesOff, NoSignalsDetected and Throttled states.

## Day mode (first proposal)
Idea: lighthouses are known by their light at night and by their painted daymark by day.
- Page/sky #E6F1FB, sea #D6E7F7, panel #FFFFFF, text #0B1A2E, secondary text #185FA5, accent text #854F0B, button #EF9F27 with #412402 label, railing and rules #0B1A2E. Tower bands stay #F1EFE8 / #A32D2D.
- The signal code reverses by day (aerial perspective): strong #0B1A2E, good #BA7517, fair #378ADD, weak #85B7EB fading into haze. Night stays warm white, gold, light blue, then dim blue in fog.
- "More in the fog" becomes "more in the haze". The detail screen shows a per-network daymark (band pattern from the BSSID) first, with the light characteristic underneath.
- The app icon tile stays navy in both modes.
- Settings theme switch: Day / Night / System (System was chosen over a sunset-based Auto). System follows the phone's dark mode, with the helper text "Follows your phone's dark mode".
- Code today: AppSettings stores a boolean `dark_mode` (default false, i.e. day) and backs it up in BackedUpSettings. MainViewModel.isDarkMode drives WSSTheme and the system bar style in MainActivity. A three-way setting would replace the boolean (old true/false values map to Night/Day). System would use isSystemInDarkTheme(), and the system bars would follow the resolved theme. Proposed default for new installs: System.

## Implementation
What's built:
- Brand: the app is called Manara. The launcher icon is the C mark on a navy tile (adaptive foreground, background and a monochrome layer for themed icons), with PNG versions for Android 7. The notification small icon is the one-colour mark. Android 12+ shows a navy splash, and the window is navy or day sky until Compose draws.
- Fonts: Fraunces (Medium, opsz 24), El Messiri (Regular and Medium) and Aref Ruqaa are bundled in `res/font`. Fraunces and El Messiri are static instances cut from Google's variable fonts, so they work on every Android version. Their OFL licences ship in `assets/licenses`. The Arabic wordmark is set in Aref Ruqaa as text, not outlined, because the font is bundled anyway.
- Theme: `ui/theme` has the night and day palettes, the signal code, and the verdict colours (`ManaraTheme.colors`), mapped onto Material's colour scheme so existing screens follow. Typography uses Fraunces for titles; when the phone runs in Arabic, body text switches to El Messiri with taller lines.
- Theme setting: Day / Night / System, saved as `theme_mode`. An existing `dark_mode` switch is moved over once (true becomes Night, false becomes Day), and new installs follow the phone. The account backup and its Firestore rules still store only `darkMode`, so the backup writes Night as true and Day or System as false. On a new phone only Night is restored, and only if the theme was never chosen there.
- Loading screen: shown for 1.4 s when the app opens, with the arcs lighting up from inner to outer, the Aref Ruqaa wordmark and the lantern boat.
- Networks tab: the tower. The mark is the lantern (lit, broken beam or out, from the Wi-Fi and location switches), the railing goes round its base, and the gallery card shows the connection or a Wi-Fi off or location off message with one button (Android's Wi-Fi panel or location settings). Each band is a network, strongest first, with a porthole holding its verdict mark, a dashed ring for other people's reports, and an amber window when it's saved. Networks at -80 dBm and below wait in the fog band, which opens on tap. Pull down to scan; the hint at the top is also a button, for TalkBack. When Android refuses a scan, the hint counts down to the next one (estimated from Manara's own requests, see `ScanThrottle`) and a snackbar says the list is the earlier scan. An empty scan shows the empty tower with "Scan again".
- Kept from the old Networks tab: the All / Secure / Moderate / Vulnerable filter, now under the tower with the verdict marks. Removed: the Environment Score card and the Scan Now button, which pull to scan and the tower replace.
- Lantern room: the scan overlay is the sea, with a sweeping beam and a sailboat per network (up to 9). Boats light up as the beam passes; the connected one has its lantern lit, open networks fly a pennant, Vulnerable ones get a danger buoy, and reported ones a dashed ring.
- Network detail: the boat, name, signal and security, and the light characteristic (worked out from the BSSID and flashing its pattern). The verdict panel comes next as a sector light, then dashed report cards. The rest of the sheet (connection check, traffic test, facts, actions) is unchanged apart from colours.
- Nav bar: set A's eight icons as vector drawables, outline when idle and filled when selected.
- Headers: Debugging, History and Settings have title-only headers with the avatar. The Networks tab has none.
- Settings: the theme switch and an About card with the lockup.
- History: empty lists are a blank logbook page, with a button when the user can fix it (Sign in, or Turn on in Settings).
- Notification: the red-tinted mark, "<network> may be unsafe", the short body, and View network, which opens Manara on that network once a scan has found it.
- Permission screen: the beam scene replaces lighthouse.gif. Sign-in shows the lockup. The radar's Wi-Fi off, location off, no signal and scan-limit states use the same lamp states and wording.

Not done yet:
- Not checked on a device: this PC can't run the Android emulator, so the screens have only been compiled and unit tested.
- Day mode's per-network daymark on the detail screen (the light characteristic is there, the daymark isn't).
- The locate radar's own drawing (the fan of arcs) and the logbook styling of History's category cards.
- Arabic translations of the app's text. The typography is ready for them.

## Mockups
In the order they were made. Later files replace parts of earlier ones, as noted.

| File | What it shows |
| --- | --- |
| [01-logo-concepts-round1.html](mockups/01-logo-concepts-round1.html) | The first logo concepts. C became the mark and B the hero scene. |
| [02-screens-part1-launch-to-scan.html](mockups/02-screens-part1-launch-to-scan.html) | Launcher, splash, permission, sign in, networks tower and lantern room scan. The home header and the notification copy are replaced by 09 and 11. |
| [03-screens-part2-detail-to-profile.html](mockups/03-screens-part2-detail-to-profile.html) | Detail, locate radar, history, debugging, settings and edit profile. The logo tile in the headers, Noto Kufi Arabic and the Trusted / Caution / Unsafe labels are replaced by 08, 10 and 11. |
| [04-day-mode-palette.html](mockups/04-day-mode-palette.html) | Day mode palette and the reversed signal code. |
| [05-day-mode-screens.html](mockups/05-day-mode-screens.html) | Day mode screens. |
| [06-settings-theme-system-option.html](mockups/06-settings-theme-system-option.html) | The Day / Night / System theme setting. |
| [07-arabic-typeface-options.html](mockups/07-arabic-typeface-options.html) | Arabic typeface options that were compared. |
| [08-arabic-type-system.html](mockups/08-arabic-type-system.html) | Aref Ruqaa for the logo and El Messiri for in-app Arabic. |
| [09-home-logo-lantern-and-loading.html](mockups/09-home-logo-lantern-and-loading.html) | Home with the mark as the lantern, and the loading screen by night and day. |
| [10-tab-headers-titles-only.html](mockups/10-tab-headers-titles-only.html) | Title-only headers for Debugging, History and Settings. |
| [11-danger-language-verdicts-reports.html](mockups/11-danger-language-verdicts-reports.html) | Verdict marks, dashed reports, the detail sector light and the nearby warning notification. |
| [12-bottom-nav-icon-sets.html](mockups/12-bottom-nav-icon-sets.html) | Nav icon sets A and B at large and real size. Set A was chosen. |
| [13-empty-and-error-states.html](mockups/13-empty-and-error-states.html) | Wi-Fi off, location off, nothing in range, the scan limit, empty history, and Wi-Fi off by day. |
