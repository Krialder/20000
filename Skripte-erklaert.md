# Jede Datei erklärt: was genau passiert und warum

Diese Referenz beschreibt jede Datei im Paket einzeln: was sie genau tut, warum, welche Parameter es gibt und was sie am System verändert. Reihenfolge wie im Ablauf. Die Schritt-für-Schritt-Anleitung steht in `Win10-Pro-Lockdown-Anleitung-fuer-Einsteiger.md`, die ganz einfache Fassung in `Win10-Pro-Lockdown-Komplett-fuer-Dummies.md`, die fachliche Bewertung in `Bewertung-und-Iteration.md`.

## Wiederkehrende Begriffe

- **Vertrauensperson:** richtet alles als Administrator ein, hält alle Geheimnisse.
- **Verwaltetes Konto:** das Standardkonto der betroffenen Person, ohne Adminrechte.
- **Audit-Modus:** eine Regel ist aktiv, blockiert aber nichts, sondern protokolliert nur. Dient zum Testen.
- **Erzwingen:** dieselbe Regel blockiert jetzt wirklich.
- **Idempotent:** ein Skript kann man mehrfach laufen lassen, es stellt nur den Sollzustand her.
- Jedes Skript schreibt ein **Protokoll** nach `%USERPROFILE%` mit Zeitstempel und verlangt eine als Administrator gestartete PowerShell.

---

## _Common.ps1

**Was es tut:** Sammelstelle für gemeinsame Funktionen (farbige Ausgaben, Gruppen über die SID finden, Registry-Werte setzen, die Richtlinie für BitLocker ohne TPM setzen). Wird von jedem Skript automatisch über `. "$PSScriptRoot\_Common.ps1"` geladen.

**Warum:** Damit jede Funktion nur einmal existiert und alle Skripte sich gleich verhalten. Spart Wiederholung und Fehler.

**Wichtig:** Nicht direkt ausführen, das macht nichts. Es ist eine Bibliothek, kein eigenständiger Schritt.

---

## 00-Pruefung.ps1

**Was es tut:** Liest nur aus, ändert nichts. Zeigt Edition, Windows-Version, ob Secure Boot aktiv ist, ob ein TPM vorhanden und einsatzbereit ist, den BitLocker-Status samt vorhandener Schlüsselschutzvorrichtungen, die Mitglieder der Administratorengruppe und die aktivierten riskanten Features.

**Warum:** Bestandsaufnahme vor jedem Eingriff. So siehst du zum Beispiel, dass euer Laptop kein nutzbares TPM hat und was dein Freund an BitLocker schon eingerichtet hat, bevor du etwas änderst.

**Ändert:** nichts.

---

## 10-Konten.ps1

**Was es tut:** Legt das Adminkonto der Vertrauensperson und das Standardkonto der Person an und stuft ein vorhandenes Konto vom Admin zum Standardbenutzer herab. Fragt Passwörter sicher ab. Weigert sich, den letzten Administrator zu entfernen.

**Warum:** Das Standardkonto ohne Adminrechte ist nach der Schlüsselgewalt die wichtigste Einzelmaßnahme. Ein Standardnutzer kann keine Software systemweit installieren, keine Netzwerkeinstellungen ändern, kein zweites Adminkonto anlegen und die Schutzmaßnahmen nicht abschalten.

**Parameter:** `-AdminKonto`, `-StandardKonto`, `-HerabstufenKonto`.

**Ändert:** lokale Benutzerkonten und Gruppenmitgliedschaften.

---

## 20-BitLocker.ps1

**Was es tut:** Verschlüsselt das Systemlaufwerk mit XTS-AES-256. Kennt vier Modi: `Tpm` (Schlüssel im TPM, unbeaufsichtigter Start), `PasswortOhneTpm` (Pre-Boot-Passwort), `UsbSchluesselOhneTpm` (USB-Startschlüssel), `Auto`. Für die Ohne-TPM-Modi setzt es vorher die nötige Gruppenrichtlinie (`EnableBDEWithNoTPM` unter `HKLM\SOFTWARE\Policies\Microsoft\FVE`). Fügt immer einen 48-stelligen Wiederherstellungsschlüssel hinzu, zeigt ihn an und speichert ihn in eine Datei. Erkennt, wenn BitLocker schon läuft, und sichert dann nur den Wiederherstellungsschlüssel.

