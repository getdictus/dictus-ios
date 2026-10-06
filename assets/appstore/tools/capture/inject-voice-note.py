#!/usr/bin/env python3
"""Offer a demo voice-note transcript to the Dictus keyboard in a simulator (#637).

Usage: inject-voice-note.py <udid> <language> <duration-seconds> "<transcript>"
       inject-voice-note.py <udid> --hide

Writes one delivery file where DictusApp writes it after a shared voice note is
transcribed (VoiceNoteKeyboardDeliveryStore: VoiceNotes/KeyboardDelivery/
Deliveries/<id>.json), then posts voiceNoteResultReady. The shipping keyboard
shows its chip; tapping the chip (axe tap --tap-style physical) opens the real
reader. A simulator cannot receive a WhatsApp voice message, so this is the only
way to show the reader there; the UI on screen is the shipping one.

--hide writes the marker the reader's delete button writes
(VoiceNoteKeyboardDeliveryStore.deleteFromKeyboard, Deleted/<id>, #639), which
takes the demo note out of the keyboard without deleting any file. Since #639 a
receipt alone no longer hides a note.
"""
import datetime
import json
import os
import subprocess
import sys

DEMO_ID = "6F1C2A8E-3B4D-4E5F-9A1B-2C3D4E5F6A7B"


def iso(d):
    # VoiceNoteDates: ISO 8601 with fractional seconds, UTC.
    return d.strftime("%Y-%m-%dT%H:%M:%S.") + f"{d.microsecond // 1000:03d}Z"


def group_root(udid):
    out = subprocess.run(["xcrun", "simctl", "get_app_container", udid, "com.pivi.dictus", "groups"],
                         capture_output=True, text=True, check=True).stdout
    for line in out.splitlines():
        if line.startswith("group.solutions.pivi.dictus"):
            return os.path.join(line.split("\t", 1)[1], "VoiceNotes", "KeyboardDelivery")
    raise SystemExit("App Group not found: install and launch Dictus first")


def main():
    udid = sys.argv[1]
    root = group_root(udid)
    now = datetime.datetime.now(datetime.timezone.utc)
    if sys.argv[2] == "--hide":
        folder = os.path.join(root, "Deleted")
        os.makedirs(folder, exist_ok=True)
        open(os.path.join(folder, DEMO_ID), "w").close()
        return
    language, duration, transcript = sys.argv[2], int(sys.argv[3]), sys.argv[4]
    folder = os.path.join(root, "Deliveries")
    os.makedirs(folder, exist_ok=True)
    delivery = {
        "id": DEMO_ID,
        "transcript": transcript,
        "sharedAt": iso(now - datetime.timedelta(minutes=2)),
        "transcribedAt": iso(now - datetime.timedelta(minutes=1)),
        "language": language,
        "durationSeconds": duration,
    }
    with open(os.path.join(folder, f"{DEMO_ID}.json"), "w") as f:
        json.dump(delivery, f)
    subprocess.run(["xcrun", "simctl", "spawn", udid, "notifyutil", "-p",
                    "com.pivi.dictus.voiceNoteResultReady"], check=True)


if __name__ == "__main__":
    main()
