# Bóveda de conocimiento — Contact Tracking (Seguimientos IA)

Notas atómicas (Markdown + wikilinks `[[ ]]`) del módulo **Contact Tracking**:
re-enganche automático de contactos con un **agente IA** (seguimientos programados
con reintentos, plantillas, asignación masiva, importación Excel/CSV, router de
intención y soporte WhatsApp con ventana de 24 h). Empieza por **[[00-Indice]]**.

```
vault-contact-tracking/
├── 00-Indice.md            ← mapa de contenido (MOC), empieza aquí
├── diseno/                 ← qué es, modelo de datos, ciclo de vida, servicios, frontend, API
└── implementacion/         ← archivos reales, bulk assign, importación, estado y pendientes
```

> Rama `dashboard_contact_tracking` (derivada de `develop`). El módulo ya está
> **mayormente construido**; esta bóveda documenta su estado real para retomarlo
> sin releer todo el código.

## Ver el grafo de relaciones

- **En el navegador (code-server / Foam):** `Ctrl+Shift+P` → **Foam: Show Graph**.
- **En tu laptop (Obsidian):** abre `docs/vault-contact-tracking` como vault →
  panel de **Graph view**.

En el servidor, esta bóveda se ve **junto** a las de Tickets y Base de Conocimiento
vía un workspace multi-raíz (`docs/vaults.code-workspace`, fuera de git por ser
config local del servidor). Es lo que sirve `vaults.wintook.com`.

## Relación con otras bóvedas

- **Base de Conocimiento** (`vault-kbase`): el router de intención tiene una ruta
  `:kbase` y las plantillas un `kbase_hook_id` para responder preguntas técnicas.
- **Tickets** (`vault-tickets`): mismo patrón de bóveda + skill delgado.
