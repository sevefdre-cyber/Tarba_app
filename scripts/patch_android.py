#!/usr/bin/env python3
"""Adapte le projet Android genere par `flutter create` : permissions, service, notifications natives."""
import glob
import os
import re
import sys

ROOT = "android/app/src/main"
MANIFEST = os.path.join(ROOT, "AndroidManifest.xml")

if not os.path.exists(MANIFEST):
    sys.exit("AndroidManifest.xml introuvable : le projet Android n'a pas ete genere")

s = open(MANIFEST, encoding="utf-8").read()

perms = [
    "INTERNET",
    "POST_NOTIFICATIONS",
    "FOREGROUND_SERVICE",
    "FOREGROUND_SERVICE_DATA_SYNC",
    "WAKE_LOCK",
]
add = "".join(
    '    <uses-permission android:name="android.permission.%s"/>\n' % p
    for p in perms
    if 'android.permission.%s"' % p not in s
)
if add:
    idx = s.index("<application")
    s = s[:idx] + add.lstrip() + "    " + s[idx:]

s = re.sub(r'android:label="[^"]*"', 'android:label="Crypto Radar"', s, count=1)

if "RadarService" not in s:
    service = (
        '        <service android:name=".RadarService" android:exported="false" '
        'android:foregroundServiceType="dataSync"/>\n    '
    )
    s = s.replace("</application>", service + "</application>", 1)

open(MANIFEST, "w", encoding="utf-8").write(s)

# Kotlin : on remplace MainActivity et on ajoute RadarService dans le meme package.
found = glob.glob(os.path.join(ROOT, "kotlin", "**", "MainActivity.kt"), recursive=True)
if not found:
    sys.exit("MainActivity.kt introuvable")
main_path = found[0]
pkg = re.search(r"^package\s+([\w.]+)", open(main_path, encoding="utf-8").read(), re.M).group(1)
out_dir = os.path.dirname(main_path)

for tpl, name in (("MainActivity.kt.tpl", "MainActivity.kt"), ("RadarService.kt.tpl", "RadarService.kt")):
    code = open(os.path.join("android_overlay", tpl), encoding="utf-8").read().replace("__PKG__", pkg)
    open(os.path.join(out_dir, name), "w", encoding="utf-8").write(code)

print("Android patche (package %s)" % pkg)
