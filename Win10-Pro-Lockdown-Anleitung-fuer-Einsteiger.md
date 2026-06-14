# Windows 10 Pro absichern gegen Kaufzwang: Anleitung für Einsteiger

Diese Anleitung erklärt jeden Schritt so, dass auch jemand ohne tiefe Windows-Kenntnisse ihn nachmachen kann. Sie gehört zu den Skripten in diesem Ordner, die die technischen Einstellungen automatisch setzen. Jede Phase liegt als eigene Datei vor (`00-Pruefung.ps1`, `10-Konten.ps1` und so weiter), die genaue Reihenfolge und alle Aufrufe stehen in `README.md` im selben Ordner. Die Anleitung sagt dir, was die Skripte tun und sie führt durch die Teile, die kein Skript erledigen kann: BIOS, Family Safety, Zahlung, Router und die Begleitung des Menschen.

> **Einwilligung:** Dieses Vorgehen gilt für das Gerät der betroffenen Person, mit deren Wissen und Zustimmung, am besten auf ihren eigenen Wunsch als Selbstbindung. Eine Vertrauensperson verwahrt alle Passwörter und Schlüssel im Einvernehmen. Das heimliche Sperren des Geräts eines anderen Erwachsenen ist etwas anderes und ist hier nicht gemeint.

---

## 0. Was hier passiert, in einem Satz

Ein technisch versierter Mensch soll an genau diesem Rechner nicht mehr einkaufen können, auch wenn er sich gut mit Programmieren und Netzwerken auskennt. Das gelingt nicht durch eine einzelne Sperre, sondern durch mehrere Schichten, die zusammen greifen, und durch eine Vertrauensperson, die als Einzige die Schlüssel hält.

Die wichtigste Erkenntnis vorweg: Ein gesperrter Rechner allein reicht nicht. Die zwei stärksten Hebel sind die **Zahlung** (kein gültiges Zahlungsmittel erreichbar) und der **Netzausgang am Router** (der Rechner erreicht Händler erst gar nicht). Sie wirken auch dann, wenn die Person über die Kommandozeile arbeitet. Alles andere ist wichtige Härtung darum herum.

---

## 1. Was du vorher brauchst

- **Eine Vertrauensperson.** Sie legt das Gerät an, kennt alle Passwörter und verwahrt sie. Die betroffene Person bekommt ein eingeschränktes Alltagskonto, sonst nichts.
- **Einen USB-Stick** nur für die Schlüssel der Vertrauensperson. Darauf landet der BitLocker-Wiederherstellungsschlüssel und eine Notiz mit allen Passwörtern.
- **Windows 10 Pro** auf dem Gerät. Nicht Home. Wenn dort Home läuft, lässt sich über Einstellungen, Update und Sicherheit, Aktivierung, Product Key ändern auf Pro wechseln. Pro ist nötig, weil nur dort BitLocker mit TPM, die Gruppenrichtlinien und die WDAC-Werkzeuge vollständig vorhanden sind.
- **Optional, aber für echten Schutz empfohlen:** eine fähige Firewall als Router, also OpenWrt, pfSense oder OPNsense. Eine normale Fritz!Box kann den entscheidenden Netzausgangs-Filter nicht.
- **Zeit und Ruhe.** Plane einen halben Tag ein. Zwischen einzelnen Schritten sind Neustarts nötig.

---

## 2. Die Reihenfolge im Überblick

Halte dich an diese Reihenfolge. Jede Stufe baut auf der vorigen auf.

1. BIOS/UEFI vorbereiten (von Hand)
2. Windows aktuell machen und ESU aktivieren (von Hand)
3. Skripte ausführen (BitLocker, Konten, Härtung, Features, WDAC, DNS)
4. Family Safety einrichten (von Hand, im Browser)
5. Zahlung sperren (von Hand, bei Bank und Diensten)
6. Router absichern (von Hand, am Router)
7. Cold Turkey als vollständige Zusatzschicht
8. Verhalten und Begleitung (laufend)
9. Selbsttest und Schlüssel-Tresor

