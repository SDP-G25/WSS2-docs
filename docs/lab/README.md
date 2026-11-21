# Manara test-AP lab

Config and scripts to run a controlled access point from a Linux laptop (tested target:
Parrot) with an 802.11ac USB card, so each Phase 2 rule in [`../Testing_Plan.md`](../Testing_Plan.md)
can be made to fire deliberately. The AP is a **test fixture for the scanner** — set a condition,
scan with the phone, check Manara reports what the table below predicts.

Everything here is standard access-point configuration. Only ever broadcast network **names you
own**, keep the signal low (`iw dev <wlan> set txpower fixed 500`), and turn the AP off when done.

## Files

| File | Purpose |
| --- | --- |
| `hostapd.conf` | The AP. Baseline = WPA2-Personal, 2.4 GHz, should score **100 / Secure**. |
| `dnsmasq.conf` | DHCP + DNS. Only needed for connected-network (Stage 2/3) tests. |
| `lab-up.sh` | Releases the card from NetworkManager, addresses it, shares internet, starts both. |
| `lab-down.sh` | Removes the firewall rules and hands the card back to NetworkManager. |

## First check your card can host an AP

```bash
iw dev                                                 # find the card name + its phyN
iw phy phy1 info | grep -A 8 "Supported interface modes"   # must list "* AP"
```

No `* AP` line means the driver can't host a network. MediaTek (MT7612U/MT7610U) works out of the
box; Realtek RTL8812AU/8821AU usually needs `realtek-rtl88xxau-dkms`.

## Run

```bash
sudo apt install hostapd dnsmasq iw
chmod +x lab-up.sh lab-down.sh
sudo ./lab-up.sh wlan1 eth0        # your AP card, your internet interface
```

`lab-up.sh` ends by running `hostapd` in the foreground; Ctrl+C stops it. Then:

```bash
sudo ./lab-down.sh wlan1 eth0
```

If 5 GHz refuses ("NO-IR" / "not allowed"), start on 2.4 GHz channel 6, then switch to the 5 GHz
block in `hostapd.conf`. If the phone shows "Connected, no internet", the uplink interface name is
wrong — without validation Android skips Stage 3 and you get an **Unknown** verdict.

## hostapd change per rule

Start from the baseline, change **one** thing, restart hostapd. Penalties are from
`PreConnectionScanEngine` (score starts at 100; bands: 75+ Secure, 40–74 Moderate, <40 Vulnerable).
The pre-connection rules score from the scan list, so the phone does **not** need to join.

| Rule | Penalty | Change in `hostapd.conf` | Expect in Manara |
| --- | ---: | --- | --- |
| PRE-1 weak encryption | −30 | `wpa=1`, `wpa_key_mgmt=WPA-PSK`, `wpa_pairwise=TKIP` (remove the WPA2 lines) | "Weak Encryption (WPA/WEP)" |
| PRE-2 WPS | −10 | keep WPA2, add `wps_state=2`, `eap_server=1`, `config_methods=push_button` | "WPS Enabled (Vulnerable)" |
| PRE-3 random MAC | −15 | add `bssid=02:1A:2B:3C:4D:5E` (2nd hex digit 2/6/A/E = random) | "Random MAC Address (Possible Hotspot)" + Maker "Randomized" |
| PRE-4 org name + random MAC | −30 | PRE-3's `bssid` **and** `ssid=City Hotel` | "Hotspot network + Organization-like SSID (Possible Spoofed Network)" |
| PRE-9 "Free" in name | −8 | `ssid=Free Lab WiFi` | "SSID Contains 'Free' (Possible Bait Network)" |
| PRE-10 hidden name | −10 | `ignore_broadcast_ssid=1` | "Hidden SSID" |
| PRE-11 open network | −30 | remove every `wpa…` / `rsn_pairwise` / `auth_algs` line | "Open Network (No Encryption)" |
| PRE-12 open copy | −50 | run an **open** AP with the same `ssid` as your WPA2 one (second card or the Pi) | "Open Copy of a Protected Network (Possible Evil Twin)" (open copy only) |
| PRE-7 same name, unrelated MACs | −10 | two APs, same `ssid`, BSSIDs > 5 apart numerically (needs a second radio) | "Same Name Broadcast by Unrelated Devices" |

Notes that trip people up:

- **PRE-3 vs PRE-8 are exclusive.** A Samsung/Apple/Nothing hotspot takes PRE-8 ("Mobile Hotspot
  Detected (…)"); any other random MAC takes PRE-3. You can't stage PRE-8 with hostapd — use a real
  phone hotspot from that maker (it's in the checklist).
- **PRE-1 parsing:** a bare `WPA-PSK` with no WPA2/RSN reads as legacy WPA and fires PRE-1; WPA2/RSN
  does not. `wpa=1` + TKIP is the reliable trigger. Android may refuse to *join* legacy WPA, but the
  rule only needs the scan.
- **PRE-5 (same name + same MAC twice)** usually can't be shown live — Android keeps one scan entry
  per BSSID, so a clone collapses into the original. Rely on the unit test; try a duplicated-BSSID
  clone once and record the result.
- **PRE-6 (>50 networks)** is a warning, not a penalty, and needs a crowded RF environment, not this AP.

## Stage 3 (connected) tests

These need the phone **joined** and the internet shared, so run `dnsmasq` too (lab-up.sh does). For
the DNS-comparison check, uncomment the `address=/example.com/…` line in `dnsmasq.conf` so this
network's answer disagrees with Manara's encrypted (DoH) lookup, then remove it afterwards. The
captive-portal and TLS probes only run when Android marks the network validated (internet working)
and finds no captive portal — see Phase 2 → "Stage 3 probes" in the testing plan.
