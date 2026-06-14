# Fachliche Bewertung und Iteration

Diese Datei dokumentiert die kritische Eigenprüfung des AppLocker-Whitelist-Ansatzes und die Korrekturen, in mehreren Durchläufen bis zum praktischen Optimum. Maßstab ist das Ziel und die Premise aus dem Projektgedächtnis.

## Ziel und Premise

Ein Windows 10 Pro Laptop ohne nutzbares TPM soll als Einkaufskanal verschlossen werden, gehärtet gegen eine technisch versierte Person (Coding, Netzwerk), mit deren Einwilligung als Selbstbindung. Eine Vertrauensperson hält alle Schlüssel. Fokus jetzt: AppLocker als echte Whitelist, Firefox als einziger Browser, Edge raus, keinerlei KI, nur das Nötigste zum Arbeiten, Cold Turkey als Zusatzschicht. Tragende Wände bleiben Zahlung und Netz-Egress.

## Methode

Bewerten, korrigieren, erneut bewerten, bis keine im Rahmen schließbare Lücke mehr offen ist. Jeder Durchlauf nennt Befund und Korrektur. Der letzte Durchlauf nennt die bewusst offenen Restpunkte.

## Architektonische Einordnung

AppLocker ist Ausführungs- und Browserkontrolle, also Härtung der lokalen Oberfläche. Es ist nicht die tragende Wand gegen einen Entwickler. Wer einen erlaubten Interpreter hat, hat beliebige Codeausführung und einen HTTP-Client und erreicht damit Händler direkt über deren Schnittstelle, vorbei an Firefox und Cold Turkey. Tragend bleiben deshalb Zahlung (kein gültiges Zahlungsmittel) und Egress (Router-Default-Deny). Diese Einordnung bestimmt die ganze Bewertung.

## Durchlauf 1: vom Quasi-Allowlist zur echten Whitelist

- **Befund:** Die erste Fassung erlaubte pauschal alles in Program Files und sperrte nur bekannte Umgehungen. Das ist keine Whitelist, sondern eine Blockliste auf großzügigem Fundament, und widerspricht der Vorgabe, dass nur das Nötige läuft.
- **Korrektur:** In der Exe-Sammlung wurde die pauschale Program-Files-Erlaubnis entfernt. Erlaubt sind jetzt nur der Windows-Ordner (zwingend für den Systemstart), Firefox und ausdrücklich eingetragene Arbeitsprogramme. Alles andere ist für das verwaltete Konto automatisch gesperrt.
- **Befund (verifiziert):** AppLocker erzwingt auf Windows 10 Pro ab Version 2004, euer 22H2 erfüllt das. Kein Editionswechsel nötig.
- **Befund (verifiziert):** `%PROGRAMFILES%` und `%SYSTEM32%` decken in AppLocker beide Architektur-Ordner ab. Die Edge- und LOLBin-Sperren greifen damit auch auf 64-Bit.

## Durchlauf 2: die Whitelist dicht und betriebstauglich machen

- **Befund:** Der Windows-Ordner muss erlaubt bleiben, enthält aber LOLBins und für Standardnutzer beschreibbare Unterordner. Ohne Gegenmaßnahme ist die Whitelist genau dort löchrig.
- **Korrektur:** Deny-Regeln für die beschreibbaren Unterordner (Temp, Tasks, Tracing, spool color, FxsTmp und weitere) und für LOLBins (mshta, wscript, cscript, msdt, regsvr32) sowie für die .NET-Werkzeuge MSBuild, InstallUtil, RegAsm, RegSvcs. Diese gelten nur für das verwaltete Konto, damit die Vertrauensperson als Admin warten kann.
- **Befund:** Eine Herausgeber-Deny-Regel für die .NET-LOLBins hängt von der exakten Zertifikat-Zeichenkette ab. Passt sie nicht, fällt die Regel offen aus, und der LOLBin bliebe über die Windows-Erlaubnis nutzbar.
- **Korrektur:** Zusätzlich pfadbasierte Deny-Regeln für MSBuild unter Framework und Framework64, als Rückfall unabhängig vom Zertifikat.
- **Befund:** Eine reine Exe-Whitelist würde auch Skripte und DLLs erlaubter Programme aus Program Files blockieren und damit Anwendungen lahmlegen.
- **Korrektur:** Die Script- und Dll-Sammlung erlauben Program Files weiterhin (nur erlaubte EXE laufen ohnehin, deren Skripte und DLLs dürfen laden), mit denselben Sperren für beschreibbare Ordner. Erzwungene Script-Regeln zwingen die PowerShell des Nutzers in den Constrained Language Mode.
- **Befund:** Installer als Einfallstor.
- **Korrektur:** Die Msi-Sammlung erlaubt nur Administratoren. Der Nutzer kann keine Installer starten.
- **Befund:** Würde man alle Store-Apps sperren, bricht die Oberfläche (Start, Einstellungen).
- **Korrektur:** Appx erlaubt signierte Pakete; Store-Käufe regelt Family Safety. Kann auf Microsoft-only verengt werden.
- **Befund:** Per-User installierte Programme (VS Code, Teams, Zoom, Spotify in AppData) liegen außerhalb von Program Files und sind gesperrt.
- **Korrektur:** Dokumentiert plus Werkzeug `63-AppLocker-Programm-erlauben.ps1`, das Herausgeber-Regeln (updatefest) mit Hash-Rückfall erzeugt, plus zwingender Audit-Modus zuerst, der genau diese Fälle sichtbar macht.
- **Bewusst nicht gesperrt:** rundll32, weil es Windows breit nutzt und eine Sperre den normalen Betrieb bricht. Bleibt Restpunkt.