---

## 3. Schritt 1: BIOS/UEFI vorbereiten

Das BIOS ist die Firmware, die noch vor Windows startet. Hier wird festgelegt, ob der Rechner von einem USB-Stick booten darf und ob das TPM aktiv ist. Diese Stufe lässt sich nicht per Skript erledigen.

So kommst du hinein: Rechner ausschalten, einschalten und sofort wiederholt die Setup-Taste drücken. Je nach Hersteller ist das **Entf**, **F2** oder **F10**. Bei Fujitsu meist F2.

Setze dort:

1. **Boot-Modus auf UEFI**, nicht Legacy oder CSM.
2. **Secure Boot auf Enabled.** Das muss an sein, bevor du verschlüsselst.
3. **TPM aktivieren.** Der Eintrag heißt je nach Hersteller "Security Chip", "TPM", bei Intel "PTT", bei AMD "fTPM". Liegt unter dem Menü "Security". Ist der Eintrag ausgegraut, ist das TPM oft schon aktiv.
4. **Supervisor-Passwort setzen.** Das ist das BIOS-Passwort. Nur die Vertrauensperson kennt es. Damit kann niemand ohne dieses Passwort die folgenden Einstellungen ändern.
5. **Boot-Reihenfolge** fest auf die interne Festplatte. **USB-Boot und Netzwerk-Boot deaktivieren.** Das verhindert, dass jemand von einem Linux-Stick startet und an Windows vorbei arbeitet.

Speichern und neu starten, meist mit **F10**.

> Hinweis: An manchen Desktop-Rechnern lässt sich das BIOS-Passwort durch Entfernen der Knopfzelle zurücksetzen. Der eigentliche Schutz gegen so einen Offline-Eingriff ist deshalb nicht das BIOS-Passwort, sondern die Verschlüsselung in Schritt 3.

---

## 4. Schritt 2: Windows aktuell machen und ESU aktivieren

Ein Rechner mit Sicherheitslücken ist selbst ein Schlupfloch, weil eine bekannte Lücke aus dem Standardkonto Adminrechte holen kann. Darum zuerst alles patchen.

1. **Einstellungen, Update und Sicherheit, Windows Update.** Alle Updates installieren, neu starten, erneut prüfen, bis nichts mehr offen ist. Das Januar-2026-Update muss dabei sein.
2. **ESU aktivieren.** Der Support für Windows 10 ist im Oktober 2025 ausgelaufen. Sicherheitsupdates gibt es nur noch über das Consumer-ESU-Programm, das bis zum 13. Oktober 2026 läuft. Im selben Windows-Update-Bildschirm erscheint dazu ein Hinweis mit Anmeldelink. Die Anmeldung ist kostenlos durch Synchronisieren der Einstellungen, oder per 1000 Microsoft-Rewards-Punkten, oder einmalig gegen rund 30 US-Dollar. Sie verlangt ein Microsoft-Konto, das der Vertrauensperson gehören sollte.

---

## 5. Schritt 3: Die Skripte ausführen

Jetzt kommt der automatisierte Teil. Alle Skript-Aufrufe macht die Vertrauensperson in einer **als Administrator gestarteten PowerShell**.

So öffnest du sie: Startmenü, "PowerShell" tippen, mit Rechtsklick "Als Administrator ausführen". Dann in den Skriptordner wechseln:

```powershell
cd "C:\Users\Kaide\Downloads\Lockdown-Win10Pro"
```

> Die folgenden Unterabschnitte 5.1 bis 5.9 entsprechen genau den nummerierten Dateien im Ordner. Jeder Aufruf unten ist die eine Datei zu dieser Phase, die vollständige Befehlsliste steht in `README.md`.

Falls Skripte zunächst blockiert sind, einmalig für diese Sitzung erlauben:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

> Wichtige Reihenfolge: Führe **WDAC ganz am Ende** aus, denn sobald die Erzwingung läuft, gehen unsignierte PowerShell-Skripte in einen eingeschränkten Modus, auch beim Admin. Erst alles andere fertig einrichten, dann WDAC.

