# Bandejas agrupadas por tipo · registro

> Rama: `feat/bandejas_por_tipo` (desde `develop` fc062ced) · 26/10/2026
> Plan: `docs/chat_interno_plan.md` §10 (parte B), en la rama `feat/chat_interno`.
> Decisiones: D8 orden **por agente** · D9 grupos **plegables y recordados** · D10 **con contador** · D11 **PR propio**.

## Qué se hizo (B1–B3)

```
 Conversaciones
 ├─ Todas las Conversaciones
 ├─ Menciones
 ├─ No Atendidas
 ├─ ⇅ Ordenar bandejas…          ← abre el modal
 ├─ ▾ WhatsApp (3)                ← un grupo por tipo, plegable
 ├─ ▾ Telegram (1)
 ├─ ▾ Correo (2)
 ├─ ▸ Meta (Messenger e Instagram) (2)
 └─ ▾ … Sitio web, TikTok, Otros canales
```

- **Grupos por tipo** en lugar de la carpeta única «Bandejas de entrada». Orden por omisión:
  WhatsApp → Telegram → Correo → Meta → Sitio web → TikTok → Otros canales. Los grupos vacíos no salen;
  dentro de cada grupo, las bandejas siguen por nombre.
- **«Ordenar bandejas…»** justo debajo de «No Atendidas»: modal para arrastrar o usar ▲▼, con
  «Restablecer» y el número de bandejas de cada grupo.
- **Cada grupo se pliega** por su cuenta y se recuerda en el navegador.
- «Nueva bandeja» (administradores) aparece una sola vez, al final del último grupo. Sin bandejas
  queda la carpeta de siempre.
- Se respeta «Ocultar todas las bandejas a los agentes».

## Cómo funciona

| Pieza | Archivo |
|---|---|
| A qué grupo va cada bandeja, orden y armado de grupos (funciones puras) | `helper/inboxGroups.js` |
| Grupos, opción del menú y modal | `components/layout/sidebarComponents/Secondary.vue` |
| Elemento de acción, plegado y contador | `components/layout/sidebarComponents/SecondaryNavItem.vue` |
| Modal «Ordenar bandejas por tipo» (vuedraggable + ▲▼) | `components/layout/sidebarComponents/InboxGroupsOrderModal.vue` |
| Textos | `i18n/locale/{es,en}/settings.json` → `SIDEBAR.SORT_INBOXES`, `INBOX_GROUPS.*`, `INBOX_GROUPS_MODAL.*` |

- **Dónde se guarda el orden:** `ui_settings.inbox_group_order[<id de cuenta>]` del agente (D8). Un
  orden viejo o roto se normaliza: se quitan grupos desconocidos o repetidos y los faltantes se
  agregan al final.
- **Qué cae en cada grupo:** WhatsApp = `Channel::Whatsapp` + Twilio con número `whatsapp:`;
  Meta = `Channel::FacebookPage` + `Channel::Instagram`; Correo = `Channel::Email`; Sitio web =
  `Channel::WebWidget`; TikTok = `Channel::Tiktok`; Otros = SMS, Twilio SMS, Line, API, Twitter y
  cualquier tipo nuevo.
- **Plegado:** `localStorage['inbox_groups_folded']` con llave `<cuenta>:<grupo>`.

## Pruebas

- Vitest `helper/specs/inboxGroups.spec.js` (21): cada tipo de canal, Twilio WhatsApp/SMS, normalizar
  el orden, orden por cuenta, agrupado por omisión y a la medida, orden por nombre, sin bandejas.
- Vitest `sidebarComponents/specs/InboxGroupsOrderModal.spec.js` (5): copia del orden, subir/bajar y
  bordes, restablecer, guardar, textos y contador.
- Pruebas existentes del menú: 53/53. Eslint sin avisos nuevos (los 24 de `Secondary.vue` ya venían de develop).
- Backend: `profiles#update` acepta el orden anidado por cuenta en `ui_settings` (verificado).
- ⚠️ Falta probarlo en el navegador.
