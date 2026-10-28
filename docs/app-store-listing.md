# App Store listing copy

Paste-ready metadata for App Store Connect. Keep this in sync when the listing
changes, so the wording survives in version control.

Only three fields are indexed for App Store search: **name**, **subtitle** and
**keywords**. The description is not indexed — it converts a visitor who is
already looking at the page. Apple indexes the union of the three and builds
search phrases by combining words across them, so no word should appear twice.

## Name (30 char limit)

```
Pilot Timer: Dead Reckoning
```

27 characters. This is the App Store listing name only — it is independent of
`CFBundleDisplayName` in `project.yml`, which stays `Pilot Timer` and is what
appears under the icon on the home screen.

## Subtitle (30 char limit)

```
VFR cross-country nav legs
```

26 characters. Carries no word already used in the name.

## Keywords (100 char limit)

Comma-separated, no spaces after commas — a space costs a character. Omits
every word already in the name and subtitle.

```
pilotage,navlog,flight,training,student,checkride,E6B,ETE,aviation,stopwatch,countdown,PPL,CFI,ETA
```

98 characters.

`E6B` is the one judgement call: the app is not a flight computer, but it sits
in the same dead-reckoning workflow and the term carries real search traffic.
Drop it if a reviewer objects under guideline 2.3.7 (relevant metadata).

## Promotional text (170 char limit)

Not indexed, but it can be changed without shipping a new build — useful for
announcements.

```
Now with leg-by-leg countdown, audible and vibrating time-up alerts, and a volume warning so you never miss a turn. Free, no account, nothing leaves your phone.
```

## Description

```
Fly your cross-country legs on time.

Pilot Timer is a dead-reckoning timer for VFR navigation. Plan a route as a list of legs — a landmark and a time in minutes and seconds — then fly it. Each leg counts down, rings and vibrates when the time is up, and one tap starts the next.

Built for student pilots working through cross-country training, and for anyone who still navigates by chart, compass and clock.

• Plan a flight as a sequence of named legs
• Each leg counts down to zero, then rings and vibrates
• One tap advances to the next leg
• Keeps running with the phone locked, and still sounds the alert
• Warns you when the volume is too low to hear the alert
• Flights are saved on the device and ready to fly again
• No account, no network, no tracking

Pilot Timer is a timing aid for dead-reckoning practice. It is not a navigation system and is not certified for flight. Always fly with your planned charts, a watch and the aircraft's own instruments.
```

## Category

- Primary: **Navigation**
- Secondary: **Education**

## Privacy

The app stores flights as JSON on the device and makes no network requests, so
the privacy nutrition label is **Data Not Collected** on every category.

App Store Connect still requires a privacy policy URL for every app, including
one that collects nothing. Host one at `spartatechnology.com/privacy` — it can
be a short page stating that the app collects, transmits and stores no personal
data, and that flights never leave the device.