## Durchlauf 3: KI, Edge, Firefox

- **Korrektur Edge:** Edge ist für das Konto nicht in der Whitelist, also automatisch gesperrt; zusätzlich eine ausdrückliche Deny-Regel. WebView2 bleibt erlaubt, damit Apps nicht brechen. Deinstallation optional, da durch Updates rückgängig machbar.
- **Korrektur KI:** Windows Copilot und Edge Copilot per Richtlinie aus, Web- und KI-Suche im Startmenü aus, Edge Shopping-Assistent aus. Firefox: alle `browser.ml.*` und `extensions.ml.enabled` gesperrt, DoH aus, Passwort- und Formularspeicher aus, about:config gesperrt, Erweiterungen gesperrt, privates Surfen aus. KI-Domains zusätzlich in Cold Turkey.
- **Befund:** Ein vollständiges KI-Verbot auf Geräteebene ist nicht absolut. Ein Skript oder eine nicht gelistete KI-Domain oder eine direkte IP erreicht KI trotzdem. Das Domain-Blocken in Cold Turkey wirkt nur im Browser.
- **Konsequenz:** Absolut wird kein-KI erst durch den Router-Egress, der nur Arbeitsdomains zulässt. Ohne diesen bleibt KI über nicht gelistete Wege erreichbar. So dokumentiert.

## Restpunkte, im Rahmen nicht schließbar

- **Erlaubter Interpreter gleich offener Kanal.** Wird ein Interpreter (Python, Node) in die Whitelist aufgenommen, ist beliebige Codeausführung samt HTTP wieder möglich, vorbei an Firefox und Cold Turkey. Sauber wird es nur über Option A (keine Interpreter auf diesem Gerät, Entwicklung auf einem getrennten Rechner) oder über die tragenden Wände Egress und Zahlung. Das ist der wichtigste Punkt.
- **AppLocker ist Benutzermodus.** Es hat strukturell mehr theoretische Umgehungen als das kernelnahe WDAC. Gegen das Ziel hier (Kaufzwang, nicht Schadsoftware) ist die gehärtete Whitelist angemessen; wer das Maximum will, nimmt WDAC aus `Optional-WDAC\`.
- **DLL-Regeln standardmäßig aus** (Leistung). Für die stärkste Stufe mit `-DllRegeln` einschalten, sonst bleibt DLL-Sideloading ein theoretischer Weg.
- **BitLocker ohne TPM.** Entweder Anwesenheit der Vertrauensperson bei jedem Start oder der Offline-Angriff auf die ausgebaute Platte bleibt offen. Nicht auflösbar ohne echtes TPM.
- **Geräteübergreifende Kanäle.** Handy, Tablet, Fremdrechner, Laden, Bargeld, Gutschein bleiben offen und werden nur durch Zahlung und Verhalten gedeckt.
- **Social Engineering** gegenüber der Vertrauensperson, nur durch die Verzögerungsregel gemildert.

## Konvergenz

Innerhalb der Vorgaben (AppLocker-Whitelist, Firefox, kein Edge, keine KI, Win 10 Pro, kein TPM, Cold Turkey) ist der Aufbau am praktischen Optimum. Die verbleibenden Punkte sind keine Nachlässigkeiten, sondern die Grenzen des Ansatzes selbst, und alle laufen auf dieselbe Linie hinaus: Die lokale Whitelist schließt die Oberfläche, die eigentliche Sicherheit liegt in Zahlung, Egress und Begleitung.

## Vergleichende Bewertung

| Schicht | Widerstand allein | Im Verbund | Restrisiko gegen den Entwickler |
|---|---|---|---|
| AppLocker-Whitelist (Exe) | Hoch für Casual, mittel gegen Entwickler | Hoch in Option A | Erlaubter Interpreter, Benutzermodus-Umgehungen |
| Firefox gehärtet, Edge raus | Mittel | Hoch | KI und Shop über Skript statt Browser |
| KI aus | Mittel | Hoch mit Egress | Nicht gelistete Domain, direkte IP |
| Cold Turkey | Niedrig | Mittel, redundant | Browser-only, per Skript umgangen |
| BitLocker ohne TPM | Hoch nur mit Geheimnis bei der Vertrauensperson | Hoch | Offline-Angriff bei Geheimnis beim Nutzer |
| Zahlung | Hoch, geräteübergreifend | Tragende Wand | Gutschein, neue Karte, Bargeld |
| Netz-Egress (Router) | Hoch nur auf fähiger Firewall | Tragende Wand | Tethering, anderes Gerät |
| Verhalten und Begleitung | Nicht zutreffend | Entscheidend für Dauer | Rückfall als Teil des Verlaufs |

## Klartext

AppLocker als Whitelist, Firefox-only, kein Edge und keine KI machen diesen Rechner für alltägliches und unüberlegtes Einkaufen dicht und entfernen KI aus der Oberfläche. Gegen die gezielte, skriptfähige Person tragen sie nur zusammen mit Egress und Zahlung. Ohne die zwei Wände ist es Verzögerung, keine Mauer. Jede ausgelassene Schicht ist das Schlupfloch.
