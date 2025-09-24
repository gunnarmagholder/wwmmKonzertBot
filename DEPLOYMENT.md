# 🐳 wwmm-Concert Bot - Docker Deployment

## Quick Start

### 1. Environment Setup
Erstelle eine `.env` Datei im Projektverzeichnis:

```bash
# Discord Bot Configuration
DISCORD_BOT_TOKEN=your_bot_token_here
DISCORD_CLIENT_ID=your_client_id_here
DISCORD_CHANNEL_ID=your_channel_id_here
```

### 2. Verzeichnisse erstellen
```bash
mkdir -p data logs
chmod 755 data logs
```

### 3. Bot starten
```bash
# Build und Start in einem Schritt
docker-compose up -d

# Oder separat:
docker-compose build
docker-compose up -d
```

### 4. Status prüfen
```bash
# Container Status
docker-compose ps

# Logs anschauen
docker-compose logs -f

# In Container einsteigen (für Debugging)
docker-compose exec hamburg-concert-bot bash
```

## 🔧 Konfiguration

### Resource Limits
In `docker-compose.yml` anpassen falls nötig:
```yaml
deploy:
  resources:
    limits:
      memory: 512M      # Mehr RAM für mehr Konzerte
      cpus: '0.5'       # CPU-Limit
```

### Daten-Persistierung
- **Konzertdaten**: `./data/concerts.json` (wird alle 6h aktualisiert)
- **Logs**: `./logs/` (optional)

### Umgebungsvariablen
| Variable | Beschreibung | Beispiel |
|----------|--------------|----------|
| `DISCORD_BOT_TOKEN` | Bot Token von Discord Developer Portal | `MTIzNDU2Nzg5...` |
| `DISCORD_CLIENT_ID` | Application ID von Discord | `123456789012345678` |
| `DISCORD_CHANNEL_ID` | Channel ID für Nachrichten | `987654321098765432` |

## 🚀 Production Setup

### SSL/TLS (optional)
Wenn der Bot externe APIs erreichen muss:
```yaml
# In docker-compose.yml unter volumes:
- /etc/ssl/certs:/etc/ssl/certs:ro
```

### Monitoring
```bash
# Health Check
docker-compose exec hamburg-concert-bot test -f /app/data/concerts.json && echo "✅ OK" || echo "❌ FAIL"

# Memory Usage
docker stats hamburg-concert-bot --no-stream
```

### Backups
```bash
# Backup der Konzertdaten
tar -czf backup-$(date +%Y%m%d).tar.gz data/

# Automatisches Backup (Crontab)
0 2 * * * cd /pfad/zum/bot && tar -czf backup-$(date +\%Y\%m\%d).tar.gz data/
```

## 🐛 Troubleshooting

### Container startet nicht
```bash
# Logs prüfen
docker-compose logs hamburg-concert-bot

# Häufige Probleme:
# - .env Datei fehlt oder falsche Tokens
# - Ports bereits belegt
# - Unzureichende Berechtigungen für data/ Ordner
```

### Chrome/Chromium Probleme
```bash
# Container mit Chrome testen
docker-compose exec hamburg-concert-bot chromium --version

# Falls Chrome fehlt, rebuild:
docker-compose build --no-cache
```

### Discord Slash Commands funktionieren nicht
```bash
# Bot muss die Commands erst registrieren (dauert bis zu 1h)
# Oder Bot neu starten:
docker-compose restart hamburg-concert-bot
```

## 📦 Updates

### Code Updates
```bash
git pull
docker-compose build
docker-compose up -d
```

### Gem Updates
```bash
# Neue Gemfile.lock erstellen und rebuilden
docker-compose build --no-cache
```

## 🔒 Security Notes

- Container läuft als non-root User
- Keine privilegierten Rechte
- Network isolation aktiviert
- Sensitive Daten nur über Environment Variables

## 📊 Commands für Users

Nach dem Deployment können Discord-User folgende Slash Commands nutzen:

- `/concerts` - Alle Konzerte anzeigen
- `/concerts artist:Metallica` - Nach Künstler filtern
- `/concerts venue:Barclays` - Nach Venue filtern
- `/concerts limit:5` - Anzahl begrenzen
- `/refresh` - Neue Daten von Songkick laden

---

**Support**: Bei Problemen Logs mit `docker-compose logs` sammeln und an Entwickler senden.
