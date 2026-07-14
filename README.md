# Foxly MOTD

Ein schnelles, updatefähiges System-Dashboard für SSH-Logins auf Debian und Ubuntu.

[Website](https://motd.foxly.de) · [English](#english) · [Deutsch](#deutsch)

## Deutsch

Foxly MOTD zeigt Hostname, Betriebssystem, IP-Adressen, Uptime, Systemlast, RAM, Swap, Speicherplatz, Docker-Status und verfügbare Paketupdates auf Deutsch oder Englisch. Netzwerk- und APT-Aufrufe werden nicht während des Logins ausgeführt: systemd aktualisiert die Paketinformationen im Hintergrund, während das MOTD ausschließlich lokale und gecachte Daten liest.

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

Bei einer interaktiven Erstinstallation fragt der Installer nach `auto`, `de` oder `en`. `auto` verwendet die Locale des SSH-Logins beziehungsweise des Betriebssystems. Für unbeaufsichtigte Installationen kann die Sprache direkt übergeben werden:

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash -s -- --language de
```

### Migration der alten Dotfiles-Version

Der Installer erkennt die früheren Foxly-Dateien `/etc/update-motd.d/00-header` und `/etc/update-motd.d/10-sysinfo`. Erkannte Legacy-Dateien werden vor der Migration unter `/var/backups/foxly-motd/legacy-*.tar.gz` archiviert und erst nach erfolgreicher Installation der neuen Skripte entfernt.

Gleichnamige fremde oder stark angepasste Dateien werden im Standardmodus nicht verändert. Nach einer manuellen Prüfung kann ihre Migration ausdrücklich erzwungen werden:

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash -s -- --migrate-legacy force
```

Mit `--migrate-legacy off` wird die Legacy-Erkennung vollständig übersprungen. Der Migrationsstatus wird unter `/var/lib/foxly-motd/legacy-migration` protokolliert.

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
SHOW_DOCKER=yes
SHOW_PACKAGE_UPDATES=yes
SHOW_UPDATE_NOTICE=yes
UPDATE_MODE=notify
```

Erlaubte Werte für Schalter sind `yes` und `no`. `MOTD_LANGUAGE` akzeptiert `auto`, `de` und `en`; `COLOR_MODE` akzeptiert `always` und `never`; `UPDATE_MODE` akzeptiert `notify` und `automatic`.

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

Foxly MOTD is a fast, updateable German and English system dashboard for Debian and Ubuntu SSH logins. Package metadata is refreshed by a systemd timer, so the login path performs no APT or network requests.

### Installation

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash
```

The interactive installer asks whether the MOTD should use automatic locale detection, German or English. For an unattended English installation:

```bash
curl -fsSL https://motd.foxly.de/install.sh | sudo bash -s -- --language en
```

### Migrating the legacy dotfiles version

Recognized legacy `/etc/update-motd.d/00-header` and `10-sysinfo` files are archived under `/var/backups/foxly-motd/` and removed only after the new installation succeeds. Unrecognized files are preserved. Use `--migrate-legacy force` only after reviewing heavily customized legacy files, or `--migrate-legacy off` to skip migration.

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
