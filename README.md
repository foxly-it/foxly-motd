# Foxly MOTD

Ein schnelles, updatefähiges System-Dashboard für SSH-Logins auf Debian und Ubuntu.

[Website](https://motd.foxly.de) · [English](#english) · [Deutsch](#deutsch)

## Deutsch

Foxly MOTD zeigt Hostname, Betriebssystem, IP-Adressen mit CIDR-Präfix, DNS-Server, Uptime, Systemlast, RAM, Swap, Speicherplatz, systemd-Zustand, Neustartbedarf, Docker-Status und verfügbare Paketupdates auf Deutsch oder Englisch. Die Systeminformationen sind dabei in einem platzsparenden dreispaltigen Raster nach Netzwerk, Ressourcen, Sitzung, Systemstatus und Paket-Updates gruppiert. Netzwerk- und APT-Aufrufe werden nicht während des Logins ausgeführt: systemd aktualisiert die Paketinformationen im Hintergrund, während das MOTD ausschließlich lokale und gecachte Daten liest.

### Unterstützte Systeme

- Debian und Ubuntu mit systemd und `pam_motd`
- Bash 4 oder neuer
- APT-basierte Paketverwaltung
- Docker optional
- `lolcat` optional; bei Fehlen werden normale ANSI-Farben verwendet

### Installation

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash
```

Alternativ kann das Skript vor der Ausführung geprüft werden:

```bash
curl -fsSLo foxly-motd-install.sh https://motd.foxly.de/install.sh
less foxly-motd-install.sh
sudo bash foxly-motd-install.sh
```

Bei einer lokalen Entwicklungskopie:

```bash
sudo bash install.sh
```

Der Installer installiert fehlende Kernabhängigkeiten, übernimmt vorhandene Einstellungen und aktiviert zwei Timer:

- `foxly-motd-cache.timer`: aktualisiert den Paket-Cache alle 30 Minuten
- `foxly-motd-update.timer`: prüft täglich auf neue Foxly-MOTD-Releases

Softwareupdates laufen standardmäßig im Modus `notify`: Ein neues Release wird im MOTD angekündigt, aber nicht automatisch installiert.

Auf der [Website](https://motd.foxly.de/#configurator) steht ein visueller Konfigurator bereit. Module und Darstellung können dort ausgewählt, sofort in einer Terminal-Vorschau geprüft und anschließend als vollständige Konfiguration kopiert werden. Die Verarbeitung findet ausschließlich lokal im Browser statt.

Bei einer interaktiven Erstinstallation fragt der Installer nach `auto`, `de` oder `en`. `auto` verwendet die Locale des SSH-Logins beziehungsweise des Betriebssystems. Für unbeaufsichtigte Installationen kann die Sprache direkt übergeben werden:

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash -s -- --language de
```

### Migration der alten Dotfiles-Version

Der Installer erkennt die früheren Foxly-Dateien `/etc/update-motd.d/00-header` und `/etc/update-motd.d/10-sysinfo`. Erkannte Legacy-Dateien werden vor der Migration unter `/var/backups/foxly-motd/legacy-*.tar.gz` archiviert und erst nach erfolgreicher Installation der neuen Skripte entfernt. Die Migration kann daher direkt auf einem Server mit der alten Dotfiles-Version ausgeführt werden.

#### Standardmigration

1. Vorhandene Dateien und ihren Ausführungsstatus kontrollieren:

   ```bash
   sudo ls -l /etc/update-motd.d/00-header /etc/update-motd.d/10-sysinfo
   ```

2. Den aktuellen Installer starten und bei der Sprachabfrage `auto`, `de` oder `en` auswählen:

   ```bash
   curl -fsSL https://motd.foxly.de/install.sh | sudo bash
   ```

3. Installation, Timer und Ausgabe prüfen:

   ```bash
   foxly-motd status
   foxly-motd preview
   systemctl list-timers 'foxly-motd-*'
   ```

4. Migration und Backup kontrollieren:

   ```bash
   sudo cat /var/lib/foxly-motd/legacy-migration
   sudo ls -lh /var/backups/foxly-motd/legacy-*.tar.gz
   ```

Nach erfolgreicher Migration sind nur noch `/etc/update-motd.d/00-foxly-header` und `/etc/update-motd.d/10-foxly-sysinfo` aktiv. Die alten Dateien werden aus `/etc/update-motd.d` entfernt, bleiben aber im Legacy-Archiv erhalten.

#### Bereits installierte Version 1.0

Wenn Foxly MOTD 1.0 bereits zusätzlich zu den alten Dotfiles-Skripten installiert wurde, führt das normale Update die fehlende Migration nachträglich aus:

```bash
sudo foxly-motd update
foxly-motd preview
```

#### Angepasste oder nicht erkannte Legacy-Dateien

Gleichnamige fremde oder stark angepasste Dateien werden im Standardmodus nicht verändert. Nach einer manuellen Prüfung kann ihre Migration ausdrücklich erzwungen werden:

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash -s -- --migrate-legacy force
```

Mit `--migrate-legacy off` wird die Legacy-Erkennung vollständig übersprungen. Der Migrationsstatus wird unter `/var/lib/foxly-motd/legacy-migration` protokolliert.

#### Migration zurücknehmen

Zuerst den Pfad des Legacy-Archivs aus `/var/lib/foxly-motd/legacy-migration` prüfen. Anschließend kann die neue Installation entfernt und das alte Archiv wiederhergestellt werden:

```bash
sudo foxly-motd uninstall
sudo tar -xzf /var/backups/foxly-motd/legacy-YYYYMMDD-HHMMSS.tar.gz -C /
sudo run-parts /etc/update-motd.d
```

Konfiguration, Cache und Backups der neuen Version bleiben bei der Deinstallation bewusst erhalten.

#### Änderungen des alten Installers außerhalb von `update-motd.d`

Die Migration verändert ausschließlich die alten Foxly-MOTD-Skripte. Optionale Änderungen, die der frühere Installer vorgenommen haben könnte, werden nicht automatisch zurückgesetzt:

- ein geleertes `/etc/motd` und eventuell vorhandene Backups `/etc/motd.bak-*`
- `PrintLastLog no` in der SSH-Konfiguration
- andere MOTD-Skripte, denen der alte Installer das Ausführungsrecht entzogen hat

Diese Einstellungen können absichtlich auf dem Server gesetzt worden sein und müssen deshalb vor einer manuellen Rücknahme einzeln geprüft werden. Eine SSH-Konfigurationsänderung sollte immer mit `sshd -t` validiert werden, bevor der Dienst neu geladen wird.

Der alte `motd-scripts`-Ordner wird für Installation, Updates oder Rollbacks nicht mehr benötigt. Er sollte erst entfernt werden, nachdem die Migration auf allen betroffenen Servern geprüft und mindestens ein Legacy-Backup außerhalb des Servers gesichert wurde.

### Befehle

```bash
foxly-motd status                    # Version, Cache und Timer anzeigen
foxly-motd preview                   # MOTD direkt anzeigen
sudo foxly-motd refresh              # Paket-Cache sofort aktualisieren
foxly-motd check-update              # Nach einem neuen Release suchen
sudo foxly-motd update               # Aktuelles Release installieren
sudo foxly-motd rollback             # Neuestes Backup wiederherstellen
sudo foxly-motd enable-auto-update   # Releases automatisch installieren
sudo foxly-motd disable-auto-update  # Nur über Releases informieren
sudo foxly-motd uninstall            # Installation entfernen
```

`check-update` liefert Status `0`, wenn die Installation aktuell ist, und Status `10`, wenn eine neue Version verfügbar ist.

### Konfiguration

Die Konfiguration liegt in `/etc/default/foxly-motd`:

```bash
MOTD_LANGUAGE=auto
COLOR_MODE=always
USE_LOLCAT=yes
FIGLET_FONT=slant
SHOW_NETWORK=yes
SHOW_NETWORK_DETAILS=yes
SHOW_RESOURCES=yes
SHOW_SESSION=yes
SHOW_SYSTEM_HEALTH=yes
SHOW_DOCKER=yes
SHOW_PACKAGE_UPDATES=yes
SHOW_PACKAGE_NAMES=no
PACKAGE_NAME_LIMIT=5
SHOW_UPDATE_NOTICE=yes
SHOW_FRAME=yes
UPDATE_MODE=notify
```

Erlaubte Werte für Schalter sind `yes` und `no`. `SHOW_NETWORK`, `SHOW_RESOURCES`, `SHOW_SESSION`, `SHOW_SYSTEM_HEALTH` und `SHOW_PACKAGE_UPDATES` steuern die Module im dreispaltigen Raster. `SHOW_NETWORK_DETAILS` ergänzt die DNS-Anzeige. Mit `SHOW_PACKAGE_NAMES` und `PACKAGE_NAME_LIMIT` lässt sich eine begrenzte Paketliste einblenden; standardmäßig bleibt die Paketmeldung kompakt. `SHOW_FRAME` steuert den Außenrahmen. `MOTD_LANGUAGE` akzeptiert `auto`, `de` und `en`; `COLOR_MODE` akzeptiert `always` und `never`; `UPDATE_MODE` akzeptiert `notify` und `automatic`.

Bei einem Upgrade bleibt eine vorhandene `/etc/default/foxly-motd` erhalten. Der Installer ergänzt ausschließlich fehlende Konfigurationsschlüssel mit den aktuellen Standardwerten. Bereits gesetzte Werte und eigene zusätzliche Einträge werden nicht überschrieben.

### Datenquellen und Login-Verhalten

Die MOTD führt beim Login keine ausgehenden Netzwerkaufrufe aus. Die angezeigten Werte stammen aus lokalen Dateien, lokalen Systemwerkzeugen oder dem von systemd gepflegten Paket-Cache:

| Anzeige | Lokale Datenquelle |
| --- | --- |
| Betriebssystem und Kernel | `/etc/os-release`, `uname` |
| IP-Adressen und CIDR-Präfixe | `ip address` |
| DNS-Server | `resolvectl dns`, ersatzweise `/etc/resolv.conf` |
| Fehlgeschlagene Dienste | `systemctl --failed --type=service` |
| Neustart erforderlich | `/var/run/reboot-required` |
| Docker-Zustände | `docker ps`, einschließlich `unhealthy` und `restarting` |
| Paketupdates | `/var/cache/foxly-motd/packages`, aktualisiert durch den Cache-Timer |
| Remote Host | SSH- und PAM-Sitzungsdaten, ersatzweise `who -m` |

Die Abfragen von DNS, systemd und Docker besitzen jeweils ein Zeitlimit von zwei Sekunden. Ist eine Quelle nicht verfügbar, wird `N/A` beziehungsweise ein Hinweis ausgegeben, ohne den Login dauerhaft zu blockieren. Wenn `/etc/resolv.conf` auf einen lokalen Stub-Resolver zeigt, kann als DNS-Server beispielsweise `127.0.0.53` erscheinen.

### Pfade

| Zweck | Pfad |
| --- | --- |
| Verwaltungsbefehl | `/usr/local/sbin/foxly-motd` |
| MOTD-Skripte | `/etc/update-motd.d/00-foxly-header`, `/etc/update-motd.d/10-foxly-sysinfo` |
| Konfiguration | `/etc/default/foxly-motd` |
| Paket-Cache | `/var/cache/foxly-motd/packages` |
| Versionsstatus | `/var/lib/foxly-motd/` |
| Backups | `/var/backups/foxly-motd/` |

### Update-Sicherheit

- private temporäre Verzeichnisse über `mktemp`
- versionierte GitHub-Release-Archive
- verpflichtende SHA-256-Prüfung vor dem Entpacken
- Prüfung auf unsichere Archivpfade
- Bash-Syntaxprüfung vor der Installation
- Backup vor jedem Upgrade
- sichere Erkennung und separates Backup alter Foxly-MOTD-Skripte
- atomarer Austausch der Cache-Datei
- Netzwerkzugriffe mit Verbindungs- und Gesamtlaufzeitlimit

Für veröffentlichte Versionen sollte in GitHub zusätzlich **Release immutability** aktiviert werden.

### Deinstallation

```bash
sudo foxly-motd uninstall
```

Konfiguration, Cache und Backups bleiben bewusst erhalten. Sie können nach einer Kontrolle manuell entfernt werden.

## English

Foxly MOTD is a fast, updateable German and English system dashboard for Debian and Ubuntu SSH logins. It includes IP addresses with CIDR prefixes, DNS servers, systemd and reboot health, and detailed Docker states. System information is arranged in a compact three-column grid for network, resources, session, system health, and package updates. Package metadata is refreshed by a systemd timer, so the login path performs no APT or network requests.

### Installation

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash
```

The interactive installer asks whether the MOTD should use automatic locale detection, German or English. For an unattended English installation:

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash -s -- --language en
```

The [visual configurator](https://motd.foxly.de/#configurator) provides an immediate terminal preview and generates a complete configuration locally in the browser. During upgrades, the installer preserves existing settings and only appends newly introduced options with compatible defaults.

### Migrating the legacy dotfiles version

Recognized legacy `/etc/update-motd.d/00-header` and `10-sysinfo` files are archived under `/var/backups/foxly-motd/` and removed only after the new installation succeeds.

1. Review the existing files:

   ```bash
   sudo ls -l /etc/update-motd.d/00-header /etc/update-motd.d/10-sysinfo
   ```

2. Run the migration and select `auto`, `de`, or `en` when prompted:

   ```bash
   curl -fsSL https://motd.foxly.de/install.sh | sudo bash
   ```

3. Verify the result and migration backup:

   ```bash
   foxly-motd status
   foxly-motd preview
   sudo cat /var/lib/foxly-motd/legacy-migration
   sudo ls -lh /var/backups/foxly-motd/legacy-*.tar.gz
   ```

If Foxly MOTD 1.0 is already installed alongside the legacy scripts, `sudo foxly-motd update` performs the outstanding migration. Unrecognized files are preserved. Use `--migrate-legacy force` only after reviewing heavily customized legacy files, or `--migrate-legacy off` to skip migration.

To restore the legacy installation, first read the exact backup path from the migration record, then run:

```bash
sudo foxly-motd uninstall
sudo tar -xzf /var/backups/foxly-motd/legacy-YYYYMMDD-HHMMSS.tar.gz -C /
sudo run-parts /etc/update-motd.d
```

The migration intentionally does not revert changes to `/etc/motd`, SSH `PrintLastLog`, or execute permissions of unrelated MOTD scripts that may have been made by the old installer. Review those settings separately; always validate SSH changes with `sshd -t` before reloading the service.

The old `motd-scripts` source is no longer needed by installation, updates, or rollback. Remove it only after every affected server has been verified and at least one legacy backup has been stored outside the server.

### Common commands

```bash
foxly-motd status
foxly-motd preview
sudo foxly-motd update
sudo foxly-motd rollback
sudo foxly-motd uninstall
```

Configuration is stored in `/etc/default/foxly-motd`. `MOTD_LANGUAGE=auto` follows the login or operating-system locale; `de` and `en` select a fixed language. Automatic software updates are disabled by default; the daily timer only records and displays available releases.

## Entwicklung

```bash
bash -n bin/foxly-motd install.sh docs/install.sh motd/* libexec/* tests/integration.sh
shfmt -i 4 -ci -sr -d bin/foxly-motd install.sh docs/install.sh motd/* libexec/* tests/integration.sh
bash tests/integration.sh
node tests/web.js
```

## Lizenz

MIT – siehe [LICENSE](LICENSE).