**Warum:** Ohne Verschlüsselung baut ein Angreifer die Platte aus und liest oder verändert sie an einem anderen Rechner, womit alle Sperren fallen. Die Verschlüsselung schließt diesen Offline-Weg. Ohne TPM braucht der Start ein Geheimnis, deshalb die Modi.

**Parameter:** `-Modus`, `-SchluesselDatei`, `-StartupKeyLaufwerk`.

**Ändert:** FVE-Richtlinie in der Registry, BitLocker-Status und Schlüsselschutzvorrichtungen des Laufwerks. Der Wiederherstellungsschlüssel gehört ausschließlich der Vertrauensperson.

---

## 30-Haertung.ps1

**Was es tut:** Setzt Registry-Werte. `NoConnectedUser` unter `HKLM\...\Policies\System` sperrt das Hinzufügen fremder Microsoft-Konten. Mehrere Edge-Werte unter `HKLM\SOFTWARE\Policies\Microsoft\Edge` schalten Edges eigenes verschlüsseltes DNS, den InPrivate-Modus und das Anlegen weiterer Profile aus.

**Warum:** Ein fremdes Microsoft-Konto wäre ein frischer, unkontrollierter Profil- und Synchronisierungskanal. Edges eigenes DNS würde die Netzfilterung umgehen. Diese Basisriegel gehören gesetzt, auch wenn Edge später ohnehin gesperrt wird.

**Parameter:** `-NoConnectedUser` (1 für verwaltetes Konto, 3 für rein lokal).

**Ändert:** Registry. Wirkt nach dem nächsten Anmelden.

---

## 42-Edge-und-KI-deaktivieren.ps1

**Was es tut:** Schaltet jede KI ab und neutralisiert Edge. Setzt `TurnOffWindowsCopilot`, schaltet die Web- und KI-Suche im Startmenü aus (`AllowCortana`, `DisableWebSearch`, `ConnectedSearchUseWeb`), deaktiviert per Edge-Richtlinie Copilot, Sidebar, Discover, den Shopping-Assistenten und den Erststart, und verhindert per `EdgeUpdate`-Richtlinie die Neuinstallation. Mit `-EdgeDeinstallieren` ruft es zusätzlich den Edge-Deinstaller auf.

**Warum:** Ziel ist, dass keinerlei KI läuft. Die eigentliche Sperre von Edge für den Nutzer macht die AppLocker-Whitelist, hier kommen die Richtlinien als zweite Sicherung dazu. WebView2 bleibt absichtlich erlaubt, sonst brechen Programme, die es einbetten.

**Parameter:** `-EdgeDeinstallieren` (optional, da Updates die Deinstallation rückgängig machen können).

**Ändert:** Registry-Richtlinien für Copilot, Suche, Edge und EdgeUpdate. Wirkt nach dem nächsten Anmelden.

---

## 40-Features.ps1

**Was es tut:** Deaktiviert optionale Windows-Features: Hyper-V, Windows-Sandbox, Windows-Subsystem für Linux (WSL), die Plattform für virtuelle Computer, die Hypervisor-Plattform und PowerShell 2.0.

**Warum:** Jedes dieser Features ist eine eigene Ausführungsumgebung, die an der Whitelist vorbeiführt. Eine virtuelle Maschine oder WSL ist eine Insel mit eigenem System und Browser, die AppLocker auf dem Wirt nicht regiert. PowerShell 2.0 umgeht den eingeschränkten Sprachmodus. Darum gehören sie aus.

**Parameter:** keine.

**Ändert:** Windows-Features. **Erfordert einen Neustart**, damit es wirkt.

---

## 50-Dns.ps1

**Was es tut:** Trägt an allen aktiven Netzwerkadaptern einen gefilterten DNS-Server ein, standardmäßig Cloudflare Families.

**Warum:** Ein gefilterter DNS sperrt bekannte Shop- und Schadseiten schon am Gerät, und ein Standardnutzer kann diese Adaptereinstellung ohne Adminrechte nicht ändern. Wichtig: das ist nur Reibung, kein verlässlicher Schutz, weil eine direkte IP-Adresse oder verschlüsseltes DNS daran vorbeigeht. Der Router ist die wirksame Stelle.

