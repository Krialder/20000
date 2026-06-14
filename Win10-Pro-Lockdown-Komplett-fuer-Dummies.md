# Windows 10 Pro sicher machen gegen Kaufzwang: ganz einfach erklärt

Diese Anleitung ist die einfachste Fassung. Sie erklärt jedes Wort und jeden Klick. Wenn du noch nie etwas an Windows tiefer eingestellt hast, ist das hier dein Dokument. Die etwas technischere Fassung mit Hintergründen heißt `Win10-Pro-Lockdown-Anleitung-fuer-Einsteiger.md` im selben Ordner, die brauchst du nur, wenn du mehr Details willst.

> Wichtig vorweg: Das Ganze gilt für das Gerät der betroffenen Person, mit ihrem Einverständnis. Eine **Vertrauensperson** richtet alles ein und behält alle Passwörter. Die betroffene Person bekommt ein eingeschränktes Konto.

---

## Teil A: Wörter, die immer wieder vorkommen

Lies das einmal, dann verstehst du den Rest.

- **Vertrauensperson:** der Mensch, der alles einrichtet und alle Passwörter behält. Im Text "du".
- **Betroffene Person:** der Mensch, der nicht mehr einkaufen können soll.
- **Konto:** ein Login an Windows. Es gibt zwei Sorten.
  - **Administrator (Admin):** darf alles, auch Programme installieren und Einstellungen ändern. Das bekommt nur die Vertrauensperson.
  - **Standardbenutzer:** darf normal arbeiten, aber nichts Tiefes ändern und nichts installieren. Das bekommt die betroffene Person.
- **BIOS (auch UEFI):** ein kleines Menü, das noch vor Windows startet. Hier stellt man ein, ob der Rechner von einem USB-Stick starten darf. Man kommt hinein, indem man direkt nach dem Einschalten eine Taste drückt, meist Entf, F2 oder F10.
- **TPM:** ein kleiner Sicherheitschip. Wenn er da ist, kann sich die verschlüsselte Platte beim Start von selbst entsperren. **Euer Laptop hat keinen nutzbaren TPM**, darum gibt es weiter unten einen eigenen Weg.
- **PowerShell:** ein schwarzes Fenster, in das man Befehle tippt. Wir benutzen es, um die fertigen Skripte zu starten.
- **Skript:** eine fertige Befehlsdatei, die endet auf `.ps1`. Du musst sie nur aufrufen, nicht selbst schreiben.
- **Verschlüsselung (BitLocker):** macht die Festplatte unlesbar für jeden, der sie ausbaut. Ohne den richtigen Schlüssel sieht man nur Datensalat.
- **Allowlist (WDAC):** eine Liste erlaubter Programme. Was nicht auf der Liste steht, startet nicht. So kann die Person keinen neuen Browser nachladen.
- **DNS:** das Telefonbuch des Internets. Es übersetzt Namen wie amazon.de in eine Nummer. Ein gefilterter DNS kann bestimmte Namen sperren.
- **Router:** die Box, die dein Internet verteilt. An ihr kann man steuern, wohin der Rechner überhaupt darf.
- **Family Safety:** Microsofts eingebaute Kindersicherung. Liefert Zeitlimits und Kaufkontrolle im Microsoft Store.
- **Cold Turkey:** ein zusätzliches Sperrprogramm, das Shopping-Seiten blockt.

> Die zwei wichtigsten Dinge in einem Satz: Am Ende soll die Person **kein Zahlungsmittel** erreichen und der Rechner soll **Händler-Seiten gar nicht erreichen**. Alles andere unterstützt diese zwei Punkte.

---

## Teil B: Was du bereitlegst

- Ein zweiter, leerer **USB-Stick** nur für die Schlüssel und Passwörter der Vertrauensperson.
- Etwas **Zeit**, plane einen halben Tag ein. Zwischendurch musst du den Rechner mehrmals neu starten.
- Die **Skript-Dateien** liegen schon im Ordner `C:\Users\Kaide\Downloads\Lockdown-Win10Pro`.

---

## Teil C: Die Schritte, einer nach dem anderen

Mach sie der Reihe nach. Überspringe nichts.

### Schritt 1: BIOS einstellen

**Warum:** Damit niemand mit einem USB-Stick an Windows vorbei starten kann.

**So geht es:**
1. Rechner ausschalten. Wieder einschalten und sofort mehrmals die BIOS-Taste drücken (Entf, F2 oder F10, bei Fujitsu meist F2).
2. Suche den Menüpunkt **Security**. Stelle dort:
   - **Secure Boot** auf **Enabled** (eingeschaltet).
   - Ein **Supervisor Password** (BIOS-Passwort) setzen. Nur du kennst es.
