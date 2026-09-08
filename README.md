# Foxly MOTD

System-Dashboard für SSH-Logins auf Debian und Ubuntu.

System dashboard for SSH logins on Debian and Ubuntu.

[Deutsch](#deutsch) · [English](#english) · [Website](https://motd.foxly.de)

<a id="deutsch"></a>

## Deutsch

[Voraussetzungen und Shells](#de-requirements) · [Installation](#de-installation) · [Migration](#de-migration) · [Befehle](#de-commands) · [Konfiguration](#de-configuration) · [Datenquellen](#de-data-sources) · [Shells, Warp und Proxmox](#de-shells) · [Pfade](#de-paths) · [Update-Sicherheit](#de-update-safety) · [Deinstallation](#de-uninstall) · [Entwicklung](#de-development) · [Lizenz](#de-license)

Foxly MOTD zeigt Hostname, Betriebssystem, IP-Adressen mit CIDR-Präfix, DNS-Server, Uptime, Systemlast, RAM, Swap, Speicherplatz, systemd-Zustand, Neustartbedarf, Docker-Status und verfügbare Paketupdates auf Deutsch oder Englisch. Die Systeminformationen sind dabei in einem platzsparenden dreispaltigen Raster nach Netzwerk, Ressourcen, Sitzung, Systemstatus und Paket-Updates gruppiert. Paket- und Release-Abfragen laufen außerhalb des Logins: systemd aktualisiert die Paketinformationen im Hintergrund, während das MOTD gecachte Daten liest und Systemwerkzeuge abfragt.

<a id="de-requirements"></a>

### Voraussetzungen und unterstützte Shells

- Debian und Ubuntu mit systemd und `pam_motd`
- Bash 4 oder neuer für Installer, Verwaltungsbefehl und MOTD-Skripte
- Bash, Zsh und Fish mit eigenen Hooks für interaktive Warp-SSH-Sitzungen; Details unter [Shells, Warp und Proxmox](#de-shells)
- APT-basierte Paketverwaltung
- Docker optional
- `lolcat` optional; bei Fehlen werden normale ANSI-Farben verwendet

<a id="de-installation"></a>

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

Der Download-Installer benötigt bereits `curl`, `tar`, `sha256sum`, `awk` und `sed`. Der eigentliche Installer installiert fehlende Kernabhängigkeiten, übernimmt vorhandene Einstellungen und aktiviert zwei Timer:

- `foxly-motd-cache.timer`: aktualisiert den Paket-Cache alle 30 Minuten mit bis zu fünf Minuten Zufallsverzögerung
- `foxly-motd-update.timer`: prüft täglich auf neue Foxly-MOTD-Releases

Softwareupdates laufen standardmäßig im Modus `notify`: Ein neues Release wird im MOTD angekündigt, aber nicht automatisch installiert.

Auf der [Website](https://motd.foxly.de/#configurator) steht ein visueller Konfigurator bereit. Module und Darstellung können dort ausgewählt, sofort in einer Terminal-Vorschau geprüft und anschließend als vollständige Konfiguration kopiert werden. Die Verarbeitung findet ausschließlich lokal im Browser statt.

Bei einer interaktiven Erstinstallation fragt der Installer nach `auto`, `de` oder `en`. `auto` verwendet die Locale des SSH-Logins beziehungsweise des Betriebssystems. Für unbeaufsichtigte Installationen kann die Sprache direkt übergeben werden:

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash -s -- --language de
```

<a id="de-migration"></a>

### Migration der alten Dotfiles-Version

Der Installer erkennt die früheren Foxly-Dateien `/etc/update-motd.d/00-header` und `/etc/update-motd.d/10-sysinfo`. Erkannte Legacy-Dateien werden vor der Migration unter `/var/backups/foxly-motd/legacy-*.tar.gz` archiviert und nach der Installation der neuen Skripte und Konfiguration entfernt. Die Migration kann daher direkt auf einem Server mit der alten Dotfiles-Version ausgeführt werden.

<a id="de-migration-standard"></a>

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

Nach erfolgreicher Migration ersetzen `/etc/update-motd.d/00-foxly-header` und `/etc/update-motd.d/10-foxly-sysinfo` die erkannten alten Foxly-Skripte. Andere MOTD-Skripte bleiben unverändert. Die alten Dateien werden aus `/etc/update-motd.d` entfernt, bleiben aber im Legacy-Archiv erhalten.

<a id="de-migration-version-1-0"></a>

#### Bereits installierte Version 1.0

Wenn Foxly MOTD 1.0 bereits zusätzlich zu den alten Dotfiles-Skripten installiert wurde, führt ein Update auf ein neueres Release die fehlende Migration nachträglich aus:

```bash
sudo foxly-motd update
foxly-motd preview
```

<a id="de-migration-custom-files"></a>

#### Angepasste oder nicht erkannte Legacy-Dateien

Gleichnamige fremde oder stark angepasste Dateien werden im Standardmodus nicht verändert. Nach einer manuellen Prüfung kann ihre Migration ausdrücklich erzwungen werden:

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash -s -- --migrate-legacy force
```

Mit `--migrate-legacy off` wird die Legacy-Erkennung vollständig übersprungen. Der Migrationsstatus wird unter `/var/lib/foxly-motd/legacy-migration` protokolliert.

<a id="de-migration-restore"></a>

#### Migration zurücknehmen

Zuerst den Pfad des Legacy-Archivs aus `/var/lib/foxly-motd/legacy-migration` prüfen. Anschließend kann die neue Installation entfernt und das alte Archiv wiederhergestellt werden:

```bash
sudo foxly-motd uninstall
sudo tar -xzf /var/backups/foxly-motd/legacy-YYYYMMDD-HHMMSS.tar.gz -C /
sudo run-parts /etc/update-motd.d
```

Konfiguration, Cache und Backups der neuen Version bleiben bei der Deinstallation bewusst erhalten.

<a id="de-migration-other-changes"></a>

#### Änderungen des alten Installers außerhalb von `update-motd.d`

Die Migration verändert ausschließlich die alten Foxly-MOTD-Skripte. Optionale Änderungen, die der frühere Installer vorgenommen haben könnte, werden nicht automatisch zurückgesetzt:

- ein geleertes `/etc/motd` und eventuell vorhandene Backups `/etc/motd.bak-*`
- `PrintLastLog no` in der SSH-Konfiguration
- andere MOTD-Skripte, denen der alte Installer das Ausführungsrecht entzogen hat

Diese Einstellungen können absichtlich auf dem Server gesetzt worden sein und müssen deshalb vor einer manuellen Rücknahme einzeln geprüft werden. Eine SSH-Konfigurationsänderung sollte immer mit `sshd -t` validiert werden, bevor der Dienst neu geladen wird.

Der alte `motd-scripts`-Ordner wird für Installation, Updates oder Rollbacks nicht mehr benötigt. Er sollte erst entfernt werden, nachdem die Migration auf allen betroffenen Servern geprüft und mindestens ein Legacy-Backup außerhalb des Servers gesichert wurde.

<a id="de-commands"></a>

### Befehle

```bash
foxly-motd help                      # Hilfe anzeigen
foxly-motd version                   # Installierte Version anzeigen
foxly-motd status                    # Version, Cache und Timer anzeigen
foxly-motd preview                   # MOTD direkt anzeigen
sudo foxly-motd refresh              # Paket-Cache sofort aktualisieren
foxly-motd check-update              # Nach einem neuen Release suchen
sudo foxly-motd update               # Aktuelles Release installieren
sudo foxly-motd rollback             # Neuestes Upgrade-Backup wiederherstellen
sudo foxly-motd enable-auto-update   # Releases automatisch installieren
sudo foxly-motd disable-auto-update  # Nur über Releases informieren
sudo foxly-motd uninstall            # Installation entfernen
```

`check-update` liefert Status `0`, wenn installierte und neueste Version übereinstimmen, und Status `10`, wenn sie sich unterscheiden.

<a id="de-configuration"></a>

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

Erlaubte Werte für Schalter sind `yes` und `no`. `SHOW_NETWORK`, `SHOW_RESOURCES`, `SHOW_SESSION`, `SHOW_SYSTEM_HEALTH` und `SHOW_PACKAGE_UPDATES` steuern die Module im dreispaltigen Raster. `SHOW_NETWORK_DETAILS` ergänzt die DNS-Anzeige. `SHOW_DOCKER` steuert die Docker-Zusammenfassung. Mit `SHOW_PACKAGE_NAMES` und `PACKAGE_NAME_LIMIT` (1–20) lässt sich eine begrenzte Paketliste einblenden; standardmäßig bleibt die Paketmeldung kompakt. `SHOW_UPDATE_NOTICE` steuert den Hinweis auf neue Foxly-MOTD-Releases, `SHOW_FRAME` den Außenrahmen. `MOTD_LANGUAGE` akzeptiert `auto`, `de` und `en`; `COLOR_MODE` akzeptiert `always` und `never`; `UPDATE_MODE` akzeptiert `notify` und `automatic`. `USE_LOLCAT` aktiviert die optionale Einfärbung des Headers, `FIGLET_FONT` wählt die figlet-Schrift.

Bei einem Upgrade bleibt eine vorhandene `/etc/default/foxly-motd` erhalten. Der Installer ergänzt ausschließlich fehlende Konfigurationsschlüssel mit den aktuellen Standardwerten. Bereits gesetzte Werte und eigene zusätzliche Einträge bleiben erhalten. Eine ausdrücklich gewählte Sprache, etwa über `--language en`, überschreibt jedoch `MOTD_LANGUAGE`.

Bei `auto` wird zuerst `LC_ALL`, dann `LC_MESSAGES`, dann `LANG` ausgewertet; fehlen diese Werte, wird `/etc/default/locale` gelesen. Locales mit dem Präfix `de` wählen Deutsch, alle anderen Englisch. `foxly-motd preview` erzwingt Farben auch bei `COLOR_MODE=never`.

<a id="de-data-sources"></a>

### Datenquellen und Login-Verhalten

Die MOTD-Skripte starten beim Login weder APT noch HTTP-Abfragen. Die Docker-Abfrage verwendet den konfigurierten Docker-Endpunkt; für ausschließlich lokale Abfragen muss dieser auf den lokalen Daemon zeigen. Die angezeigten Werte stammen aus lokalen Dateien, lokalen Systemwerkzeugen oder dem von systemd gepflegten Paket-Cache:

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

<a id="de-shells"></a>

### Shells, Warp Terminal und Proxmox LXC

Normale SSH-Logins verwenden die MOTD-Anzeige über PAM. Die MOTD-Skripte laufen mit Bash, unabhängig davon, welche Login-Shell der Benutzer verwendet. Für andere Shells als Bash, Zsh und Fish enthält das Projekt keine eigenen Warp-Hooks.

Warp kann die normale PAM-Anzeige beim SSH-Shell-Start umgehen. Der Installer ergänzt dafür folgende Startdateien:

| Shell | Startdatei | Einrichtung |
| --- | --- | --- |
| Bash | `/etc/bash.bashrc` | Bei jeder Installation und jedem ausgeführten Upgrade |
| Zsh | `/etc/zsh/zshenv` | Wenn `/etc/zsh` vorhanden ist |
| Fish | `/etc/fish/config.fish` | Wenn `/etc/fish` vorhanden ist |

Die Shells selbst werden nicht installiert. Ein alter Foxly-Hook in `/etc/zsh/zshrc` wird beim Installer-Lauf entfernt und durch den Hook in `zshenv` ersetzt. Dieser Einstiegspunkt berücksichtigt den im Projekt dokumentierten Warp-Bootstrap, bei dem `zshrc` übersprungen wurde.

Der Hook zeigt das Dashboard, wenn die Shell interaktiv ist, die Standardausgabe an einem Terminal hängt, `TERM_PROGRAM=WarpTerminal` gesetzt ist und sowohl `SSH_CONNECTION` als auch `SSH_TTY` vorhanden sind. Ein exportierter Marker verhindert die erneute Anzeige für dasselbe SSH-Terminal in nachgestarteten Shells. `~/.hushlogin` unterdrückt den Hook. Nichtinteraktive Befehle und lokale Warp-Shells erhalten keine zusätzliche Ausgabe.

Wird Zsh oder Fish später nachinstalliert, muss der Installer erneut laufen. Ein Update auf ein neueres Release erledigt das ebenfalls; `foxly-motd update` beendet sich bei bereits aktueller Version ohne Installer-Lauf. Aus einer lokalen Repository-Kopie lassen sich die Hooks so nachrüsten:

```bash
sudo bash install.sh --upgrade --no-refresh
```

Vor dem Ergänzen eines neuen Hooks wird eine vorhandene Startdatei unter `/var/backups/foxly-motd/` gesichert. Die Deinstallation entfernt die markierten Foxly-Blöcke aus den genannten Dateien sowie aus der früher verwendeten `/etc/zsh/zshrc` und löscht die Hook-Helfer.

In der Proxmox-Webkonsole im Modus „shell“ kann die Anzeige ohne normalen Login mit `foxly-motd preview` aufgerufen werden.

<a id="de-paths"></a>

### Pfade

| Zweck | Pfad |
| --- | --- |
| Verwaltungsbefehl | `/usr/local/sbin/foxly-motd` |
| MOTD-Skripte | `/etc/update-motd.d/00-foxly-header`, `/etc/update-motd.d/10-foxly-sysinfo` |
| Konfiguration | `/etc/default/foxly-motd` |
| Paket-Cache | `/var/cache/foxly-motd/packages` |
| Versionsstatus | `/var/lib/foxly-motd/` |
| Backups | `/var/backups/foxly-motd/` |

<a id="de-update-safety"></a>

### Update-Sicherheit

- private temporäre Verzeichnisse über `mktemp`
- versionierte GitHub-Release-Archive
- verpflichtende SHA-256-Prüfung vor dem Entpacken
- Prüfung auf unsichere Archivpfade
- Bash-Syntaxprüfung vor der Installation
- Backup vor jedem Upgrade
- sichere Erkennung und separates Backup alter Foxly-MOTD-Skripte
- atomarer Austausch der Cache-Datei
- HTTP-Abfragen mit Verbindungs- und Gesamtlaufzeitlimit

<a id="de-uninstall"></a>

### Deinstallation

```bash
sudo foxly-motd uninstall
```

Konfiguration, Cache, Versionsstatus und Backups bleiben erhalten. Sie können nach einer Kontrolle manuell entfernt werden.

<a id="de-development"></a>

### Entwicklung

Die CI führt diese Prüfungen unter Ubuntu mit Bash, Zsh, Fish, ShellCheck, shfmt, Python 3 und Node.js aus. Die Warp-Tests prüfen die Hooks für alle drei Shells.

```bash
bash -n bin/foxly-motd install.sh docs/install.sh motd/* libexec/foxly-motd-cache libexec/foxly-motd-warp tests/integration.sh
fish --no-execute libexec/foxly-motd-warp.fish
shellcheck -x bin/foxly-motd install.sh docs/install.sh motd/* libexec/foxly-motd-cache libexec/foxly-motd-warp tests/integration.sh
shfmt -i 4 -ci -sr -d bin/foxly-motd install.sh docs/install.sh motd/* libexec/foxly-motd-cache libexec/foxly-motd-warp tests/integration.sh
bash tests/integration.sh
python3 tests/warp.py
node tests/web.js
```

<a id="de-license"></a>

### Lizenz

MIT – siehe [LICENSE](LICENSE).

[Zurück zur Sprachauswahl](#foxly-motd) · [English](#english)

<a id="english"></a>

## English

[Requirements and shells](#en-requirements) · [Installation](#en-installation) · [Migration](#en-migration) · [Commands](#en-commands) · [Configuration](#en-configuration) · [Data sources](#en-data-sources) · [Shells, Warp and Proxmox](#en-shells) · [Paths](#en-paths) · [Update safeguards](#en-update-safety) · [Uninstallation](#en-uninstall) · [Development](#en-development) · [License](#en-license)

Foxly MOTD displays the hostname, operating system, IP addresses with CIDR prefixes, DNS servers, uptime, system load, RAM, swap, disk usage, systemd health, reboot status, Docker states and available package updates in German or English. System information is grouped in a compact three-column grid. Package and release checks run outside the login path: systemd refreshes package metadata in the background, while the MOTD reads cached data and queries system tools.

<a id="en-requirements"></a>

### Requirements and supported shells

- Debian or Ubuntu with systemd and `pam_motd`
- Bash 4 or newer for the installer, management command and MOTD scripts
- Bash, Zsh and Fish with dedicated hooks for interactive Warp SSH sessions; see [Shells, Warp and Proxmox](#en-shells)
- APT-based package management
- Docker is optional
- `lolcat` is optional; standard ANSI colors are used when it is unavailable

<a id="en-installation"></a>

### Installation

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash
```

To inspect the download script before running it:

```bash
curl -fsSLo foxly-motd-install.sh https://motd.foxly.de/install.sh
less foxly-motd-install.sh
sudo bash foxly-motd-install.sh
```

From a local repository checkout:

```bash
sudo bash install.sh
```

The download installer requires `curl`, `tar`, `sha256sum`, `awk` and `sed` to be available. The release installer installs missing core dependencies, keeps existing settings and enables two timers:

- `foxly-motd-cache.timer`: refreshes package metadata every 30 minutes, with up to five minutes of randomized delay
- `foxly-motd-update.timer`: checks for new Foxly MOTD releases daily

The default software update mode is `notify`: a new release is announced in the MOTD but is not installed automatically.

The [visual configurator](https://motd.foxly.de/#configurator) lets you select modules and appearance, inspect a terminal preview and copy a complete configuration. Configuration is processed locally in the browser.

During an interactive installation, the installer asks for `auto`, `de` or `en`. `auto` uses the login or operating-system locale. For an unattended English installation:

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash -s -- --language en
```

<a id="en-migration"></a>

### Migrating the legacy dotfiles version

The installer recognizes the legacy Foxly files `/etc/update-motd.d/00-header` and `/etc/update-motd.d/10-sysinfo`. Recognized files are archived under `/var/backups/foxly-motd/legacy-*.tar.gz` before migration and removed after the new scripts and configuration have been installed.

<a id="en-migration-standard"></a>

#### Standard migration

1. Check the existing files and their execute permissions:

   ```bash
   sudo ls -l /etc/update-motd.d/00-header /etc/update-motd.d/10-sysinfo
   ```

2. Run the installer and select `auto`, `de` or `en` when prompted:

   ```bash
   curl -fsSL https://motd.foxly.de/install.sh | sudo bash
   ```

3. Check the installation, timers and output:

   ```bash
   foxly-motd status
   foxly-motd preview
   systemctl list-timers 'foxly-motd-*'
   ```

4. Check the migration record and backup:

   ```bash
   sudo cat /var/lib/foxly-motd/legacy-migration
   sudo ls -lh /var/backups/foxly-motd/legacy-*.tar.gz
   ```

After migration, `/etc/update-motd.d/00-foxly-header` and `/etc/update-motd.d/10-foxly-sysinfo` replace the recognized legacy Foxly scripts. Other MOTD scripts remain unchanged. The old files remain in the legacy archive.

<a id="en-migration-version-1-0"></a>

#### Version 1.0 already installed

If Foxly MOTD 1.0 was installed alongside the old dotfiles scripts, updating to a newer release performs the outstanding migration:

```bash
sudo foxly-motd update
foxly-motd preview
```

<a id="en-migration-custom-files"></a>

#### Customized or unrecognized legacy files

Unrecognized files are left untouched by default. After manually reviewing them, you can explicitly force migration:

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash -s -- --migrate-legacy force
```

Use `--migrate-legacy off` to skip legacy detection. Migration is recorded in `/var/lib/foxly-motd/legacy-migration`.

<a id="en-migration-restore"></a>

#### Reverting the migration

Read the exact archive path from `/var/lib/foxly-motd/legacy-migration`, then remove the new installation and restore that archive. Replace the timestamp below with the actual backup filename:

```bash
sudo foxly-motd uninstall
sudo tar -xzf /var/backups/foxly-motd/legacy-YYYYMMDD-HHMMSS.tar.gz -C /
sudo run-parts /etc/update-motd.d
```

Uninstallation retains the new version's configuration, cache and backups.

<a id="en-migration-other-changes"></a>

#### Changes outside `update-motd.d` made by the old installer

Migration only handles the old Foxly MOTD scripts. It does not revert optional changes the earlier installer may have made:

- an emptied `/etc/motd` and any `/etc/motd.bak-*` backups
- `PrintLastLog no` in the SSH configuration
- execute permissions removed from other MOTD scripts

Review these settings individually before reverting them. Validate SSH configuration changes with `sshd -t` before reloading the service.

The old `motd-scripts` directory is no longer needed for installation, updates or rollback. Remove it only after verifying migration on all affected servers and storing at least one legacy backup outside the server.

<a id="en-commands"></a>

### Commands

```bash
foxly-motd help                      # Show help
foxly-motd version                   # Show the installed version
foxly-motd status                    # Show version, cache and timer status
foxly-motd preview                   # Display the MOTD
sudo foxly-motd refresh              # Refresh package metadata now
foxly-motd check-update              # Check for a new release
sudo foxly-motd update               # Install the latest release
sudo foxly-motd rollback             # Restore the newest upgrade backup
sudo foxly-motd enable-auto-update   # Install releases automatically
sudo foxly-motd disable-auto-update  # Only announce available releases
sudo foxly-motd uninstall            # Remove the installation
```

`check-update` returns status `0` when the installed and latest versions match, and `10` when they differ.

<a id="en-configuration"></a>

### Configuration

Configuration is stored in `/etc/default/foxly-motd`. Defaults:

```bash
MOTD_LANGUAGE=auto
COLOR_MODE=always
USE_LOLCAT=yes
FIGLET_FONT=slant
SHOW_NETWORK_DETAILS=yes
SHOW_NETWORK=yes
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

Switches accept `yes` and `no`. `SHOW_NETWORK`, `SHOW_RESOURCES`, `SHOW_SESSION`, `SHOW_SYSTEM_HEALTH` and `SHOW_PACKAGE_UPDATES` control the grid modules. `SHOW_NETWORK_DETAILS` adds DNS information. `SHOW_DOCKER` controls the Docker summary. `SHOW_PACKAGE_NAMES` and `PACKAGE_NAME_LIMIT` (1–20) enable a limited package list; the default output stays compact. `SHOW_UPDATE_NOTICE` controls the Foxly MOTD release notice, and `SHOW_FRAME` controls the outer frame.

`MOTD_LANGUAGE` accepts `auto`, `de` and `en`; `COLOR_MODE` accepts `always` and `never`; `UPDATE_MODE` accepts `notify` and `automatic`. `USE_LOLCAT` enables the optional header coloring, and `FIGLET_FONT` selects the figlet font.

Upgrades preserve existing settings and additional custom entries, appending only missing keys with their current defaults. An explicit language selection, such as `--language en`, does overwrite `MOTD_LANGUAGE`.

In `auto` mode, language detection checks `LC_ALL`, then `LC_MESSAGES`, then `LANG`, falling back to `/etc/default/locale` if none is set. Locales beginning with `de` select German; all others select English. `foxly-motd preview` forces colors even with `COLOR_MODE=never`.

<a id="en-data-sources"></a>

### Data sources and login behavior

The MOTD scripts do not start APT or HTTP requests during login. The Docker query uses the configured Docker endpoint; it must point to the local daemon for queries to remain entirely local.

| Display | Data source |
| --- | --- |
| Operating system and kernel | `/etc/os-release`, `uname` |
| IP addresses and CIDR prefixes | `ip address` |
| DNS servers | `resolvectl dns`, falling back to `/etc/resolv.conf` |
| Failed services | `systemctl --failed --type=service` |
| Reboot required | `/var/run/reboot-required` |
| Docker states | `docker ps`, including `unhealthy` and `restarting` |
| Package updates | `/var/cache/foxly-motd/packages`, refreshed by the cache timer |
| Remote host | SSH and PAM session data, falling back to `who -m` |

DNS, systemd and Docker queries each have a two-second timeout. Unavailable sources produce `N/A` or a status message. If `/etc/resolv.conf` points to a local stub resolver, a DNS server such as `127.0.0.53` may appear.

<a id="en-shells"></a>

### Shells, Warp Terminal and Proxmox LXC

Normal SSH logins use PAM to display the MOTD. The MOTD scripts run with Bash regardless of the user's login shell. The project contains dedicated Warp hooks for Bash, Zsh and Fish only.

Warp can bypass the normal PAM display during SSH shell startup. The installer adds hooks to these startup files:

| Shell | Startup file | Installation condition |
| --- | --- | --- |
| Bash | `/etc/bash.bashrc` | Every installation and executed upgrade |
| Zsh | `/etc/zsh/zshenv` | When `/etc/zsh` exists |
| Fish | `/etc/fish/config.fish` | When `/etc/fish` exists |

The installer does not install these shells. An old Foxly hook in `/etc/zsh/zshrc` is removed and replaced with the `zshenv` hook when the installer runs. This entry point accounts for the Warp bootstrap behavior documented in the project, where `zshrc` was skipped.

The hook displays the dashboard when the shell is interactive, standard output is a terminal, `TERM_PROGRAM=WarpTerminal` is set, and both `SSH_CONNECTION` and `SSH_TTY` are present. An exported marker prevents another display for the same SSH terminal in child shells. `~/.hushlogin` suppresses the hook. Noninteractive commands and local Warp shells receive no additional output.

If Zsh or Fish is installed later, run the installer again. Updating to a newer release also sets up the hooks; `foxly-motd update` exits without running the installer if the latest version is already installed. From a local repository checkout:

```bash
sudo bash install.sh --upgrade --no-refresh
```

Before appending a new hook, the installer backs up an existing startup file under `/var/backups/foxly-motd/`. Uninstallation removes the marked Foxly blocks from the files above and the formerly used `/etc/zsh/zshrc`, along with the hook helpers.

In the Proxmox web console's “shell” mode, use `foxly-motd preview` to display the dashboard without a normal login.

<a id="en-paths"></a>

### Paths

| Purpose | Path |
| --- | --- |
| Management command | `/usr/local/sbin/foxly-motd` |
| MOTD scripts | `/etc/update-motd.d/00-foxly-header`, `/etc/update-motd.d/10-foxly-sysinfo` |
| Configuration | `/etc/default/foxly-motd` |
| Package cache | `/var/cache/foxly-motd/packages` |
| Version state | `/var/lib/foxly-motd/` |
| Backups | `/var/backups/foxly-motd/` |

<a id="en-update-safety"></a>

### Update safeguards

- private temporary directories created with `mktemp`
- versioned GitHub release archives
- mandatory SHA-256 verification before extraction
- checks for unsafe archive paths
- Bash syntax checks before installation
- a backup before each upgrade
- recognition and separate backups of legacy Foxly MOTD scripts
- atomic replacement of the cache file
- connection and total runtime limits for HTTP requests

<a id="en-uninstall"></a>

### Uninstallation

```bash
sudo foxly-motd uninstall
```

Configuration, cache, version state and backups are retained. Review them before removing them manually.

<a id="en-development"></a>

### Development

CI runs these checks on Ubuntu with Bash, Zsh, Fish, ShellCheck, shfmt, Python 3 and Node.js. The Warp tests exercise the hooks for all three shells.

```bash
bash -n bin/foxly-motd install.sh docs/install.sh motd/* libexec/foxly-motd-cache libexec/foxly-motd-warp tests/integration.sh
fish --no-execute libexec/foxly-motd-warp.fish
shellcheck -x bin/foxly-motd install.sh docs/install.sh motd/* libexec/foxly-motd-cache libexec/foxly-motd-warp tests/integration.sh
shfmt -i 4 -ci -sr -d bin/foxly-motd install.sh docs/install.sh motd/* libexec/foxly-motd-cache libexec/foxly-motd-warp tests/integration.sh
bash tests/integration.sh
python3 tests/warp.py
node tests/web.js
```

<a id="en-license"></a>

### License

MIT – see [LICENSE](LICENSE).

[Back to language selection](#foxly-motd) · [Deutsch](#deutsch)
