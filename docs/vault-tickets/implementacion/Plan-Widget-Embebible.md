---
titulo: Plan — Widget embebible de tickets (launcher + iframe)
tipo: plan
tags: [tickets, osticket, user-portal, widget, sdk, plan]
fecha: 2026-07-21
estado: propuesta (no implementado)
---

# 🔌 Plan — Widget embebible de tickets (Opción B)

> Relacionado: [[Plan-User-Portal]] · [[Referencia-osTicket]] · [[Pendiente]]

## 1. Objetivo

Que el cliente pegue **dos líneas** en su web y obtenga una burbuja flotante que abre
el alta y la consulta de tickets, sin sacar al visitante de su sitio.

```html
<script src="https://mgci.tld/js/ticket_sdk.js"></script>
<script>window.mgciTickets.run({ slug: 'soporte' })</script>
```

**Decisión de arquitectura:** el launcher **no reimplementa el formulario**. Inyecta
un iframe que carga el **User Portal que ya existe**. Todo lo caro (campos
personalizados 2K, adjuntos, match de contacto por email/teléfono, acuse, creación de
la conversación) ya vive en `Public::CasePortalController` y `Cases::PortalTicketService`.
El widget es una **cáscara**, no un segundo producto.

## 2. Lo que ya está construido

| Pieza | Estado | Dónde |
|---|---|---|
| Portal HTML server-rendered | ✅ P1 implementado | `app/views/public/case_portal/*.erb` |
| Rutas públicas por slug | ✅ | `config/routes.rb:723-726` |
| Alta, consulta por folio, timeline público | ✅ | `case_portal_controller.rb` |
| Tabla `case_portals` (`slug` único, `custom_domain`, `enabled`) | ✅ | `db/schema.rb:317` |
| Patrón burbuja + iframe + CSS inline | ✅ reusable | `app/javascript/sdk/` |
| Nombre de bundle sin hash | ✅ mecanismo | `config/webpack/environment.js:62` |
| Launcher propio de tickets | ❌ | — |
| Control de qué dominios pueden embeber | ❌ | — |

## 3. Arquitectura

```
   Web del cliente (cliente.com)                    MGCI (mgci.tld)
 ┌───────────────────────────────────┐
 │ <script src=…/js/ticket_sdk.js>   │──── GET ────▶ pack webpack
 │ mgciTickets.run({slug:'soporte'}) │               (nombre estable)
 │                                   │
 │   inyecta CSS inline + DOM        │
 │   ┌─────────────────────────┐     │
 │   │ .mgci-ticket-bubble  🎫 │     │
 │   └─────────────────────────┘     │
 │              │ click              │
 │              ▼                    │
 │   ┌─────────────────────────┐     │
 │   │ .mgci-ticket-holder     │     │
 │   │ ┌─────────────────────┐ │     │
 │   │ │ <iframe>            │ │────▶ GET /portal/soporte/new?embed=1
 │   │ │  Nuevo ticket       │ │     │      (vistas ya existentes,
 │   │ │  Consultar folio    │ │     │       layout 'case_portal' en
 │   │ │                     │ │     │       variante compacta)
 │   │ └─────────────────────┘ │     │
 │   └─────────────────────────┘     │
 │              ▲                    │
 │              └── postMessage ─────┼──── altura, cerrar, ticket creado
 └───────────────────────────────────┘
```

Sin cookies, sin identidad, sin websockets. El visitante es **guest**, igual que en el
portal. Eso mantiene el launcher en un orden de magnitud menos de código que
`packs/sdk.js` (que arrastra `js-cookie`, hashing de usuario y ~15 métodos de API).

## 4. Contrato del snippet

```js
window.mgciTickets.run({
  slug:      'soporte',          // requerido — resuelve el portal
  baseUrl:   'https://mgci.tld', // opcional — se infiere del <script src>
  position:  'right',            // 'right' | 'left'
  color:     '#1f93ff',
  launcherTitle: 'Soporte',
  view:      'new',              // 'new' | 'status' — pestaña inicial
  locale:    'es',
  hideBubble: false,             // para lanzar desde un botón propio
});

// API mínima, para que el cliente lo dispare desde su propio botón:
window.mgciTickets.toggle();     // abre/cierra
window.mgciTickets.open('status');
window.mgciTickets.close();
```

## 5. Cambios por archivo

### 5.1 Nuevo pack + launcher

**`app/javascript/packs/ticket_sdk.js`** — entrada; expone `window.mgciTickets.run`.
Calca la forma de `packs/sdk.js` pero sin cookies ni `setUser`.

**`app/javascript/ticket_sdk/`** — módulo nuevo, hermano de `sdk/`:
```
ticket_sdk/
├── launcher.js     bubble + holder, abrir/cerrar
├── frame.js        crea el iframe, arma la URL, escucha postMessage
├── styles.js       CSS como string (patrón SDK_CSS + loadCSS)
└── constants.js    eventos postMessage
```

> **Trampa a evitar:** `config/webpack/environment.js:62` define
> `preserveNameFor = ['sdk', 'worker']`; todo lo demás sale como
> `js/[name]-[hash].js`. Si no se añade `'ticket_sdk'` a ese array, la URL del
> snippet cambia en cada build y el cliente queda roto. **Es un cambio de una
> palabra y es el que más fácil se olvida.**

### 5.2 Modo embed en el portal

**`app/controllers/public/case_portal_controller.rb`** — detectar `params[:embed]`
y exponer `@embed` al layout. Ninguna lógica de negocio cambia.