### 5.1 Prüfung

Schaut nach, ob TPM, Secure Boot und Edition stimmen. Ändert nichts.

```powershell
.\00-Pruefung.ps1
```

Lies die Ausgabe. Sie zeigt auch, welche BitLocker-Schutzvorrichtungen schon vorhanden sind, also was dein Freund eingerichtet hat. Bei eurem Laptop ohne TPM ist die TPM-Warnung normal, das fängt der nächste Schritt ab.

### 5.2 Konten

Legt das Adminkonto der Vertrauensperson und das Standardkonto der betroffenen Person an und stuft das Alltagskonto auf Standardbenutzer herab. Das Skript fragt die Passwörter sicher ab und weigert sich, den letzten Administrator zu entfernen, damit du dich nicht aussperrst.

```powershell
.\10-Konten.ps1 -AdminKonto "Verwalter" -StandardKonto "Alltag"
```

Ist das Alltagskonto bereits vorhanden und noch Administrator, zusätzlich herabstufen:

```powershell
.\10-Konten.ps1 -AdminKonto "Verwalter" -HerabstufenKonto "Alltag"
```

Hintergrund: Ein Standardbenutzer kann keine Software systemweit installieren, keine Netzwerkeinstellungen ändern, kein zweites Adminkonto anlegen und Family Safety nicht abschalten. Das ist nach der Schlüsselgewalt die wichtigste Einzelmaßnahme.

> Wenn du den Family-Safety-Weg gehst (Schritt 4), wird das Alltagskonto stattdessen ein Kinder-Microsoft-Konto. Dann legst du es nicht hier an, sondern in Schritt 4, und stufst es nach dem Hinzufügen mit `-HerabstufenKonto` herab.

### 5.3 BitLocker

Verschlüsselt die Festplatte, damit niemand die ausgebaute Platte an einem anderen Rechner lesen oder verändern kann. Stecke vorher den Schlüssel-USB-Stick ein, zum Beispiel als Laufwerk E.

**Mit TPM** (falls die Prüfung ein einsatzbereites TPM zeigt): Der Schlüssel liegt im TPM, der Rechner startet unbeaufsichtigt.

```powershell
.\20-BitLocker.ps1 -Modus Tpm -SchluesselDatei "E:\BitLocker-Schluessel.txt"
```

**Ohne TPM** (euer Laptop): Hier braucht BitLocker beim Start ein Geheimnis. Das Skript setzt die nötige Richtlinie selbst. Zwei Varianten:

```powershell
.\20-BitLocker.ps1 -Modus PasswortOhneTpm -SchluesselDatei "E:\BitLocker-Schluessel.txt"
```

oder mit einem USB-Startschlüssel, der bei jedem Start stecken muss:

```powershell
.\20-BitLocker.ps1 -Modus UsbSchluesselOhneTpm -StartupKeyLaufwerk "F:" -SchluesselDatei "E:\BitLocker-Schluessel.txt"
```

Ist BitLocker schon eingeschaltet (dein Freund hat es eingerichtet), erkennt das Skript das und stellt nur sicher, dass ein Wiederherstellungsschlüssel existiert, und gibt ihn aus.

Das Skript zeigt den 48-stelligen Wiederherstellungsschlüssel und speichert ihn in die angegebene Datei. **Diesen Schlüssel ausschließlich bei der Vertrauensperson verwahren.** Er ist der Notausgang für die Wartung. Gerät er an die betroffene Person, ist der Offline-Schutz weg.

Prüfe danach mit `manage-bde -status C:`, dass am Ende "Schutz: Ein" und 100 Prozent steht.

> Die ehrliche Folge ohne TPM: Wer das Pre-Boot-Geheimnis kennt, bestimmt den Schutz. Bei der Vertrauensperson ist der Offline-Schutz voll, aber sie muss bei jedem Start dabei sein. Kennt es die betroffene Person, startet sie allein, doch der Offline-Angriff auf die ausgebaute Platte bleibt offen. Alle anderen Schichten greifen im laufenden Betrieb trotzdem. Wer beides will, also unbeaufsichtigter Start und voller Offline-Schutz, braucht ein Gerät mit echtem TPM.

