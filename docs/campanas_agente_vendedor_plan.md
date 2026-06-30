# Plan — Módulo Campañas con Agente Vendedor IA (MVP)

> **Estado:** PLAN consolidado (solo revisión, sin implementar). Rama `fix/bulk_tracking`.
> **Origen:** spec funcional del usuario, consolidada y aterrizada sobre el módulo
> existente de **Contact Tracking (Seguimientos IA)** + **Kanban (Oportunidades)**.

---

## 0. La idea en una frase

No es un sistema de **envíos masivos**. Es desplegar un **Agente Vendedor IA** sobre un
**segmento de prospectos** y convertir las conversaciones en **oportunidades de venta**,
con un tablero que responde 3 preguntas todos los días:

```
1. ¿Cómo va mi campaña?      → Dashboard Ejecutivo (KPIs + embudo)
2. ¿Dónde está el dinero?    → Resultados comerciales (valor generado)
3. ¿A quién llamar primero?  → Cola de trabajo del vendedor (orden automático)
```

---

## 1. Sobre qué se apoya (reuso) vs qué es nuevo

| Concepto del spec | En el código hoy | Acción |
|---|---|---|
| "Entrenamiento del Agente" | **`tracking_template`** (= "Agente IA") | ✅ reusar |
| "Asignar a lista de prospectos" | **bulk assign** (`Contacts::FilterService`, límite 30) | ✅ reusar / subir límite |
| "El Agente conversa con cada prospecto" | `ContactTrackingJob` + RouterService (intención) | ✅ reusar |
| "Prospecto de la campaña" | `ContactTracking` (1 activo por contacto+inbox) | ⭐ extender |
| "Oportunidad / cotización / demo" | **Kanban** (`kanban_process`) + `case_tickets` | ✅ enlazar |
| Señales: intención, sentimiento, resultado | `last_intent`, `last_sentiment_analysis`, `outcome` | ✅ reusar |
| **Score, Interés, Valor, Prioridad, Resultado, Vendedor, Siguiente acción** | — | 🆕 nuevo |
| Agrupar todo en una "Campaña" medible | — | 🆕 nuevo (`SalesCampaign`) |
| Dashboard KPIs + embudo + listas | patrón `contactTrackings/Dashboard.vue` | ✅ extender |

> ⚠️ **No reusar el `Campaign` nativo** de Chatwoot (es de envíos one_off/ongoing).
> El módulo nuevo se llama **`SalesCampaign`** ("Campaña de Agente Vendedor") para no chocar.

---

## 2. Modelo de datos (nuevo)

```
sales_campaigns                         sales_campaign_prospects
──────────────────────────────         ─────────────────────────────────────────
account_id            FK                sales_campaign_id     FK
name                  "Reactivación Q3" contact_id            FK
tracking_template_id  FK (entrenamiento)contact_tracking_id   FK (la conversación IA)
objective             enum (cotizar/    assignee_id           FK users (vendedor)
                       agendar/vender…)  status               enum (pendiente/conversando/
inbox_id              FK (canal)                               escalado/objetivo/sin_respuesta/
status                enum (draft/                              no_interesado)
                       running/paused/   interest              enum (alto/medio/bajo)
                       finished)         score                 integer (0-100, IA)
starts_at / ends_at   datetime          priority              enum (alta/media/baja)
                                         result                enum (cotizacion/pedido/demo/
                                                                oportunidad/venta/ninguno)
                                         value_generated       decimal
                                         next_action           string
                                         kanban_process_id     FK (oportunidad, opcional)
                                         last_interaction_at   datetime
```

- **`sales_campaign_prospects`** = la fila de la "Vista 3". Cada prospecto enlaza su
  `contact_tracking` (la conversación IA real) y, si aplica, su oportunidad en el Kanban.
- **`score`, `priority`, `next_action`, `result`** los calcula/actualiza la IA y los
  eventos de la conversación (extiende el analyzer que ya ajusta seguimientos).
- Migraciones SIEMPRE al final (convención del repo).

---

## 3. Flujo general (los 7 pasos)

```
1 Crear campaña ─▶ 2 Elegir Entrenamiento (tracking_template)
        │
        ▼
3 Seleccionar contactos (bulk: filtro + selección manual)
        │
        ▼
4 Iniciar ─▶ crea 1 ContactTracking por prospecto (respeta 1-activo-por-inbox)
        │
        ▼
5 El Agente conversa (ContactTrackingJob + Router) ─▶ actualiza score/interés/resultado
        │
        ▼
6 El sistema mide (KPIs, embudo, valor) ◀── eventos de conversación + outcome
        │
        ▼
7 El usuario decide (dashboards + cola del vendedor)
```

---

## 4. Las 7 vistas (consolidadas)

### Vista 1 · Listado de campañas  → *"¿qué campañas tengo y cuál va mejor?"*
Tabla: nombre · entrenamiento · objetivo · estado · prospectos · respondieron ·
objetivos cumplidos · valor generado · inicio · fin.
**Acciones:** crear · duplicar · pausar · reanudar · finalizar · ver detalle.

### Vista 2 · Dashboard Ejecutivo  → *"¿cómo va mi campaña?"* (en < 10 s)
Tarjetas: prospectos asignados · respondieron · **tasa de respuesta** · objetivos
cumplidos · **autonomía del agente** · escalados a vendedor · **valor generado** ·
pendientes. **+ Embudo:**
```
1000 Prospectos → 640 Respondieron → 390 Conversaciones útiles
   → 180 Cotizaciones → 95 Oportunidades → 42 Ventas
```
Top resultados: cotizaciones · pedidos · demos agendadas · oportunidades.