**`app/views/layouts/case_portal.html.erb`** — en modo embed: sin header grande, sin
footer, márgenes compactos, y un `<script>` que publica al padre:
- altura del documento al cargar y en cada cambio (auto-resize),
- `ticket-created` con el folio tras `#create`,
- `close` desde un botón ✕.

**Vistas `new`/`status`** — un conmutador de pestañas dentro del iframe para que el
widget tenga las dos acciones sin navegación externa.

### 5.3 Seguridad de embebido

**`config/application.rb:58`** hoy pone `X-Frame-Options: ALLOWALL` **global**:

```ruby
# Adiciona cabeçalho para permitir iframes
config.action_dispatch.default_headers = { 'X-Frame-Options' => 'ALLOWALL' }
```

Esto permite que **cualquier** sitio enmarque **cualquier** página de la instancia,
incluido el dashboard de agentes → riesgo de clickjacking. El plan lo corrige:

1. Quitar ese default global.
2. En `Public::CasePortalController`, emitir
   `Content-Security-Policy: frame-ancestors <dominios del portal>` solo en las
   rutas públicas del portal.
3. Columna nueva `case_portals.allowed_origins` (text[] o jsonb) — lista de
   dominios donde ese portal puede embeberse. Vacío = solo el propio dominio.
4. UI en el ajuste del portal (dashboard) para editar esa lista + mostrar el
   snippet listo para copiar.

> Es una corrección de seguridad **independiente del widget**, pero el widget la
> vuelve inevitable: sin lista de orígenes no hay forma de acotar el embebido.

### 5.4 Anti-abuso del POST público

El alta ya es pública hoy (`POST /portal/:slug/tickets`), pero el widget la vuelve
mucho más fácil de encontrar y automatizar. Mínimo:
- **rate limit por IP** (`rack-attack` ya está en el stack de Chatwoot),
- **honeypot** oculto en el form,
- validar `Origin` contra `allowed_origins` en el `create`.

Captcha queda fuera del MVP (fricción alta para soporte legítimo).

## 6. Protocolo postMessage

```
iframe (portal)                          launcher (web del cliente)
 ─────────────────────────────────────────────────────────────────
 {type:'mgci:resize', height:640}   ───▶  ajusta alto del holder
 {type:'mgci:created', folio:'01018'} ─▶  callback opcional onCreated
 {type:'mgci:close'}                ───▶  cierra el panel
                              ◀───  {type:'mgci:view', view:'status'}
```

Validar `event.origin` contra `baseUrl` en ambos extremos — sin eso, cualquier
iframe de la página puede redimensionar o cerrar el widget.

## 7. Fases

```
 P1 — Embebible mínimo  ← corte útil
   1. modo ?embed=1 + layout compacto
   2. pack ticket_sdk + 'ticket_sdk' en preserveNameFor
   3. burbuja + panel iframe + auto-resize
   4. pestañas Nuevo / Consultar dentro del iframe

 P2 — Seguridad (no opcional para producción)
   5. quitar ALLOWALL global
   6. allowed_origins + frame-ancestors por portal
   7. rate limit + honeypot + validación de Origin

 P3 — Comodidad
   8. generador de snippet en el ajuste del portal (copiar/pegar)
   9. callbacks (onCreated), open/close programático
  10. prefill: mgciTickets.run({ prefill:{ email, name } })
```

**P1 y P2 se despliegan juntos.** Publicar P1 solo sería exponer un alta pública
más fácil de abusar sin haber cerrado el `ALLOWALL`.

## 8. Verificación

- **Página de prueba** fuera de la app (archivo estático servido en otro puerto) con
  el snippet → burbuja visible, panel abre, alta crea ticket real con folio.
- **Auto-resize**: el panel crece al mostrar errores de validación sin scroll doble.
- **Aislamiento CSS**: probar sobre una página con CSS agresivo (Bootstrap/Tailwind
  reset) — el iframe protege el contenido, pero **la burbuja vive en el DOM del
  cliente**; prefijar todo con `.mgci-` y fijar `all: initial` en el holder.
- **frame-ancestors**: desde un dominio NO listado, el iframe debe ser bloqueado por
  el navegador; desde uno listado, cargar.
- **Regresión**: el portal directo (`/portal/:slug`, sin `embed`) se ve igual que hoy.
- Móvil: panel a pantalla completa por debajo de ~480px.

## 9. Riesgos

| Riesgo | Mitigación |
|---|---|
| Quitar `ALLOWALL` rompe otro embebido en uso hoy | **Investigado (2026-07-21): riesgo bajo.** Viene del commit `fd22446c` (nestordavalos, 2024-06-19), heredado del fork upstream — comentario en portugués, anterior al módulo de tickets, sin relación con MGCI. Los dos embebidos legítimos (`widgets_controller.rb:73` y `portals/base_controller.rb:57`) **borran la cabecera ellos mismos**, así que no dependen del default global. Aun así: retirada gradual a `SAMEORIGIN` y observar logs (`Sec-Fetch-Dest: iframe`, `Referer` externo) antes de eliminarlo. |
| El bundle sale con hash y el snippet muere | `preserveNameFor` — verificar el nombre del archivo en el build, no asumirlo |
| CSS del cliente deforma la burbuja | Prefijo `.mgci-` + `all: initial` + z-index alto |
| Spam de tickets | P2 completo antes de producción |
| Confusión con el widget de chat de Chatwoot | Nombre, color e icono distintos; documentar que pueden convivir (son dos scripts independientes) |

## 10. Lo que este plan NO hace

- No crea una API pública de tickets (eso era la Opción C).
- No permite al cliente diseñar su propio formulario.
- No autentica al visitante; sigue siendo guest + folio, como osTicket.
- No toca el widget de chat existente de Chatwoot.