### 5.4 Härtung

Setzt mehrere Registry-Werte: fremde Microsoft-Konten werden gesperrt, Edge darf kein eigenes verschlüsseltes DNS und keinen InPrivate-Modus mehr, das Anlegen weiterer Edge-Profile wird unterbunden.

```powershell
.\30-Haertung.ps1 -NoConnectedUser 1
```

Wert 1 bedeutet: das verwaltete Konto funktioniert weiter, aber kein fremdes Microsoft-Konto kann hinzugefügt werden. Nur wenn du gar kein Microsoft-Konto nutzt, nimm Wert 3.

### 5.5 Features deaktivieren

Schließt die alternativen Ausführungsumgebungen: WSL, die VM-Plattform, Hyper-V, die Windows-Sandbox und die alte PowerShell 2.0, mit der man sonst die Skript-Erzwingung umgehen könnte.

```powershell
.\40-Features.ps1
```

**Danach den Rechner neu starten.** Erst dann sind die Features wirklich aus.

### 5.6 DNS am Gerät

Trägt einen gefilterten DNS-Server am Adapter ein. Das ist nur Ergänzung, der Router ist wirksamer.

```powershell
.\50-Dns.ps1 -DnsServer "1.1.1.3","1.0.0.3"
```

### 5.7 Edge raus, KI aus, Firefox als einziger Browser

Erst Edge und jede KI abschalten:

```powershell
.\42-Edge-und-KI-deaktivieren.ps1
```

Das schaltet Windows Copilot, Edge Copilot, die Web- und KI-Suche im Startmenü und den Edge-Shopping-Assistenten ab. Edge selbst sperrt gleich die Whitelist. Mit `-EdgeDeinstallieren` lässt sich Edge zusätzlich entfernen, das kann aber durch Updates rückgängig werden.

Dann Firefox installieren (als Admin, nach Program Files) und härten:

```powershell
.\45-Firefox-haerten.ps1
```

Das schaltet in Firefox die KI ab, das verschlüsselte DNS, den Passwort- und Formularspeicher und das private Surfen, und sperrt about:config und Erweiterungen. Firefox einmal in den Windows-Einstellungen als Standardbrowser setzen.

### 5.8 AppLocker-Whitelist

AppLocker ist hier die Allowlist: Für das verwaltete Konto läuft nur, was ausdrücklich erlaubt ist (Windows, Firefox, eingetragene Arbeitsprogramme), alles andere ist gesperrt. AppLocker erzwingt auf Windows 10 Pro.

Zuerst die benötigten Arbeitsprogramme aufnehmen. Jedes vorher als Admin sauber installieren, dann:

```powershell
.\63-AppLocker-Programm-erlauben.ps1 -Pfad "C:\Program Files\Beispielprogramm"
```

Dann im Audit-Modus ausrollen (blockiert nichts, protokolliert nur):

```powershell
.\60-AppLocker-Einrichten.ps1 -StandardKonto "Alltag"
```

**Neu starten.** Ein bis zwei Tage testen, dann die Verstöße ansehen:

```powershell
.\61-AppLocker-Pruefen.ps1
```

Fehlt ein legitimes Programm, mit `63-...` aufnehmen und `60-...` erneut. Hinweis: Programme im Benutzerordner (VS Code, Teams, Zoom) sind gesperrt, bis du sie systemweit nach Program Files installierst oder mit `63-...` aufnimmst.

Wenn alles passt, scharf schalten. Für die stärkste Stufe zusätzlich `-DllRegeln`:

```powershell
.\60-AppLocker-Einrichten.ps1 -StandardKonto "Alltag" -Erzwingen
```

**Neu starten.** Danach läuft die Whitelist, und die PowerShell des Nutzers ist eingeschränkt.