3. Suche **Boot** oder **Boot Order**. Stelle die interne Festplatte an die erste Stelle. Schalte **USB Boot** und **Network Boot** aus.
4. Speichern und beenden, meist mit **F10**, dann Enter.

**Geklappt, wenn:** der Rechner danach normal Windows startet und beim nächsten BIOS-Besuch nach dem Passwort fragt.

### Schritt 2: Windows aktuell machen

**Warum:** Ein veralteter Rechner hat Löcher, durch die man Adminrechte bekommt.

**So geht es:**
1. **Start** anklicken, **Einstellungen** (Zahnrad), **Update und Sicherheit**, **Windows Update**.
2. Auf **Nach Updates suchen** klicken. Alles installieren. Neu starten. Das wiederholen, bis nichts mehr kommt.
3. Im selben Fenster erscheint ein Hinweis zu **ESU** (verlängerte Updates). Dem Link folgen und anmelden. Das ist kostenlos über das Synchronisieren der Einstellungen und braucht ein Microsoft-Konto der Vertrauensperson.

**Geklappt, wenn:** "Sie sind auf dem neuesten Stand" steht.

### Schritt 3: PowerShell als Administrator öffnen

Das brauchst du für alle folgenden Skript-Schritte.

**So geht es:**
1. **Start** anklicken, `PowerShell` tippen.
2. Auf **Windows PowerShell** mit der **rechten** Maustaste klicken, dann **Als Administrator ausführen**, dann **Ja**.
3. In das Fenster genau das tippen und Enter drücken:
   ```powershell
   cd "C:\Users\Kaide\Downloads\Lockdown-Win10Pro"
   ```
4. Dann noch das, damit die Skripte laufen dürfen:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
   Wenn es fragt, **J** tippen und Enter.

Lass dieses Fenster offen. Jeder Skript-Aufruf unten wird hier eingetippt.

### Schritt 4: Erst nur prüfen

**Warum:** Damit du siehst, was schon da ist.

```powershell
.\00-Pruefung.ps1
```

Es zeigt grüne **OK** und gelbe **WARN**. Die Warnung zum TPM ist bei eurem Laptop normal. Den Rest fängt der nächste Schritt ab.

### Schritt 5: Konten anlegen

**Warum:** Die betroffene Person bekommt ein Konto ohne Adminrechte. Das ist nach den Passwörtern die wichtigste Maßnahme.

```powershell
.\10-Konten.ps1 -AdminKonto "Verwalter" -StandardKonto "Alltag"
```

Das Skript fragt nacheinander nach einem Passwort für **Verwalter** (das behältst du) und für **Alltag** (das nutzt die Person). Beim Tippen siehst du nichts, das ist normal, einfach tippen und Enter.

Falls die Person schon ein eigenes Konto mit Adminrechten hat, zusätzlich:
```powershell
.\10-Konten.ps1 -HerabstufenKonto "NameDesKontos"
```

**Geklappt, wenn:** am Ende in der Liste nur **Verwalter** als Administrator steht.

### Schritt 6: Festplatte verschlüsseln (ohne TPM)

**Warum:** Damit niemand die Platte ausbaut und an einem anderen Rechner liest oder die Sperren löscht.

Weil euer Laptop keinen TPM hat, braucht der Start ein Geheimnis. Du wählst, wer es kennt.

Variante mit Passwort beim Start:
```powershell
.\20-BitLocker.ps1 -Modus PasswortOhneTpm -SchluesselDatei "E:\BitLocker-Schluessel.txt"
```
("E:" durch den Laufwerksbuchstaben deines USB-Sticks ersetzen.)

Das Skript fragt nach einem **Pre-Boot-Passwort**. Das muss bei jedem Einschalten eingegeben werden. Danach zeigt und speichert es einen langen **Wiederherstellungsschlüssel** (48 Ziffern).

**Drei Dinge merken:**
- Den Wiederherstellungsschlüssel **nur du** behältst, auf dem USB-Stick. Niemals der Person geben.
- Kennt **nur du** das Pre-Boot-Passwort, ist der Schutz am stärksten, aber du musst bei jedem Start dabei sein.
- Kennt die **Person** das Passwort, kann sie allein starten, dann ist der Schutz gegen das Ausbauen der Platte aber weg. Alle anderen Sperren wirken im Betrieb trotzdem weiter.

**Geklappt, wenn:** `manage-bde -status C:` am Ende "Schutz: Ein" und 100 Prozent zeigt. Das Verschlüsseln läuft im Hintergrund, du kannst weitermachen.

