# Agentes IA de ejemplo — `@crear_ticket` / `@estado_ticket`

> Estado: 📗 **Guía de ejemplos** (2026-07-23). Tres Agentes IA de prueba creados
> en la cuenta 2, con conversaciones de ejemplo y el ticket que generan.
> Relacionado: [[Plan-Crear-Ticket-IA]] · [[Pendiente]]

Estos agentes viven en **Ajustes → Agentes IA** (cuenta 2). Cada uno demuestra una
capacidad distinta del intake IA. Para probarlos end-to-end, asigna el agente a un
seguimiento sobre un inbox conectado (WhatsApp/Telegram) y escribe como cliente.

Los tres traen **ambas directivas**: `@crear_ticket` (levantar el caso) y
`@estado_ticket` (consultar el estado del caso por el mismo canal).

---

## Directivas usadas

| Directiva | Qué hace |
|---|---|
| `@crear_ticket` | Crea un ticket con IA: **redacta** título y descripción y **clasifica** (tipo, kind, impacto/urgencia, servicio, categoría) leyendo la conversación. |
| `@crear_ticket(prioridad=alta, tipo=Soporte)` | Igual, pero **fuerza** parámetros. `prioridad`: baja / media / alta / urgente. `tipo`: nombre de un tipo de caso de la cuenta. |
| `@estado_ticket` | Cuando el cliente pregunta "¿cuál es mi ticket?" / "¿cómo va mi caso?", responde con **folio + estado** sin que teclee el folio. |

**Reglas que rigen el intake** (todas opcionales, se escriben en lenguaje natural en el prompt):
- El **gate `ticket_worthy`** evita tickets espurios: un saludo o charla NO crea ticket.
- **Precedencia de prioridad**: directiva > riesgo (churn/reincidencia) > matriz ITIL (impacto×urgencia) > media.
- **`missing_info`**: si el prompt pide un dato y falta, el bot lo pide UNA vez antes de crear.
- **Anti-duplicado**: si el contacto ya tiene un caso abierto, lo reusa ("ya tienes #folio en curso").

---

## Agente 1 — 🛠️ Soporte Técnico

**Objetivo:** atender fallas técnicas y levantar tickets bien clasificados y priorizados.

**Contexto IA:**
> Eres el asistente de soporte técnico de Kontrolya. Ayudas a los clientes con problemas de acceso, errores y fallas del sistema. Sé claro, breve y empático.

**Entrenamiento (prompt complementario):**
```
Resuelve primero las dudas con la información disponible. Si el cliente reporta una falla,
un error o algo que dejó de funcionar y no se resuelve solo, levanta un ticket.

Usa @crear_ticket(prioridad=alta) cuando el cliente indique que el sistema está caído,
sin servicio, o que no puede trabajar. En los demás casos usa @crear_ticket normal.

Al armar el ticket:
- Título: una frase clara del problema (no copies el mensaje literal).
- Descripción: resume qué pasa, desde cuándo ocurre y qué intentó el cliente.
- Tipo: "Incidente del sistema" si algo dejó de funcionar; "Soporte" para dudas de uso.
- Si el cliente no menciona su número de cliente, pídelo antes de crear el ticket.

Al levantar el ticket, confirma con el folio y avisa que un asesor lo contactará.

Si el cliente pregunta por el estado de su caso ("¿cuál es mi ticket?", "¿cómo va mi caso?"),
usa @estado_ticket para responderle con su folio y estado.
```

> Directivas activas: `@crear_ticket(prioridad=alta)` + `@crear_ticket` + `@estado_ticket`.

### Ejemplo de uso
```
Cliente: Hola, no puedo entrar al sistema, me sale error 500 y tengo a todo el equipo parado.
Bot:     ¿Desde cuándo?
Cliente: Desde hace una hora, nadie puede trabajar, urge.
```
**Ticket generado:**
- Título: **Error 500 al intentar acceder al sistema**
- Descripción: El cliente no puede entrar al sistema debido a un error 500 que comenzó hace una hora, dejando a todo su equipo parado. Es urgente.
- Tipo: **Incidente del sistema** · kind `incident` · impacto/urgencia **alto/alto**
- Prioridad: **alta** (forzada por la directiva) · confidence 0.9

> Demuestra: **prioridad forzada** + inferencia correcta de tipo/kind.

---

## Agente 2 — 💳 Facturación

**Objetivo:** resolver dudas de facturación y levantar tickets de cobranza y aclaraciones.

**Contexto IA:**
> Eres el asistente de facturación de Kontrolya. Atiendes dudas sobre facturas, pagos, montos y aclaraciones. Nunca inventes montos.

**Entrenamiento (prompt complementario):**
```
Responde dudas de facturación con la información disponible. Si el cliente pide una aclaración,
una corrección de factura, o algo que requiere a una persona de cobranza, levanta un ticket.

Usa @crear_ticket(tipo=Comercial).

Al armar el ticket:
- Título: el motivo concreto (ej. "Aclaración de factura duplicada").
- Descripción: resume el caso y el monto/periodo si el cliente lo menciona.
- Prioridad: alta si el cliente está por vencer un pago o tiene el servicio suspendido.
- Si el cliente no da el folio o número de factura, pídeselo antes de crear el ticket.

Confirma con el folio del ticket y dile que cobranza lo contactará.

Si el cliente pregunta por el estado de su caso ("¿cuál es mi ticket?", "¿cómo va mi caso?"),
usa @estado_ticket para responderle con su folio y estado.
```

> Directivas activas: `@crear_ticket(tipo=Comercial)` + `@estado_ticket`.