> Brauchst du auf diesem Gerät keine Entwicklungsumgebung, nimm auch keine Interpreter (Python, Node) in die Whitelist auf. Dann ist die Ausführungskontrolle eine echte Wand. Sind sie nötig, bleibt ein offener Kanal, den Router und Zahlung auffangen müssen.

> Wartung: AppLocker als Admin aussetzen mit `Stop-Service appidsvc`. Notausgang bei Aussperrung über die Verschlüsselung in WinRE mit dem BitLocker-Wiederherstellungsschlüssel.

### 5.9 Selbsttest per Skript

```powershell
.\90-Selbsttest.ps1
```

Prüft BitLocker, AppLocker-Status, deaktivierte Features, die Kontosperre und Cold Turkey und listet die Versuche auf, die du danach von Hand im Alltagskonto durchspielen solltest.

---

## 6. Schritt 4: Family Safety einrichten (optional)

Family Safety ist Microsofts eingebaute Kindersicherung. Sein Nutzen liegt hier vor allem in der **Kaufkontrolle im Microsoft Store** und in **Zeitlimits**. Der Webfilter von Family Safety wirkt nur in Edge, und Edge ist hier raus, also übernehmen Cold Turkey und der Router das Sperren von Shop- und KI-Seiten, nicht Family Safety. Family Safety ist damit optional und braucht ein Kinder-Microsoft-Konto.

Wenn du es nutzt:

1. Auf einem Gerät der Vertrauensperson `family.microsoft.com` öffnen und mit dem Konto der Vertrauensperson anmelden.
2. Eine **Familiengruppe** anlegen und ein **Kinder-Microsoft-Konto** für die betroffene Person erstellen.
3. Dieses Konto am PC hinzufügen über Einstellungen, Konten, Familie und andere Benutzer. Danach das Skript noch einmal mit `-HerabstufenKonto` aufrufen, damit auch dieses Konto Standardbenutzer ist.
4. In Family Safety beim Konto der Person einstellen:
   - **Kaufgenehmigung an, keine Karte hinterlegen.** Einkäufe nur über aufgeladenes Guthaben.
   - Optional **App- und Spielefilter** und **Bildschirmzeit**.

> Willst du es einfacher halten, lass Family Safety weg und nutze ein lokales Standardkonto (`10-Konten.ps1`). Die Kaufkontrolle tragen dann Zahlung, Router und Cold Turkey. Family Safety ist Komfort und Store-Kaufkontrolle, nicht die tragende Wand.

---

## 7. Schritt 5: Zahlung sperren, die tragende Wand

Das ist der wirksamste Hebel überhaupt, weil er auch auf dem Handy, einem Zweitgerät und im Laden greift. Ziel: Die Person hat auf keinem erreichbaren Weg ein gültiges Zahlungsmittel.

1. Im **Microsoft-Konto** der Person alle Zahlungsmethoden entfernen.
2. In **allen Browsern und Händlerkonten** wie Amazon gespeicherte Karten und Adressen löschen, 1-Klick-Kauf abschalten.
3. Bei der **Bank** Online- und Karten-nicht-anwesend-Zahlungen sperren oder die Karte einfrieren, Limits stark senken. Das geht meist in der Banking-App oder telefonisch.
4. **Buy-now-pay-later schließen:** Klarna, PayPal Später, Ratenkauf kündigen oder deaktivieren.
5. **PayPal** sperren oder von der Vertrauensperson verwalten lassen.
6. **Virtuelle Karten** einfrieren, Freigabe nur durch die Vertrauensperson.

---

## 8. Schritt 6: Router absichern

Der Router ist die zweite tragende Wand. Hier verhinderst du, dass der Rechner Händler überhaupt erreicht, auch nicht über ein selbst geschriebenes Skript oder eine virtuelle Maschine, denn deren Verkehr läuft durch dieselbe Netzwerkkarte.

