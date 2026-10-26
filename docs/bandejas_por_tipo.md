# Bandejas agrupadas por tipo · registro

> Rama: `feat/bandejas_por_tipo` (desde `develop` fc062ced) · 26/10/2026
> Plan: `docs/chat_interno_plan.md` §10 (parte B), en la rama `feat/chat_interno`.
> Decisiones: D8 orden **por agente** · D9 grupos en **acordeón** (ajuste del 26/10: uno abierto a la vez, el primero por omisión) · D10 **con contador** · D11 **PR propio**.

## Qué se hizo (B1–B3)

```
 Conversaciones
 ├─ Todas las Conversaciones
 ├─ Menciones
 ├─ No Atendidas
 ├─ ⇅ Ordenar bandejas…          ← abre el modal
 ├─ ▾ WhatsApp (3)                ← abierto: el primero por omisión
 │    ├─ Ventas MX · Soporte · Cobranza
 ├─ ▸ Telegram (1)                 ← los demás cerrados (acordeón)
 ├─ ▸ Correo (2)
 ├─ ▸ Meta (Messenger e Instagram) (2)
 └─ ▸ … Sitio web, TikTok, Otros canales
```

- **Grupos por tipo** en lugar de la carpeta única «Bandejas de entrada». Orden por omisión:
  WhatsApp → Telegram → Correo → Meta → Sitio web → TikTok → Otros canales. Los grupos vacíos no salen;
  dentro de cada grupo, las bandejas siguen por nombre.
- **«Ordenar bandejas…»** justo debajo de «No Atendidas»: modal para arrastrar o usar ▲▼, con
  «Restablecer» y el número de bandejas de cada grupo.
- **Acordeón:** solo un grupo abierto a la vez. Al entrar está abierto el primero; abrir otro cierra
  el anterior, y tocar el abierto lo cierra. Al entrar a una bandeja se abre su grupo.
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
- **Acordeón:** `Secondary.vue` guarda cuál está abierto (`openInboxGroup`: `''` = el primero, `null` =
  ninguno); las reglas viven en `resolveOpenGroup` y `toggleOpenGroup` del helper. No se guarda entre recargas.

## Pruebas

- Vitest `helper/specs/inboxGroups.spec.js` (23): cada tipo de canal, Twilio WhatsApp/SMS, normalizar
  el orden, orden por cuenta, agrupado por omisión y a la medida, orden por nombre, sin bandejas y el acordeón.
- Vitest `sidebarComponents/specs/InboxGroupsOrderModal.spec.js` (5): copia del orden, subir/bajar y
  bordes, restablecer, guardar, textos y contador.
- Pruebas existentes del menú: 53/53. Eslint sin avisos nuevos (los 24 de `Secondary.vue` ya venían de develop).
- Backend: `profiles#update` acepta el orden anidado por cuenta en `ui_settings` (verificado).
- ⚠️ Falta probarlo en el navegador.

## Ajustes posteriores (26/10/2026)

- **Título «Bandejas de entrada»** después de «Ordenar bandejas…»; los grupos cuelgan de él (un poco adentro).
- **Etiquetas con «Mostrar más»:** la lista muestra las primeras **10**; abajo, «Mostrar más (N)» /
  «Mostrar menos», con el mismo estilo que «Nueva etiqueta». La etiqueta abierta se ve siempre
  aunque esté más abajo. Igual en «Etiquetado con» del menú de Contactos.
  Es genérico: cualquier sección con `childLimit: N` en `Secondary.vue` lo usa
  (`SecondaryNavItem.vue`: `hasChildLimit`, `shownChildren`, `hiddenChildrenCount`).
