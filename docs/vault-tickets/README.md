# Bóveda de conocimiento — Gestor de Tickets (MGCI)

Notas atómicas (Markdown + wikilinks `[[ ]]`) del módulo de tickets ITIL.
Es la versión navegable del skill `@tickets_cases`. Empieza por **[[00-Indice]]**.

```
vault-tickets/
├── 00-Indice.md            ← mapa de contenido (MOC), empieza aquí
├── diseno/                 ← especificación original
└── implementacion/         ← estado real, trampas, changelog
```

## Verla en Obsidian (tu laptop) — recomendado

1. En tu laptop: `git pull` la rama `feat/tickets`.
2. Obsidian → **Open folder as vault** → elige `docs/vault-tickets`.
3. Los `[[wikilinks]]`, backlinks y el grafo funcionan solos. Para las tablas
   automáticas del índice, instala el plugin **Dataview**.

## Verla por navegador (desde el servidor) — code-server + Foam

Ya está montado un **code-server** (VS Code en el navegador) con la extensión
**Foam** (wikilinks, backlinks, grafo estilo Obsidian), detrás de nginx + Cloudflare.

```bash
cd /opt/chatwoot/docs/vault-tickets
docker compose up -d      # levantar
docker compose down       # apagar
docker compose logs -f    # ver logs
```

- Abre el **workspace multi-raíz** `docs/vaults.code-workspace`, que muestra **dos
  bóvedas** como raíces separadas: **📋 Tickets (MGCI)** y **📚 Base de Conocimiento**
  (`docs/vault-kbase/`). Foam combina ambas en un solo grafo (`Ctrl+Shift+P → Foam: Show Graph`).
- **URL: `https://vaults.wintook.com`** (TLS por Cloudflare).
- Contraseña: en el archivo `.env` (NO se versiona; `chmod 600`).
- code-server escucha solo en `127.0.0.1:8080`; nginx
  (`/etc/nginx/sites-available/vaults.wintook.com`) hace de reverse proxy con
  WebSocket. El puerto 8080 **no** queda expuesto a internet.
- DNS: registro de `vaults` → IP del servidor, **proxied** en Cloudflare.
- Foam y extensiones persisten en el volumen `codeserver-data` (sobreviven `up -d`).
- Comandos Foam útiles (Ctrl+Shift+P): **Foam: Show Graph**, navegación por
  `[[wikilinks]]`, panel de backlinks.

> El contenedor monta **todo el repo** en `/home/coder/project` y abre la bóveda
> como carpeta de trabajo, así que también puedes ver/editar el código desde ahí.

## Mantenimiento

- El detalle vive aquí; el skill `~/.claude/commands/tickets_cases.md` solo enruta.
- Al resolver algo nuevo: añade entrada a
  `implementacion/Historial-de-implementacion.md` (y a `Trampas.md` si aplica).
  Tema grande nuevo → nota atómica + enlázala desde `00-Indice.md`.
