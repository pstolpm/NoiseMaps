# Installationsanleitung (Release-APK)

Diese Anleitung richtet sich an alle, die NoiseMaps **ohne** Flutter, Android Studio oder sonstige Entwicklungsumgebung ausprobieren möchten – nur mit der fertigen Datei `app-release.apk`.

## Was wird benötigt?

- ein Android-Gerät (Smartphone/Tablet ab Android 8.0) **oder** ein Android-Emulator
- die Datei `app-release.apk` (liegt bei der Abgabe bei bzw. entsteht beim Bauen unter `build/app/outputs/flutter-apk/app-release.apk`)

## Installation auf einem echten Android-Gerät

1. Die Datei `app-release.apk` auf das Gerät übertragen (z. B. per USB-Kabel, E-Mail-Anhang oder Cloud-Speicher).
2. Auf dem Gerät die Datei im Dateimanager antippen.
3. Falls eine Meldung erscheint, dass „Apps aus unbekannten Quellen" nicht erlaubt sind: der Aufforderung folgen und die Installation für die jeweilige App (z. B. den Dateimanager) einmalig erlauben. Das ist normal – es betrifft jede App, die nicht über den Play Store installiert wird.
4. „Installieren" antippen, kurz warten, „Öffnen" antippen.
5. Beim ersten Start nach Mikrofon- und Standortberechtigung fragen lassen und beide erlauben – ohne diese Berechtigungen kann keine Messung durchgeführt werden.

## Installation auf einem Android-Emulator (z. B. für Testzwecke)

Voraussetzung: Android SDK Platform Tools (Befehl `adb`) sind installiert und ein Emulator läuft bereits.

1. Prüfen, dass der Emulator erkannt wird:
   ```
   adb devices
   ```
2. APK installieren:
   ```
   adb install app-release.apk
   ```
   Läuft mehr als ein Gerät gleichzeitig, das Zielgerät angeben:
   ```
   adb -s <geraete-id> install app-release.apk
   ```
3. App im App-Drawer öffnen (petrolfarbenes „N"-Icon).

## Kurzer Funktionstest nach der Installation

1. App öffnen, „Messung starten" antippen.
2. Mikrofon- und Standortberechtigung erlauben.
3. Ein paar Sekunden warten, bis die Messung abgeschlossen ist.
4. Ergebnis ansehen (Pegel, erkannte Geräuschquelle, Confidence).
5. Über „Karte" prüfen, dass der neue Messpunkt angezeigt wird.

## Bekannte Hinweise

- Die App ist mit rund 100 MB vergleichsweise groß, weil das KI-Modell (YAMNet) vollständig in der App enthalten ist und lokal auf dem Gerät läuft – es wird keine Internetverbindung für die Messung oder Klassifikation benötigt.
- Die App zeigt beim Start deutlich, dass Messwerte indikativ und nicht amtlich kalibriert sind.
- Für die Kartenanzeige wird eine Internetverbindung benötigt (Kartenkacheln von OpenFreeMap); die Messfunktion selbst funktioniert auch offline.