### Schritt 7: System absichern

**Warum:** Sperrt fremde Microsoft-Konten und verhindert, dass der Browser die Filter umgeht.

```powershell
.\30-Haertung.ps1 -NoConnectedUser 1
```

### Schritt 8: Hintertüren schließen

**Warum:** Schaltet versteckte Wege ab (Linux unter Windows, virtuelle Maschinen, eine alte Befehlsversion).

```powershell
.\40-Features.ps1
```

**Danach den Rechner neu starten** (Start, Ein/Aus, Neu starten). Dann PowerShell wie in Schritt 3 wieder als Administrator öffnen und in den Ordner wechseln.

### Schritt 9: Internet-Filter am Gerät

**Warum:** Sperrt schädliche und nicht jugendfreie Seiten schon am Rechner. Der Router ist später wichtiger.

```powershell
.\50-Dns.ps1 -DnsServer "1.1.1.3","1.0.0.3"
```

### Schritt 10: Edge raus, KI aus, Firefox als einziger Browser, dann die Whitelist

Dieser Schritt hat drei Teile. Er macht den Rechner zu einer Firefox-only-Maschine ohne KI, auf der nur das Nötige läuft.

**Teil A: Edge raus und jede KI aus.**
```powershell
.\42-Edge-und-KI-deaktivieren.ps1
```
Das schaltet Windows Copilot, Edge Copilot, die Web- und KI-Suche im Startmenü und den Edge-Shopping-Assistenten ab. Edge selbst sperrt gleich die Whitelist. Wer Edge ganz entfernen will, hängt `-EdgeDeinstallieren` an, das kann aber durch Updates rückgängig werden.

**Teil B: Firefox installieren und härten.**
1. Firefox als Admin installieren, nach `C:\Program Files\Mozilla Firefox`.
2. Härten:
```powershell
.\45-Firefox-haerten.ps1
```
Das schaltet in Firefox die KI ab, das verschlüsselte DNS, den Passwort- und Formularspeicher und das private Surfen, und sperrt about:config und Erweiterungen.
3. Firefox einmal als Standardbrowser setzen: Einstellungen, Apps, Standard-Apps, Firefox für http und https.

**Teil C: Die Whitelist (nur erlaubte Programme).**

Auf der Whitelist stehen am Anfang nur Windows und Firefox. Jedes weitere Programm, das die Person zum Arbeiten braucht, musst du aufnehmen. Erst installieren (als Admin, nach Program Files), dann:
```powershell
.\63-AppLocker-Programm-erlauben.ps1 -Pfad "C:\Program Files\Beispielprogramm"
```
Das für jedes benötigte Programm wiederholen.

**Dann der Probelauf** (blockiert noch nichts, merkt sich nur, was fehlen würde):
```powershell
.\60-AppLocker-Einrichten.ps1 -StandardKonto "Alltag"
```
**Neu starten.** Die Person ein bis zwei Tage normal arbeiten lassen.

**Nachsehen, was gefehlt hätte:**
```powershell
.\61-AppLocker-Pruefen.ps1
```
Fehlt ein Programm, mit `63-...` aufnehmen und `60-...` erneut.

**Wenn alles passt, scharf schalten:**
```powershell
.\60-AppLocker-Einrichten.ps1 -StandardKonto "Alltag" -Erzwingen
```
**Neu starten.** Ab jetzt startet nur noch, was erlaubt ist.

> Merke: Mach Teil C zuletzt unter den Skript-Schritten. Danach ist auch die PowerShell eingeschränkt, das ist gewollt. Hinweis: Programme, die sich in den Benutzerordner installieren (zum Beispiel VS Code, Teams, Zoom), musst du entweder systemweit nach Program Files installieren oder mit `63-...` auf ihren Ordner aufnehmen.

### Schritt 11: Family Safety (optional, Kindersicherung)

**Warum:** Nützlich vor allem für die **Kaufkontrolle im Microsoft Store** und **Zeitlimits**. Der Webfilter von Family Safety wirkt nur in Edge, und Edge ist hier raus, also übernimmt das Sperren von Shop- und KI-Seiten Cold Turkey und der Router, nicht Family Safety. Family Safety ist damit optional und braucht ein Kinder-Microsoft-Konto.

