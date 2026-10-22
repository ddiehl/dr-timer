# Real-device alert checklist

The simulator cannot test sound routing, the silent switch, vibration or locking,
so these checks must be run on your iPhone before you rely on the app in flight.
Nothing below has been run yet. Fill in the Result column (PASS / FAIL plus a note)
yourself.

## How the alert works (so you know what you are testing)

1. **Foreground (the normal case).** The screen stays awake while the app is open.
   At time-up the app plays `alert.wav` on a loop and vibrates about once a second
   until you tap the button. The sound uses the `.playback` audio category, which
   ignores the silent switch and plays through whatever audio output is active:
   your Bluetooth headset if it is connected, the phone speaker if not. It plays
   on top of other apps' audio (it does not stop or lower them). About once a
   second the app checks the alert is really playing and restarts it if not.
2. **Phone locked or app in background.** While a leg is counting down, the app
   plays a *silent* audio loop. Because the app declares background audio, iOS
   keeps an app that is playing audio running, so the app's own timer can still
   start the real alert at the exact end time. Without that silent loop iOS
   suspends the app a few seconds after you lock the phone, and a suspended app
   cannot start sound by itself.
3. **App not running at all** (force-quit, or iOS killed it). Only the scheduled
   local notification is left. It shows "TIME'S UP / Look for: <landmark>" and
   plays the first 28 s of `alert.wav` **once**. A notification sound follows
   the ringer, so **with the silent switch on it is likely to be silent**
   (vibration only, depending on your Sounds & Haptics settings). When you
   open the app after the end time, it shows the time's-up screen and starts
   ringing.

Known limits (not verified on a device):
- A phone call, Siri or another app taking over audio pauses the silent loop.
  The app tries to resume when the interruption ends. If iOS suspends the app
  during a long interruption, only the notification remains.
- iOS may still end a background app under memory pressure. You would then get
  only the notification (see 3).
- Vibration from the background (2) is expected but not guaranteed. Check it in (d).
- **The phone's media volume (and the headset's own volume) decides how loud the
  alert is. The app cannot raise it and does not warn you if it is low.** A
  muted or near-zero media volume means a silent alarm. See the pre-flight step.
- Focus or Do Not Disturb can hide the fallback notification in case 3. The in-app
  alarm in cases 1 and 2 is not a notification and should not be affected.

## Setup

- Install from Xcode onto the iPhone and allow notifications when asked. The
  prompt appears the first time you open the Fly tab. If you missed it, go to
  Settings > Notifications > DR Timer and turn on Allow Notifications and Sounds.
- Create a test flight with leg 1 = 0:15 (landmark: a long name such as
  "Large white barn with a red roof next to the grain elevator by hwy 12"),
  and leg 2 = 0:15 "Tower".
- Media volume up (use the volume buttons while the app is open).

## Pre-flight (every flight, not just testing)

1. Open DR Timer, press the **volume-up** button until the media volume bar is
   high (at least three-quarters). The bar must show while DR Timer is open; the
   ringer volume in Settings is a different setting and does not matter here.
2. Connect the headset, and check its own Bluetooth/music volume knob is up.
   Play a few seconds of any audio from the phone to confirm you hear it in the
   headset.
3. Keep the app open on the Fly tab for the whole flight.

## Checks

| # | Steps | Expected | Result |
|---|-------|----------|--------|
| a | Connect the Bluetooth headset and put it on. Silent switch **off**. Open Fly, pick the test flight, tap START, keep the app open and wait 15 s. | At 0:00 the alert beeps loudly **in the headset** and keeps repeating. The phone vibrates about once a second. Tapping "OVER IT" stops both and starts leg 2. | |
| b | Same as (a), but with the **silent switch on** (or Silent Mode on via the Action button). Repeat once with the headset disconnected. | Sound still plays: in the headset, or on the phone speaker without the headset. Vibration still happens. | |
| c | Start a leg with a longer time (e.g. 5:00, or leave the app on the ready screen) and do not touch the phone for longer than your Auto-Lock setting (Settings > Display & Brightness > Auto-Lock). | The screen never dims or locks while the app is open. After you leave the app, the phone locks normally again. | |
| d | Start a 15 s leg, then **press the side button to lock** the phone right away. Test once with the silent switch off and once with it on. Wait. | At time-up the alert sounds (headset or speaker) and keeps repeating, and the phone vibrates, with no unlocking needed. The "TIME'S UP" notification also appears. After you unlock and open the app, the time's-up screen is showing and tapping the button stops the sound. | |
| e | Start a 15 s leg, then **force-quit** the app (swipe it away in the app switcher). Wait more than 15 s, then open the app. | While the app is closed, the notification appears at time-up with the landmark and its sound plays once (expect no sound with the silent switch on: that is the known limit). When you reopen, the time's-up screen shows straight away and the alert rings until you tap. | |
| f | Let any leg reach time-up and look at the screen at arm's length, ideally in bright light. | The background alternates red and blue about twice a second. The long landmark text is fully readable in both colours, with nothing cut off. | |