**Das Minimum, auf jedem Router machbar:** einen gefilterten DNS eintragen, zum Beispiel NextDNS oder Cloudflare Families, und bekannte öffentliche Resolver sperren. Das hält Gelegenheitsversuche auf, aber ein Entwickler umgeht es über direkte IP-Adressen.

**Der eigentliche Schutz, nur auf fähiger Firewall-Hardware (OpenWrt, pfSense, OPNsense):** ein **ausgehendes Default-Deny.** Das heißt, alles nach draußen ist verboten, und nur die wenigen wirklich benötigten Arbeitsziele sind ausdrücklich erlaubt. So erreicht selbst beliebiger Code keine Händler-Schnittstelle.

Grobe Schritte auf OPNsense oder pfSense, am LAN-Interface, Regeln von oben nach unten:

1. Erlaube das LAN zum gefilterten DNS des Routers auf Port 53.
2. Erlaube das LAN zu einer kurzen Liste erlaubter Arbeitsziele auf Port 443 und 80.
3. **Blockiere** das LAN zu allem Übrigen. Die vorgefertigte Alles-erlauben-Regel entfernst du dafür.

> Was der Router nicht abdeckt: Tethering über das Handy umgeht das Heimnetz komplett. Das fangen nur Zahlung und Verhalten ab.

---

## 9. Schritt 7: Cold Turkey als vollständige Zusatzschicht

Cold Turkey kommt bewusst als doppelte Absicherung oben drauf, zusätzlich zu den OS-Schichten. Es blockt Shopping-Domains und nicht erlaubte Browser direkt im laufenden System und fügt zeitliche Reibung hinzu. Wichtig: Cold Turkey läuft mit Nutzerrechten. Erst das Standardkonto aus Schritt 3 macht es ernst, weil ein Beenden oder Deinstallieren dann Adminrechte braucht.

So richtest du es ein. Erst die Oberfläche, dann das Skript.

1. **Cold Turkey Pro installieren.** Die Kommandozeile, die das Skript nutzt, ist ein Pro-Feature.
2. In Cold Turkey einen Block mit dem Namen **Kaufsperre** anlegen (genau dieser Name, damit das Skript passt).
3. Reiter **Settings**, Bereich **Blocking** aktivieren: **Block Task Manager**, **Block Registry Editor**, **Block Time and Language settings**, in Pro auch **Block Safe Mode**. Das ist die Selbstverteidigung.
4. Einen **gesperrten Zeitplan** (Locked schedule) oder einen langen Timer für den Block anlegen, damit er nicht einfach abgeschaltet wird.
5. Die Einstellungen mit einem **Passwort der Vertrauensperson** sperren (Lock settings).
6. Erst jetzt das Skript laufen lassen, es füllt die Domain- und App-Liste und startet den Block für 24 Stunden gesperrt:

```powershell
.\70-ColdTurkey.ps1 -BlockName "Kaufsperre" -StartLockMinuten 1440
```

Die Domains stehen in `coldturkey-domains.txt` im selben Ordner und lassen sich beliebig erweitern. Die App-Sperre umfasst standardmäßig fremde Browser und Spiele-Launcher. Findet das Skript Cold Turkey nicht, installiere es zuerst und gib den Pfad mit `-ExePfad` an.

> Cold Turkey schließt keinen Weg, den die tragenden Wände (Standardkonto, WDAC, Zahlung, Router) nicht ohnehin besser schließen. Als Zusatzschicht erhöht es die Reibung und deckt erlaubte Browser ab. Verlass dich nicht allein darauf.

---

## 10. Schritt 8: Verhalten und Begleitung

Technik senkt die Gelegenheit und das Tempo, sie heilt nicht. Kaufzwang ist eine anerkannte Störung, und selbst gute Therapie hat hohe Rückfallquoten. Darum gehört der menschliche Teil dazu, sonst tragen die technischen Schichten nicht dauerhaft.

