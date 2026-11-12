# Festivus (prototype) — Mac build & test

Multi-event countdown timers for Garmin watches (PRD v1.0), built with
Connect IQ SDK 9.3. Target watch: Tactix 7 AMOLED 51mm — build for
device `epix2pro51mm` (Garmin maps the Tactix 7 AMOLED onto the epix Pro
51mm device definition; there is no tactix7amold device id).

## Build (VS Code terminal, in this folder)

```
SDK=$(ls -d ~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-*/ | tail -1)
"$SDK/bin/monkeyc" -g -d epix2pro51mm -f monkey.jungle -o bin/Festivus.prg -y developer_key.der -w
```

## Run in the simulator

```
"$SDK/bin/connectiq"        # wait until it is fully open
"$SDK/bin/monkeydo" bin/Festivus.prg epix2pro51mm
```

## Sideload to the watch

Quit Garmin Express completely (incl. menu-bar service), watch USB Mode
= MTP, then OpenMTP -> GARMIN -> APPS -> copy bin/Festivus.prg in.

Notes:
- Phone app settings do not work on sideloaded builds; all timer entry
  is on-device by design (PRD: no phone needed).
- Background alerts: a temporal event is registered for the nearest
  timer. Validate on the real watch that the background process sounds /
  vibrates (PRD 13B): set a timer ~6 minutes out, close the app, and
  wait. The glance must be added via Glances -> Edit if it does not
  appear in the glance loop.
- The launcher icon is a placeholder.

## v2 (PRD v1.4): timezones

- Timers carry an event timezone: pick "Watch timezone" or a city.
  Date/time are stored as entered (event-local); the UTC instant is
  resolved on-device by a bundled IANA rule engine (offline).
- DST: a nonexistent local time is rejected at Save; an ambiguous
  (fall-back) time asks first or second occurrence.
- Existing v1 timers migrate automatically (zone = watch timezone).

## v4 (PRD v1.5): native text entry
- The Name field now opens Garmin's native TextPicker (prepopulated
  with the current name). Confirm returns the text to the form; Cancel
  keeps the previous name and all other form values. The v2/v3 custom
  character editor is removed.