## Extended checks for the locked or background path

These cover the high-risk case where the app is not on screen at time-up. Use a
real leg length unless stated. "Rings" means the looping alert is heard (headset
or speaker) and the phone vibrates, without unlocking.

| # | Steps | Expected | Result |
|---|-------|----------|--------|
| g | Start a leg of **at least 10 minutes** (ideally a real leg length). Lock the phone immediately and leave it. | Rings at time-up. | |
| h | Start a 2-minute leg, switch to **another app** (ForeFlight, or Apple Maps navigating) and stay in it. | Rings at time-up over the other app. The banner appears. | |
| i | Same as (h), but with the other app **playing audio** (Maps voice guidance, or music in Music). | The alert is heard on top of the other audio. The other audio keeps playing. | |
| j | Start a 2-minute leg. Mid-leg, **make or receive a phone call** for about 30 s, hang up, then lock the phone. | Rings at time-up. | |
| k | Start a 1-minute leg and arrange a **phone call to be in progress at time-up** (have someone call you). | Note what happens during the call, and whether it rings once the call ends. | |
| l | Start a 1-minute leg, **hold the side button for Siri** mid-leg and ask something, then lock. Repeat with Siri active right at time-up. | Rings at time-up (or as soon as Siri finishes). | |
| m | Let it ring with the headset connected, then **switch the headset off** while it rings. | Ringing continues on the phone speaker. | |
| n | Start a leg with the headset **off**, then **switch it on** mid-leg, then lock. | Rings in the headset at time-up. | |
| o | With the **real aviation headset**, fly or simulate a long leg (30+ min) with the app counting. | No odd headset behaviour from the silent audio stream: intercom or ATC is not muted, auto-mute or "music priority" does not kick in, nothing is audible. | |
| p | Multi-leg run: legs of 1 min each, at least 3 legs. Lock the phone during leg 1; when it rings, unlock, tap "OVER IT", **lock again** straight away. Repeat for legs 2 and 3. | Rings at the end of every leg, not just the first. | |
| q | Start leg 1 (1 min), tap through to leg 2 (1 min), then **force-quit** during leg 2. | Exactly one notification arrives, at the end of **leg 2**, naming leg 2's landmark (no stale leg-1 notification). | |
| r | In Settings, **turn off notifications** for DR Timer. Repeat (a) and (d). | (a) and (d) still ring: the in-app alert does not depend on notification permission. Only the force-quit fallback (e) is lost. Turn notifications back on afterwards. | |
| s | Turn on a **Focus / Do Not Disturb**. Repeat (d) and (e). | (d) still rings. Note whether the (e) notification is shown or hidden. | |
| t | Turn on **Low Power Mode**. Repeat (d) and (g). | Still rings. | |
| u | Battery: note the battery % at the start of a **1 to 2 h** run (or a ground test with long legs), with the headset connected. | Note the % used per hour: ____ %/h. It must be comfortably affordable for your longest flight. | |
| v | While a leg counts, **pull down Control Center** (or Notification Center) and leave it open for longer than your Auto-Lock time. | The screen does not dim or lock while Control Center is open. | |

If **(b)** or **(d)** fails, the alert approach must be changed before this app is used
in flight. The same applies to any failure in (g) to (q). Write down exactly what happened (sound? vibration? notification?
headset or speaker?) and report it back.
