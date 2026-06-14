# Lockdown Windows 10 Pro: Skriptpaket

Dieses Paket setzt die skriptbaren Teile des Lockdowns gegen Kaufzwang um, aufgeteilt in einzelne Dateien pro Phase. Ausführliche Erklärung aller Schritte, auch der manuellen (BIOS, Family Safety, Zahlung, Router), steht in `Win10-Pro-Lockdown-Anleitung-fuer-Einsteiger.md`. Die ganz einfache Fassung mit Glossar heißt `Win10-Pro-Lockdown-Komplett-fuer-Dummies.md`. Eine Erklärung jeder einzelnen Datei (was genau und warum) steht in `Skripte-erklaert.md`. Die fachliche Eigenbewertung steht in `Bewertung-und-Iteration.md`.

Ausführungskontrolle ist hier **AppLocker als echte Whitelist**: Für das verwaltete Konto läuft nur, was ausdrücklich erlaubt ist (Windows, Firefox, eingetragene Arbeitsprogramme), alles andere ist gesperrt. Browser ist nur **Firefox**, **Edge ist raus**, **keinerlei KI** (Copilot und Co.). WDAC liegt als stärkere optionale Alternative in `Optional-WDAC\`, nicht zusätzlich nutzen.

Alles wird von der **Vertrauensperson** in einer **als Administrator gestarteten PowerShell** ausgeführt, nicht im Alltagskonto.

## Vorbereitung

```powershell
cd "C:\Users\Kaide\Downloads\Lockdown-Win10Pro"
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

`_Common.ps1` enthält die gemeinsamen Funktionen und wird automatisch geladen. Nicht direkt ausführen.

## Reihenfolge

| Schritt | Datei | Was es tut | Danach |
|---|---|---|---|
| 1 | `00-Pruefung.ps1` | TPM, Secure Boot, Edition, BitLocker- und Kontostand | |
| 2 | `10-Konten.ps1` | Admin- und Standardkonto, Alltagskonto herabstufen | |
| 3 | `20-BitLocker.ps1` | Verschlüsselung, mit oder ohne TPM | |
| 4 | `30-Haertung.ps1` | NoConnectedUser, Edge-DoH-Basis | Neu anmelden |
| 5 | `42-Edge-und-KI-deaktivieren.ps1` | Windows- und Edge-Copilot, Web-Suche, Edge neutralisieren | |
| 6 | `40-Features.ps1` | WSL, VM, Hyper-V, Sandbox, PowerShell 2.0 aus | NEUSTART |
| 7 | `50-Dns.ps1` | gefilterter DNS am Gerät | |
| 8 | Firefox installieren (als Admin, nach Program Files) | dann | |
| 9 | `45-Firefox-haerten.ps1` | KI aus, DoH aus, Passwortspeicher aus, about:config gesperrt | |
| 10 | `63-AppLocker-Programm-erlauben.ps1` | jedes benötigte Arbeitsprogramm in die Whitelist | je Programm |
| 11 | `60-AppLocker-Einrichten.ps1` | Whitelist im Audit-Modus | NEUSTART, 1-2 Tage testen |
| 12 | `61-AppLocker-Pruefen.ps1` | blockierte Programme ansehen, fehlende ergänzen | |
| 13 | `60-AppLocker-Einrichten.ps1 -Erzwingen` | Whitelist scharf schalten | NEUSTART |
| 14 | `70-ColdTurkey.ps1` | Cold-Turkey-Block befüllen und sperren | GUI-Härtung, siehe unten |
| 15 | `90-Selbsttest.ps1` | Zustand prüfen | |

Beispielaufrufe:

```powershell
.\00-Pruefung.ps1
.\10-Konten.ps1 -AdminKonto "Verwalter" -StandardKonto "Alltag"
.\20-BitLocker.ps1 -Modus PasswortOhneTpm -SchluesselDatei "E:\BitLocker-Schluessel.txt"
.\30-Haertung.ps1 -NoConnectedUser 1
.\42-Edge-und-KI-deaktivieren.ps1
.\40-Features.ps1            # danach Neustart
.\50-Dns.ps1 -DnsServer "1.1.1.3","1.0.0.3"
# Firefox installieren, dann:
.\45-Firefox-haerten.ps1
# Jedes benoetigte Arbeitsprogramm aufnehmen, z.B.:
.\63-AppLocker-Programm-erlauben.ps1 -Pfad "C:\Program Files\Git","C:\Program Files\Notepad++"
.\60-AppLocker-Einrichten.ps1 -StandardKonto "Alltag"             # Audit, danach Neustart, testen
.\61-AppLocker-Pruefen.ps1
.\60-AppLocker-Einrichten.ps1 -StandardKonto "Alltag" -Erzwingen  # scharf, danach Neustart
.\70-ColdTurkey.ps1 -BlockName "Kaufsperre" -StartLockMinuten 1440
.\90-Selbsttest.ps1
```