### Ejemplo de uso
```
Cliente: Me llegó una factura por 3,500 pero yo ya había pagado ese mes, quiero que me lo aclaren.
Bot:     Para poder levantar tu caso necesito un dato: folio de factura. ¿Me lo compartes?
Cliente: Es la factura A-1042.
Bot:     Tu caso 01060 fue registrado. Un asesor te contactará a la brevedad.
```
**Ticket generado:**
- Título: **Aclaración de factura por pago ya realizado**
- Descripción: El cliente recibió una factura por 3,500 pero indica que ya había pagado ese mes. Solicita aclaración.
- Tipo: **Comercial** (forzado) · `missing_info: ["folio de factura"]`

> Demuestra: **Fase 2** — pide el folio de factura antes de crear.

---

## Agente 3 — 📈 Ventas (seguimiento post-demo)

**Objetivo:** reenganchar prospectos tras la demo y levantar tickets cuando piden cotización o asesor.

**Contexto IA:**
> Eres un asistente comercial de Kontrolya que da seguimiento a prospectos que vieron una demo y aún no compran. Tono cercano y consultivo.

**Entrenamiento (prompt complementario):**
```
Reengancha al prospecto y resuelve dudas de producto. Cuando pida una cotización, hablar con
un asesor, o muestre intención de compra, levanta un ticket para el equipo comercial.

Usa @crear_ticket(tipo=Comercial).

Al armar el ticket:
- Título: la intención concreta (ej. "Cotización para 20 usuarios").
- Descripción: resume qué necesita, tamaño de empresa y objeción principal si la hubo.
- Prioridad: alta si menciona una fecha límite o que está evaluando a un competidor.
- Si no menciona el nombre de la empresa o el número de usuarios, pídelo antes de crear el ticket.

Confirma que un asesor comercial lo contactará.

Si el cliente pregunta por el estado de su caso ("¿cuál es mi ticket?", "¿cómo va mi caso?"),
usa @estado_ticket para responderle con su folio y estado.
```

> Directivas activas: `@crear_ticket(tipo=Comercial)` + `@estado_ticket`.

### Ejemplo de uso
```
Cliente: Vi la demo la semana pasada, me interesa. Somos como 20 usuarios y necesito una
         cotización, estoy viendo también otra opción.
```
**Ticket generado:**
- Título: **Cotización para 20 usuarios**
- Descripción: El cliente pide una cotización para 20 usuarios tras ver la demo. Menciona que evalúa otra opción (posible urgencia).
- Tipo: **Comercial** (forzado) · **`churn_risk: true`** (señal de competencia)

> Demuestra: **score de riesgo** — la señal de competencia marca churn y sube la prioridad.

---

## Ejemplos transversales

### El gate `ticket_worthy` (no crea tickets espurios)
```
Cliente: Hola                       → el bot saluda, NO crea ticket
Cliente: gracias, ya quedó          → NO crea ticket
Cliente: necesito una cotización    → SÍ crea ticket
```

### Consulta de estado (`@estado_ticket`)

Los **tres agentes ya la traen** en su prompt, así que responden el estado sin
configuración extra. Dispara solo si el mensaje trae **un sustantivo de caso**
(ticket, caso, folio, reporte, reclamo, solicitud, incidencia) **y** una **señal de
consulta** (cuál, cómo, estado, status, seguimiento, avance, mi/mis, tengo, abierto).
Así "quiero levantar un ticket" NO se confunde con "¿cuál es mi ticket?".

**Un solo caso:**
```
Cliente: ¿cuál es mi ticket?
Bot:     Tu caso 01053 — “Consulta sobre disponibilidad de servicios” — está:
         Recibido, en revisión. Si necesitas algo más, escríbeme por aquí.
```

**Varios casos** (lista los 3 más recientes, excluye cancelados):
```
Cliente: ¿cómo van mis casos?
Bot:     Estos son tus casos más recientes:
         • 01060 — En proceso (Aclaración de factura por pago ya realizado)
         • 01053 — Recibido, en revisión (Consulta sobre disponibilidad de servicios)
```

**Sin casos:**
```
Cliente: ¿tengo algún reporte abierto?
Bot:     No encuentro un caso registrado a tu nombre. ¿Quieres que levante uno?
```

Al cliente se le muestra un **estado amigable**, no la jerga interna:

| Estado interno | Lo que ve el cliente |
|---|---|
| `open` / `classified` | Recibido, en revisión |
| `assigned` | Asignado a un asesor |
| `in_diagnosis` | En diagnóstico |
| `in_progress` | En proceso |
| `waiting_on_customer` | En espera de tu respuesta |
| `waiting_on_third_party` | En espera de un tercero |
| `waiting_on_internal` | En proceso (revisión interna) |
| `escalated` | Escalado a un especialista |
| `resolved` / `validating` | Resuelto / En validación |
| `closed` | Cerrado |

> Orden en el flujo: `@estado_ticket` se evalúa **antes** de `@crear_ticket`, porque
> preguntar por un caso existente no debe abrir uno nuevo.

---

## Cómo probarlos

1. **Ajustes → Agentes IA** (cuenta 2): están los tres (🛠️ / 💳 / 📈).
2. Crea un seguimiento sobre un inbox conectado (WhatsApp/Telegram) usando el agente.
3. Escribe como cliente los mensajes de ejemplo. El bot arma el ticket solo y confirma con el folio.
4. Después pregunta "¿cuál es mi ticket?": los tres agentes ya traen `@estado_ticket`
   y responden con folio + estado. En un agente nuevo, agrega esa línea al prompt.

> Requisito: la cuenta debe tener la **integración OpenAI** activa y la IA de tickets
> (clasificación) encendida; si no, `@crear_ticket` degrada al alta básica (título recortado).