**Wenn du es nutzt:**
1. Auf einem Gerät der Vertrauensperson `family.microsoft.com` öffnen und anmelden.
2. Eine **Familie** anlegen, ein **Kinderkonto** für die Person erstellen.
3. Dieses Konto am PC hinzufügen über Einstellungen, Konten, Familie und andere Benutzer. Danach mit `.\10-Konten.ps1 -HerabstufenKonto "Name"` zum Standardbenutzer machen.
4. In Family Safety beim Konto der Person:
   - **Kaufgenehmigung an, keine Kreditkarte hinterlegen.** Nur Guthaben aufladen.
   - Optional **Zeitlimits** setzen.

Willst du es einfacher halten, lass Family Safety weg und nimm ein lokales Standardkonto. Die Kaufkontrolle tragen dann Zahlung, Router und Cold Turkey.

### Schritt 12: Zahlung sperren (der wichtigste Punkt)

**Warum:** Wirkt auch auf Handy, Zweitgerät und im Laden. Wenn kein Geld fließen kann, kann nichts gekauft werden.

**So gehst du durch:**
1. Im **Microsoft-Konto** alle Zahlungsmethoden löschen.
2. In **allen Browsern und Shops** gespeicherte Karten und Adressen löschen, Ein-Klick-Kauf aus.
3. Bei der **Bank** Online-Zahlungen sperren oder die Karte einfrieren, Limits runter. Geht meist in der Banking-App.
4. **Klarna, PayPal Später, Ratenkauf** kündigen.
5. **PayPal** sperren oder von dir verwalten lassen.

### Schritt 13: Router absichern

**Warum:** Verhindert, dass der Rechner Händler überhaupt erreicht.

- **Einfach, auf jedem Router:** einen gefilterten DNS eintragen (NextDNS oder Cloudflare Families). Hält Gelegenheitsversuche auf.
- **Richtig stark, nur auf einer fähigen Firewall (OpenWrt, pfSense, OPNsense):** alles nach draußen verbieten und nur die wenigen benötigten Arbeitsziele erlauben. Eine normale Fritz!Box kann das nicht.

Wenn dir das zu viel ist, mach mindestens den DNS-Teil und konzentriere dich sonst auf Zahlung und Konten.

### Schritt 14: Cold Turkey als Zusatzsperre

**Warum:** Blockt Shopping-Seiten zusätzlich direkt im laufenden System.

**Erst in der Oberfläche (einmalig):**
1. Cold Turkey **Pro** installieren.
2. Einen Block namens **Kaufsperre** anlegen.
3. Unter **Settings, Blocking** einschalten: Block Task Manager, Block Registry Editor, Block Time and Language settings, in Pro auch Block Safe Mode.
4. Einen gesperrten Zeitplan oder langen Timer setzen.
5. Die Einstellungen mit deinem Passwort sperren.

**Dann das Skript, das die Shop-Liste einträgt und sperrt:**
```powershell
.\70-ColdTurkey.ps1 -BlockName "Kaufsperre" -StartLockMinuten 1440
```

### Schritt 15: Alles testen

```powershell
.\90-Selbsttest.ps1
```
Dann im **Alltagskonto** anmelden und ausprobieren: Lässt sich ein neuer Browser installieren? Öffnet sich eine Shop-Seite? Beides muss scheitern.

---

## Teil D: Der Tresor der Vertrauensperson

Auf den USB-Stick und an einen sicheren Ort, niemals für die Person erreichbar:
- Passwort vom Konto **Verwalter**
- Passwort vom Microsoft- bzw. Family-Safety-Konto
- BIOS-Passwort
- BitLocker-Wiederherstellungsschlüssel und Pre-Boot-Passwort
- Cold-Turkey-Passwort

---

## Teil E: Wenn etwas klemmt

Hat sich das System verschluckt und ein wichtiges Programm startet nicht mehr, gibt es einen Notausgang, den nur du mit dem BitLocker-Wiederherstellungsschlüssel öffnen kannst. Er steht ausführlich in `README.md` im selben Ordner unter "Wartung später". Kurz: in der Windows-Reparaturumgebung die Allowlist-Datei umbenennen, dann neu einrichten.

---

## Teil F: Ehrlich, was nicht geht

- Behält die Person Adminrechte oder die Schlüssel, ist alles nur eine Bremse.
- Handy, Tablet, fremder Rechner, Laden und Bargeld bleiben offen. Das fangen nur die Zahlung und die gemeinsame Begleitung ab.
- Ohne echten TPM gilt: entweder du bist bei jedem Start dabei, oder das Ausbauen der Platte bleibt möglich.
- Technik bremst und gibt Zeit. Sie heilt den Kaufzwang nicht. Feste Wartezeiten vor Käufen, gemeinsame Kontoschau und professionelle Hilfe gehören dazu.
