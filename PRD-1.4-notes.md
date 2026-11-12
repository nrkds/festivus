# Festivus PRD v1.4 — implementation notes (2026-11-11)

PRD v1.4 (delivered in the Product chat) supersedes v1.0. Key deltas
implemented in Festivus-v2:

- SIX attributes: Name, Date, Time, Timezone, Event Type, Alert Type.
- Canonical record (schema v2): local date + local time + IANA
  timeZoneId + resolved eventTimestampUTC + alertDelivered + timerId.
- TimezoneService is the sole converter; CountdownEngine and
  AlertScheduler consume only the UTC instant.
- DST: nonexistent times rejected at Save; ambiguous times ask
  first/second occurrence.
- Edit rule (PRD 10.3): alertDelivered resets only when the event is
  rescheduled to a different FUTURE instant; same-instant edits never
  re-arm a delivered alert.
- New timers must have date AND time explicitly selected in the
  editors before Save (PRD 9.3); new timers must resolve to the future.
- Schema v1 records migrate on first load (zone = watch zone).

Documented platform deviations (PRD 5.6 / 18):
- Connect IQ has no IANA tz database/API. TimezoneService bundles
  POSIX-style DST rules for 29 IANA zones, resolved offline.
- The watch's IANA zone name is not exposed by the platform, so the
  default "Watch timezone" entry stores timeZoneId "Local" and resolves
  through the device's own timezone handling (DST-correct). Picking a
  city stores its true IANA id.
- Bundled rules reflect current IANA rules; a future rule change by a
  government would ship as app data in an update. Stored local
  date/time + zone id are preserved so re-resolution stays possible.

# PRD v1.5 delta (2026-11-11) — implemented in Festivus-v4
- Event-name entry switches from the custom character editor to
  Garmin's native WatchUi.TextPicker (PRD 9.4/10.3); the custom
  character-selection editor is removed entirely (out of scope now).
- TextEntryController delegate only stores the confirmed text into the
  form session and never pushes/pops views inside the callback (the
  system dismisses the picker; the form rebuilds on return). Cancel
  preserves the previous name and all other form values.
- Names capped at 20 characters on return; non-empty validation at
  Save unchanged. Everything else from v1.4 is unchanged.