- Feste **Wartefristen** von 24 oder 72 Stunden vor jedem nicht notwendigen Kauf.
- Eine **Wunschliste** statt Sofortkauf, ein **Auslöser-Protokoll**.
- **Regelmäßige Kontoschau** gemeinsam mit der Vertrauensperson.
- **Professionelle Hilfe** und Schuldnerberatung einbeziehen.
- Die **übrigen Geräte** der Person nach derselben Logik absichern.

---

## 11. Schlüssel-Tresor: was die Vertrauensperson verwahrt

Schreibe diese Liste auf den Schlüssel-USB-Stick und an einen sicheren Ort, niemals zugänglich für die betroffene Person:

- Passwort des Adminkontos (Verwalter)
- Passwort des verwaltenden Microsoft- bzw. Family-Safety-Kontos
- BIOS-Supervisor-Passwort
- BitLocker-Wiederherstellungsschlüssel (48 Stellen)
- Cold-Turkey-Passwort, falls genutzt
- Zugänge zu Bank, PayPal und Co., soweit von der Vertrauensperson verwaltet

---

## 12. Wartung später: Programme erlauben und Updates

Sobald WDAC erzwingt, ist Wartung bewusst etwas aufwändiger, das ist gewollt.

- **Neues Programm erlauben:** Als Admin sauber unter Program Files installieren, dann auf diesem Pro-Gerät die Richtlinie neu bauen (`-Phase WdacAudit`, prüfen, dann `-Phase WdacErzwingen`).
- **Wenn etwas klemmt:** Den Notausgang in WinRE nutzen, der den BitLocker-Wiederherstellungsschlüssel verlangt. Danach die Richtlinie korrigieren und wieder ausrollen.
- **PowerShell als Admin** läuft nach der Erzwingung im eingeschränkten Modus. Für größere Wartung daher vorher den Notausgang nutzen oder die Richtlinie kurz auf Audit zurückstellen.

---

## 13. Selbsttest-Checkliste

Im **Alltagskonto** anmelden und der Reihe nach versuchen. Jeder Punkt muss scheitern.

1. `winget install Mozilla.Firefox` scheitert an UAC und WDAC.
2. Eine portable Browser-Datei oder umbenannte .exe starten scheitert an WDAC.
3. `powershell -version 2` scheitert, weil das Feature entfernt ist.
4. `mshta.exe` oder `regsvr32`-Missbrauch scheitert an der Sperrliste.
5. `wsl.exe` oder VirtualBox starten scheitert, Feature aus.
6. Ein Skript, das per HTTP an eine Händler-API bestellt, scheitert am Router-Default-Deny, und es ist ohnehin kein Zahlungsmittel erreichbar. Das ist der wichtigste Test.
7. Von Live-USB oder im abgesicherten Modus starten scheitert an BIOS-Sperre und BitLocker.
8. Ein fremdes Microsoft-Konto hinzufügen ist blockiert.
9. Eigener DNS, DoH im Browser, VPN sind am Gerät gesperrt. Tethering bleibt nur über Zahlung und Verhalten abgedeckt.

---

## 14. Die ehrliche Grenze

Diese Punkte bleiben offen, das gehört zur Wahrheit dazu.

- **Ohne Schlüsselgewalt ist alles nur Reibung.** Behält die Person Adminrechte oder die Schlüssel, hebt sie jede Sperre wieder auf.
- **Geräteübergreifende Wege bleiben:** Handy, Tablet, fremder Rechner, Laden, Bargeld, ein im Laden gekaufter Gutschein, eine neue Karte. Das deckt nur die Zahlung zusammen mit der Verhaltensebene ab.
- **Social Engineering** gegenüber der Vertrauensperson lässt sich nicht technisch lösen, nur durch die vereinbarte Verzögerungsregel.
- **Windows 10 läuft aus.** Nach dem 13. Oktober 2026 endet das Consumer-ESU. Für eine dauerhafte Lösung sind Windows 11 Pro oder macOS strukturell stärker.

Der Käfig um diesen Rechner stoppt eine motivierte Person mit Smartphone nicht. Die tragende Sicherheit liegt deshalb in Zahlung, Router und Begleitung, nicht in der Software auf diesem einen Gerät.
