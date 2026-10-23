# Plan — Reacomodo del menú (menú v2)

> Estado: ✅ **F1 + F2 hechas** (2026-10-23, rama `feat/nva_oportunidad`). Prototipo visual:
> artifact «Nuevo menú Wintook».

## Qué cambió
Menú principal por lo que hace la gente: **Inicio · Conversaciones · Ventas · Servicio · Agenda ·
Clientes · Agentes IA · Informes · Centro de ayuda · Ajustes**.

| Entrada | Submenú | Sale de |
|---|---|---|
| Inicio | Mi resumen · Mis avisos · Mi negocio (visibleGetter) | Inicio, notificaciones, Resumen del negocio |
| Conversaciones | lo de antes + Vista de bandeja | Conversaciones + Vista de bandeja |
| Ventas | Embudo de contactos (+ lista de embudos) · Oportunidades · Embudo de oportunidades · Métricas de ventas | Tableros de conversaciones + Casos Comercial |
| Servicio | Casos · Tablero · Métricas (clase actual o última no Comercial) | Casos Soporte/OT/Proyecto |
| Agenda | Tareas · Calendario | Casos › Tareas + Google Calendar |
| Clientes | lo de Contactos | Contactos |
| Agentes IA | lo de antes + Asistente (Capitán) | Agente IA campañas + Capitán |
| Ajustes | lo de Configuración + Embudos de contactos + grupo «Casos y etapas» | Configuración + config de Casos |

## Cómo está hecho (y cómo regresarlo)
- Archivos nuevos: `components/layout/config/sidebarItems/v2/index.js` (+ `index.spec.js`). Reusa y
  reparte los menús de antes; **no los modifica**.
- **Interruptor**: `MENU_V2` en `components/layout/config/default-sidebar.js`. En `false` vuelve el
  menú anterior tal cual.
- Respaldos `_20261023m`: `Sidebar.vue`, `Secondary.vue`, `default-sidebar.js`, `es|en/settings.json`.
- `Sidebar.vue`: `matches(route)` para elegir menú por la clase de la ruta, `alternatives` en el menú
  principal (Agenda sin casos → Calendario; Agentes IA sin campañas → Capitán). `Secondary.vue`:
  `extraSections` (Ventas usa la sección dinámica de embudos).
- Ninguna ruta cambió. Textos nuevos con claves nuevas (`SIDEBAR.SALES`, `SETTINGS_V2`, …) para no
  tocar los del menú anterior.

## Reglas finas
- El menú principal marca activo por prefijo de dirección: Servicio apunta a
  `tickets/<clase>/list`, no a `tickets` (si no, se marca también en Ventas).
- El detalle de un caso (`tickets/:id`) no trae la clase: usa la última clase visitada.

## Pendiente (siguientes fases)
- F3: botón «+ Nuevo» y contadores en el menú. F5: Ctrl K con casos/tareas.
- Cotizaciones y Productos (módulo del sistema administrativo).
- Mover Automatizaciones a Agentes IA y Centro de ayuda a Ajustes (tienen su propio menú interno).
- «Agentes IA» también es el nombre de las plantillas de seguimiento dentro de Ajustes (renombrar).