**Parameter:** `-DnsServer`.

**Ändert:** DNS-Einträge der Adapter.

---

## firefox-policies.json

**Was es tut:** Die Konfigurationsdatei, die Firefox sperrt. Schaltet alle KI-Funktionen aus (`browser.ml.*`, `extensions.ml.enabled`), verschlüsseltes DNS aus (`network.trr.mode` = 5), Passwort- und Formularspeicher aus, privates Surfen aus, sperrt about:config und das Installieren von Erweiterungen, schaltet Telemetrie, Pocket und Konten aus.

**Warum:** Firefox ist der einzige erlaubte Browser, also muss er selbst gehärtet sein. Kein gespeichertes Zahlungsmittel im Browser, keine KI, keine Hintertür über about:config oder eine Erweiterung, kein verschlüsseltes DNS, das die Filterung umgeht.

**Wird genutzt von:** 45-Firefox-haerten.ps1.

---

## 45-Firefox-haerten.ps1

**Was es tut:** Findet die Firefox-Installation und kopiert `firefox-policies.json` in deren `distribution`-Ordner, wo Firefox sie als verbindliche Richtlinie liest.

**Warum:** Per-Datei-Richtlinie ist die einzige Art, Firefox zentral und unveränderbar einzustellen. Ein Standardnutzer kann die Datei im Programmordner nicht ändern.

**Parameter:** `-PolicyDatei`.

**Ändert:** legt `policies.json` im Firefox-Programmordner an. Prüfen über `about:policies` in Firefox.

**Voraussetzung:** Firefox muss installiert sein, am besten nach Program Files.

---

## AppLocker-Policy.xml

**Was es tut:** Die eigentliche Whitelist als Regelwerk. Erlaubt für das verwaltete Konto nur den Windows-Ordner, Firefox und ausdrücklich eingetragene Arbeitsprogramme. Sperrt für dieses Konto Edge und andere Browser, LOLBins (mshta, wscript, cscript, regsvr32, msdt, MSBuild, InstallUtil, RegAsm, RegSvcs) und die für Standardnutzer beschreibbaren Unterordner unter Windows. Administratoren dürfen alles. Enthält Platzhalter (`__MODE__`, `__DLLMODE__`, `__SID__`), die das Setup-Skript ersetzt.

**Warum:** Eine echte Allowlist ist gegen einen versierten Nutzer die einzig tragfähige Bauart, weil Sperren einzelner Programme durch Umbenennen umgangen werden. Der Windows-Ordner muss erlaubt bleiben, sonst startet das System nicht, deshalb die gezielten Deny-Regeln gegen die bekannten Lücken darin.

**Wird genutzt von:** 60-AppLocker-Einrichten.ps1. Erweitert von 63-AppLocker-Programm-erlauben.ps1.

---

## 63-AppLocker-Programm-erlauben.ps1

**Was es tut:** Nimmt ein benötigtes Programm in die Whitelist auf. Scannt den angegebenen Ordner oder die EXE, erzeugt bevorzugt Herausgeber-Regeln (die Updates überstehen) mit Hash-Rückfall für unsignierte Dateien, macht die Herausgeber-Regeln versionsunabhängig und trägt sie in AppLocker-Policy.xml ein.

**Warum:** Weil Program Files nicht mehr pauschal erlaubt ist, läuft anfangs nur Windows und Firefox. Jedes weitere benötigte Programm muss bewusst freigegeben werden. So bleibt die Liste minimal und nachvollziehbar.

**Parameter:** `-Pfad` (ein oder mehrere), `-MitDll`, `-Bevorzugt` (Publisher oder Hash).

**Ändert:** AppLocker-Policy.xml. Danach 60-AppLocker-Einrichten.ps1 erneut ausführen.

**Hinweis:** Hash-Regeln entstehen bei unsignierten Programmen und müssen nach jedem Update des Programms neu erzeugt werden.

---

## 60-AppLocker-Einrichten.ps1

**Was es tut:** Setzt die Whitelist scharf oder in den Test. Stellt den Application Identity Service (`AppIDSvc`) auf Automatisch (über `sc.exe` und Registry, weil er ein geschützter Dienst ist), ermittelt die SID des verwalteten Kontos, ersetzt die Platzhalter in der XML und setzt die Richtlinie mit `Set-AppLockerPolicy`.