### Vista 3 · Prospectos de la campaña  → la más usada por ventas
Tabla: nombre · empresa · teléfono · estado · interés · **score** · prioridad ·
resultado · siguiente acción · valor · última interacción · vendedor.
**Filtros:** alta prioridad / objetivo cumplido / escalados / sin respuesta /
conversando / cotizaciones / pedidos / no interesados / buscar.
**Orden:** score · valor · última interacción.
**Acciones:** abrir conversación · abrir CRM · asignar vendedor · cambiar prioridad ·
marcar atendido.

### Vista 4 · Cola de trabajo del vendedor  → *"¿a quién llamo primero?"*
Lista priorizada automática por: **1) score · 2) valor generado · 3) tiempo sin atención.**
El vendedor no decide; el sistema decide por él.

### Vista 5 · Resultados comerciales  → *"¿dónde está el dinero?"*
Cotizaciones · pedidos · valor cotizado · valor vendido · ticket promedio · conversión
· objetivos logrados. **Gráfica:** valor generado por día.

### Vista 6 · Rendimiento del entrenamiento  → comparar campañas/entrenamientos
```
Evento IA        38% resp · 14% conv
Página Web       46% resp · 19% conv
Clientes Inactivos 31% resp · 8% conv
```
Descubre qué `tracking_template` (entrenamiento) convierte mejor.

### Vista 7 · Detalle del prospecto
Info CRM → Resumen IA → Resultado → Score → Prioridad → Siguiente acción.
Botones: abrir conversación · abrir oportunidad (Kanban) · abrir cotización · asignar vendedor.

---

## 5. KPIs (fórmulas del spec)

```
Tasa de respuesta        = respondieron / asignados
Conversión               = objetivos cumplidos / asignados
Conversión s/ interesados= objetivos cumplidos / respondieron
Autonomía                = conversaciones resueltas por IA / respondidas
Valor generado           = Σ (cotizaciones + pedidos + oportunidades + ventas)
Score promedio           = promedio del score IA de los prospectos
Tiempo prom. de respuesta= 1er mensaje → 1ª respuesta
```

---

## 6. Arquitectura (cómo se conecta a lo existente)

```
┌──────────────── Módulo Campañas (Agente Vendedor) — NUEVO ────────────────┐
│  SalesCampaign ── tracking_template (Entrenamiento)                         │
│       │                                                                     │
│       │ iniciar → bulk assign (reusa Contacts::FilterService)               │
│       ▼                                                                     │
│  SalesCampaignProspect ──▶ ContactTracking ──▶ ContactTrackingJob (IA)      │
│       │  score/interés/resultado/valor          (RouterService, WhatsApp)   │
│       │        ▲                                                            │
│       │        └── analyzer de conversación (extiende el actual)            │
│       ▼                                                                     │
│  Dashboards (KPIs, embudo, cola vendedor)  ── enlaza ──▶ Kanban / Tickets   │
└────────────────────────────────────────────────────────────────────────────┘
        reusa: tracking_template · bulk assign · ContactTrackingJob · dashboard pattern
        nuevo:  SalesCampaign + Prospect + capa comercial (score/valor/prioridad) + 7 vistas
```

---

## 7. Fases (MVP incremental)

```
F1  Modelo: SalesCampaign + SalesCampaignProspect (+ migraciones, CRUD admin)
F2  Crear campaña: wizard (entrenamiento + objetivo + selección de contactos vía bulk)
F3  Iniciar: genera ContactTrackings; el Agente ya conversa (reuso total)
F4  Capa comercial: analyzer setea score/interés/resultado/valor por conversación
F5  Vista 1 (listado) + Vista 3 (prospectos) con filtros/orden/acciones
F6  Vista 2 (Dashboard Ejecutivo) + embudo + KPIs
F7  Vista 4 (cola vendedor) + Vista 5 (resultados $) + Vista 6 (rendimiento)
F8  Vista 7 (detalle) + enlaces a Kanban/cotización/CRM
```

> **Relación con `fix/bulk_tracking`:** la asignación de prospectos a la campaña ES el
> bulk tracking. La mejora natural de bulk (selección + límite + preview) es el F2 de este plan.

---

## 8. Decisiones abiertas (a confirmar antes de implementar)

1. **Objetivo de campaña**: ¿enum fijo (cotizar/agendar demo/vender/reactivar) o libre?
2. **Score IA**: ¿qué lo alimenta? (intención + sentimiento + señales de compra del LLM).
   ¿Se recalcula por mensaje o al cerrar la conversación?
3. **"Valor generado"**: ¿lo declara el vendedor, lo infiere la IA del texto, o viene del
   ERP/cotización? (se puede enlazar al módulo Cobranza/ERP a futuro).
4. **Oportunidad**: ¿crear automáticamente una tarjeta en el **Kanban** al detectar interés alto?
5. **Límite de prospectos**: hoy bulk = 30. Para campañas reales subir (¿200? ¿sin límite con cola?).
6. **"Resuelto por IA" (autonomía)**: criterio (sin escalado a humano y con outcome positivo).
7. **Multicanal**: 1 tracking activo por (contacto, inbox) — ¿una campaña fija su inbox?
```
```
