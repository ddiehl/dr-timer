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
   your Bluetooth headset if it is connected, the phone speaker if not.
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
- The phone's media volume decides how loud the alert is. Turn it up before flight.
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

## Checks

| # | Steps | Expected | Result |
|---|-------|----------|--------|
| a | Connect the Bluetooth headset and put it on. Silent switch **off**. Open Fly, pick the test flight, tap START, keep the app open and wait 15 s. | At 0:00 the alert beeps loudly **in the headset** and keeps repeating. The phone vibrates about once a second. Tapping "OVER IT" stops both and starts leg 2. | |
| b | Same as (a), but with the **silent switch on** (or Silent Mode on via the Action button). Repeat once with the headset disconnected. | Sound still plays: in the headset, or on the phone speaker without the headset. Vibration still happens. | |
| c | Start a leg with a longer time (e.g. 5:00, or leave the app on the ready screen) and do not touch the phone for longer than your Auto-Lock setting (Settings > Display & Brightness > Auto-Lock). | The screen never dims or locks while the app is open. After you leave the app, the phone locks normally again. | |
| d | Start a 15 s leg, then **press the side button to lock** the phone right away. Test once with the silent switch off and once with it on. Wait. | At time-up the alert sounds (headset or speaker) and keeps repeating, and the phone vibrates, with no unlocking needed. The "TIME'S UP" notification also appears. After you unlock and open the app, the time's-up screen is showing and tapping the button stops the sound. | |
| e | Start a 15 s leg, then **force-quit** the app (swipe it away in the app switcher). Wait more than 15 s, then open the app. | While the app is closed, the notification appears at time-up with the landmark and its sound plays once (expect no sound with the silent switch on: that is the known limit). When you reopen, the time's-up screen shows straight away and the alert rings until you tap. | |
| f | Let any leg reach time-up and look at the screen at arm's length, ideally in bright light. | The background alternates red and blue about twice a second. The long landmark text is fully readable in both colours, with nothing cut off. | |

If **(b)** or **(d)** fails, the alert approach must be changed before this app is used
in flight. Write down exactly what happened (sound? vibration? notification?
headset or speaker?) and report it back.