**Warum:** AppLocker erzwingt nur, wenn der AppIDSvc läuft. Die Deny-Regeln müssen auf die genaue SID des Nutzers zeigen, damit die Vertrauensperson als Admin nicht mitgesperrt wird. Ohne `-Erzwingen` läuft alles im Audit-Modus, damit du gefahrlos siehst, was die Person legitim braucht.

**Parameter:** `-StandardKonto` (Pflicht), `-Erzwingen`, `-DllRegeln`.

**Ändert:** den AppIDSvc und die lokale AppLocker-Richtlinie. **Neustart empfohlen.** Nach dem Erzwingen läuft die PowerShell des Nutzers im eingeschränkten Sprachmodus.

---

## 61-AppLocker-Pruefen.ps1

**Was es tut:** Liest die AppLocker-Ereignisprotokolle und zeigt, was blockiert wurde oder im Audit-Modus blockiert worden wäre (Ereignisse 8003, 8004, 8006, 8007).

**Warum:** Im Audit-Modus ist das die Liste der Programme, die im scharfen Betrieb scheitern würden. So findest und ergänzt du fehlende Arbeitsprogramme, bevor du erzwingst.

**Parameter:** `-Anzahl`.

**Ändert:** nichts.

---

## 70-ColdTurkey.ps1

**Was es tut:** Füllt den Cold-Turkey-Block mit den Domains aus coldturkey-domains.txt und sperrt nicht erlaubte Browser und Launcher per App-Liste. Optional startet es den Block gesperrt für eine Anzahl Minuten.

**Warum:** Zusätzliche Reibung gegen Shopping- und KI-Seiten direkt im laufenden System. Cold Turkey hat keine vollständige Automatisierung, deshalb macht das Skript nur das Befüllen und Starten. Die Härtung gegen Abschalten (Selbstverteidigung, Passwortsperre, gesperrter Zeitplan) wird einmalig in der Oberfläche gesetzt.

**Parameter:** `-BlockName`, `-DomainDatei`, `-Apps`, `-StartLockMinuten`, `-ExePfad`.

**Ändert:** die Cold-Turkey-Konfiguration. Firefox bleibt absichtlich erlaubt.

**Hinweis:** Cold Turkey läuft mit Nutzerrechten und wird erst durch das Standardkonto ernst. Es ist Zusatzschicht, nicht tragende Wand.

---

## coldturkey-domains.txt

**Was es tut:** Die Liste der zu sperrenden Domains, eine pro Zeile, gruppiert in Händler, Elektronik, Mode, Marktplätze, Buy-now-pay-later, Gaming-Stores, Deal-Seiten und KI-Dienste. Zeilen mit `#` sind Kommentare.

**Warum:** Trennt die Inhalte von der Logik, damit du Domains leicht ergänzen oder entfernen kannst, ohne das Skript anzufassen.

---

## 90-Selbsttest.ps1

**Was es tut:** Prüft den erreichten Zustand: BitLocker-Schutz und Protektoren, AppLocker-Erzwingungsstatus, deaktivierte Features, die Kontosperre, ob Cold Turkey installiert ist. Listet die Versuche auf, die du danach von Hand im verwalteten Konto durchspielen solltest.

**Warum:** Vertrauen ist gut, Nachweis ist besser. Der Test zeigt, ob jede Schicht wirklich greift, und nennt die konkreten Umgehungsversuche zum Nachstellen.

**Parameter:** keine.

**Ändert:** nichts.

---

## Optional-WDAC\ (60-WDAC-Audit, 61-WDAC-Pruefen, 62-WDAC-Erzwingen)

**Was es tut:** Die stärkere, kernelnahe Alternative zur Ausführungskontrolle (App Control for Business statt AppLocker). Baut eine Richtlinie aus einem Scan plus Microsofts Sperrlisten, rollt sie erst im Audit-Modus, dann erzwungen aus.

**Warum:** WDAC setzt tiefer an als AppLocker und ist robuster gegen einen versierten Angreifer, aber aufwändiger einzurichten. Liegt als Option bereit. Entweder AppLocker oder WDAC nutzen, nicht beides.

**Hinweis:** Diese Skripte brauchen die mitkopierte `_Common.ps1` im selben Ordner.