> AppLocker zuletzt erzwingen. Sobald die Script-Regeln erzwingen, läuft die PowerShell des Nutzers im Constrained Language Mode. Erst alles andere fertig einrichten.

## Die Whitelist befüllen (wichtig)

Weil Program Files nicht mehr pauschal erlaubt ist, startet im verwalteten Konto zunächst nur Windows und Firefox. Jedes weitere benötigte Programm muss aufgenommen werden:

1. Programm als Admin sauber installieren, möglichst nach Program Files.
2. `63-AppLocker-Programm-erlauben.ps1 -Pfad "<Ordner oder EXE>"` aufrufen. Das erzeugt Herausgeber-Regeln (überleben Updates) mit Hash-Rückfall für unsignierte Dateien.
3. `60-AppLocker-Einrichten.ps1 -StandardKonto "Alltag"` erneut ausführen.

Per-User installierte Programme (zum Beispiel VS Code, Teams, Zoom, Spotify in `%LOCALAPPDATA%`) liegen außerhalb von Program Files und sind in der Whitelist gesperrt. Entweder die systemweite Variante nach Program Files installieren oder den Ordner mit `63-...` aufnehmen. Genau dafür ist der Audit-Modus da: er zeigt, was fehlt.

## BitLocker ohne TPM (euer Laptop)

`20-BitLocker.ps1` setzt die nötige Richtlinie (`EnableBDEWithNoTPM`) selbst.

- `-Modus PasswortOhneTpm`: Pre-Boot-Passwort bei jedem Start.
- `-Modus UsbSchluesselOhneTpm -StartupKeyLaufwerk "F:"`: USB-Startschlüssel bei jedem Start.

Hält die **Vertrauensperson** das Geheimnis, ist der Offline-Schutz voll, aber sie muss bei jedem Start dabei sein. Kennt es die **betroffene Person**, startet sie allein, doch der Offline-Angriff auf die ausgebaute Platte bleibt offen. Die übrigen Schichten greifen im Betrieb trotzdem. Ist BitLocker schon aktiv, sichert das Skript nur den Wiederherstellungsschlüssel.

## Cold Turkey: Skript und Oberfläche

Das Skript befüllt den Block aus `coldturkey-domains.txt` (Shopping und KI-Seiten) und sperrt nicht erlaubte Browser und Launcher (Firefox bleibt erlaubt). Die Härtung gegen Abschalten geht nur in der Oberfläche und nur einmal:

1. Cold Turkey Pro öffnen, Block **Kaufsperre** anlegen.
2. Settings, Blocking: Block Task Manager, Block Registry Editor, Block Time and Language settings, in Pro Block Safe Mode.
3. Gesperrten Zeitplan oder langen Timer anlegen.
4. Einstellungen mit Passwort der Vertrauensperson sperren.
5. Dann `70-ColdTurkey.ps1`.

> Cold Turkey läuft mit Nutzerrechten. Ernst wird es erst durch das Standardkonto. Es ist Zusatzschicht, nicht tragende Wand.

## Wartung später

Programm erlauben: als Admin installieren, `63-AppLocker-Programm-erlauben.ps1`, dann `60-AppLocker-Einrichten.ps1 -StandardKonto "Alltag"`.

AppLocker schnell aussetzen (Admin): `Stop-Service appidsvc` hält die Durchsetzung an, bis der Dienst wieder läuft. Dauerhaft entfernen: leere Richtlinie setzen oder `Set-AppLockerPolicy` mit einer NotConfigured-Policy.

Notausgang bei verschlüsselungsbedingtem Aussperren, nur mit dem BitLocker-Wiederherstellungsschlüssel, in WinRE: die betroffene Datei umbenennen und neu einrichten.

## Optional: WDAC statt AppLocker

`Optional-WDAC\` enthält die kernelnahe, stärkere Variante (60/61/62-WDAC). Sie ist robuster gegen einen versierten Angreifer, aber aufwändiger. Entweder AppLocker oder WDAC, nicht beides.

## Protokolle

Jedes Skript schreibt ein Protokoll nach `%USERPROFILE%` mit Zeitstempel.
