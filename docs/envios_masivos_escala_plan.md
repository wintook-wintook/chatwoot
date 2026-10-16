# Envíos masivos a escala — diagnóstico y plan

Rama: `diag/envios_masivos` · Fecha: 16/10/2026 · Estado: **solo plan, nada implementado**

Objetivo: que las campañas del Agente IA (TrackingCampaign → ContactTracking) aguanten
**1 000 cuentas con varias campañas masivas cada una**, y que sigan aguantando cuando crezcan
las cuentas y los mensajes por entregar.

Referencia comparada: `/opt/wacrm` (Next.js + Supabase). wacrm **no declara capacidad ni
requisitos de servidor**; solo trae topes fijos en código (10 msg/s desde la pantalla, 1 000
destinatarios por petición a la API, 5 lanzamientos/min por usuario). Sirve como ejemplo de
dos ideas (ritmo controlado y registro por destinatario), no como medida de capacidad.

---

## 1. Cómo funciona hoy

```
 Lanzar campaña
     │
     ▼
 BulkAssignJob (cola medium)                      tope: 100 contactos (MAX_BULK_ASSIGN)
     │  por contacto: Enroll → TrackingBuilder
     │     · crea conversación + nota privada
     │     · ContactTracking.insert!
     │     · ContactTrackingJob.set(wait_until: send_at)   ◄── 1 job programado en Redis
     ▼
 ┌──────────── a la hora send_at (todos iguales) ────────────┐
 │ ContactTrackingJob (cola scheduled_jobs)                   │
 │   with_lock (transacción abierta) ─┐                       │
 │      ├ ¿ventana 24 h?              │ la fila queda         │
 │      ├ OpenAI (si ventana abierta) │ bloqueada y la        │
 │      ├ Meta /messages (HTTP)       │ conexión a la BD      │
 │      └ crea Message (callbacks)    │ ocupada todo el rato  │
 │   fin del lock ────────────────────┘                       │
 └────────────────────────────────────────────────────────────┘
     ▲
     │ ADEMÁS, cada minuto:
 ExecutePendingJob (cron */1) → vuelve a encolar TODO lo vencido de TODAS las cuentas

 Meta ──webhooks──► WhatsappEventsJob (cola low): sent / delivered / read por mensaje
```

### Lo que medí en el código

| # | Hallazgo | Dónde | Efecto a escala |
|---|---|---|---|
| H1 | Los envíos van en `scheduled_jobs`, **por debajo de `low`** en la prioridad estricta de Sidekiq ("las colas bajas solo corren si las altas están vacías") | `config/sidekiq.yml:18-30`, `contact_tracking_job.rb:11` | Cada envío produce 2–3 webhooks de estado que caen en `low` y **le ganan** a los envíos. Con mucho tráfico los envíos se quedan esperando sin fecha |
| H2 | Un solo proceso Sidekiq, concurrencia 10 por defecto, pool de BD = 10 | `config/sidekiq.yml:7`, `config/database.yml:7`, `.env:297` | Unos 10 envíos simultáneos en **todo** el sistema, compartidos con IA, webhooks, correos, etc. |
| H3 | La llamada a Meta y a OpenAI ocurre **dentro** de `with_lock` | `contact_tracking_job.rb:21-200` | Transacciones de varios segundos; una conexión a la BD ocupada por cada envío en curso; bloqueos largos |
| H4 | Todos los inscritos de una campaña reciben **la misma** `send_at` | `tracking_campaigns/schedule.rb:29` | Ráfaga: 100 (o 10 000) envíos piden salir en el mismo segundo |
| H5 | Doble encolado: job programado + cron cada minuto que encola todo lo vencido | `tracking_builder.rb:42`, `execute_pending_job.rb:37`, `config/schedule.yml:92` | Con 1 000 cuentas, decenas de miles de jobs duplicados por minuto; hoy los frena el lock y la espera de 60 s, pero cuestan Redis y BD |
| H6 | Un job programado por seguimiento en el ZSET de Redis (`wait_until`) | `tracking_builder.rb:42`, `contact_tracking.rb:561` | Millones de entradas en Redis con reintentos de días |
| H7 | No hay reparto justo entre cuentas | — | Una cuenta con una campaña enorme retrasa a todas las demás (vecino ruidoso) |
| H8 | No hay ritmo por número de WhatsApp | — | Se puede exceder la velocidad que acepta Meta por número → errores de límite |
| H9 | Un rechazo de Meta deja el seguimiento en `failed` con texto genérico, **sin reintento** ni código de error | `contact_tracking_job.rb:197` | No se distingue "número inválido" (definitivo) de "límite excedido" (pasajero) |
| H10 | Al rechazar, el canal hace `update!` sobre el mensaje temporal **sin guardar** → probablemente lo inserta | `contact_tracking_job.rb:578`, `whatsapp_cloud_service.rb:240` | Por confirmar: mensaje fallido de más o fallback con IA inesperado |
| H11 | La entrega de la campaña se mide con el **último mensaje** de la conversación | `tracking_campaigns_controller.rb:132-157` | Cifras mezcladas con mensajes posteriores y con otras campañas; además la consulta crece con el volumen |
| H12 | Cada mensaje saliente dispara callbacks (palabras clave, botseller, eventos, ActionCable, webhooks) | `message.rb:134-149` | Costo fijo por envío que se multiplica por el volumen |
| H13 | Tope de 100 contactos por campaña; el lote recorre contacto por contacto | `bulk_assign_service.rb:31,116` | No sirve para campañas grandes; si se sube sin cambiar el recorrido, el job dura horas |

---

## 2. Cuánto pesa: ejemplo con supuestos

> Son **supuestos para dimensionar**, no datos medidos. La F0 los reemplaza por datos reales.

```
1 000 cuentas × 2 campañas/día × 500 contactos = 1 000 000 envíos/día

Por cada envío:
  1 ContactTrackingJob (Meta ~0.5–1.5 s; con IA +2–6 s)
  1 Message + sus callbacks
  2–3 webhooks de estado (sent, delivered, read)  → ~3 000 000 jobs/día solo de estados
  ─────────────────────────────────────────────
  ≈ 4–5 jobs por envío → 4–5 millones de jobs/día

Si casi todo sale en horario de oficina (p. ej. 2 h pico por la mañana):
  1 000 000 / 7 200 s ≈ 140 envíos/s  →  ~600 jobs/s en el pico

Capacidad actual: ~10 jobs simultáneos × ~1 s = ~10 envíos/s (y compartidos)
→ faltan ~14× solo para los envíos, sin contar IA ni webhooks
```

Límites de Meta (**confirmar en la documentación vigente de Meta antes de usar cifras**):
- **Nivel de mensajería** por número o portafolio: contactos nuevos por 24 h (250 / 1k / 10k / 100k / ilimitado).
- **Velocidad** por número (mensajes por segundo), ampliable.
- Límite **por pareja** (mismo destinatario muchas veces seguidas).

Lo bueno: cada cuenta tiene **su propio** número y **su propia** llave de OpenAI, así que los
límites externos se reparten solos. **El cuello de botella es nuestro**: la cola, los workers, la BD.

### 2.1 Referencia oficial de Chatwoot

Versión en uso: **3.13.6** (`package.json:3`, `config/app.yml:2`). El sitio oficial muestra la
documentación vigente, no una por versión; las cifras de servidor casi no han cambiado.

| Servidor | Conversaciones/día (oficial) |
|---|---|
| 4 núcleos · 4 GB RAM | hasta 10 000 |
| 8 núcleos · 8 GB RAM | hasta 20 000 |
| Más | escalar horizontalmente (más servidores) |

- Mide **conversaciones/día**, no mensajes; son cifras de ejemplo, **no pruebas de carga**.
- Sidekiq activo puede pasar de 1 GB de RAM; recomienda Sidekiq en servidores separados de la web.
- Valores por defecto: `WEB_CONCURRENCY=0` (1 proceso web), `RAILS_MAX_THREADS=5`, `SIDEKIQ_CONCURRENCY=10`.
  El pool de la BD se calcula solo con esos valores.
- Son cifras de Chatwoot base. Esta instalación agrega seguimientos, IA, analizador y campañas
  por conversación → la capacidad real será **menor**.

Fuentes: [System Requirements](https://developers.chatwoot.com/self-hosted/deployment/requirements) ·
[Optimizing Configurations](https://developers.chatwoot.com/self-hosted/deployment/performance/optimizing-configurations)

### 2.2 Por qué los hilos de Sidekiq no alcanzan hoy

```
envíos por segundo  =  hilos trabajando a la vez  ÷  segundos que tarda cada envío

hoy:     10 hilos  ÷  ~1 s   ≈  10 envíos/s   (y esos 10 hilos se comparten con TODO)
meta:   140 envíos/s × ~1 s  ≈  140 hilos ocupados al mismo tiempo, solo en envíos
```

(~1 s por envío es estimado; con IA son 3–7 s y harían falta 400–1 000 hilos. La F0 lo mide.)

Subir `SIDEKIQ_CONCURRENCY` a 140 **no funciona** con el código actual:

1. **Cada hilo ocupa una conexión a Postgres mientras espera a Meta/OpenAI** (H3: el envío va
   dentro de `with_lock`). 140 hilos = 140 conexiones tomadas; Postgres trae `max_connections=100`
   por defecto y la web también necesita las suyas.
2. **Un proceso Ruby usa un solo núcleo para el código Ruby** (GVL). Mientras un hilo espera la
   red, otro avanza; pero armar el mensaje, los callbacks de `Message`, ActionCable y JSON sí
   gastan CPU. Muchos hilos en un proceso se estorban: lo práctico son ~10–25 hilos por proceso
   y **más procesos**, no un proceso gigante.
3. **Los envíos no son lo único**: cada uno genera 2–3 webhooks de estado (cola `low`), y por la
   prioridad estricta (H1) esos van antes que los envíos.
4. **Memoria**: cada proceso Sidekiq puede pasar de 1 GB (documentación oficial).

Lo que sí funciona:

```
   F1: enviar FUERA de la transacción → el hilo espera a Meta sin ocupar conexión a la BD
   +   varios procesos Sidekiq por rol (p. ej. 6 × 25 hilos = 150 hilos solo para envíos)
   +   PgBouncer delante de Postgres (muchos hilos, pocas conexiones reales)
   +   el despachador de F2 decide cuántos salen por número y por segundo
```

---

## 3. A dónde hay que llegar

```
                 ┌──────────────── BD = fuente de verdad ────────────────┐
 Enroll/Lote ──► │ contact_trackings (scheduled_for, status)             │
 (insert_all     │ tracking_campaign_entries (+ wamid, estados, error)    │
  por bloques)   └───────────────────────▲───────────────────────────────┘
                                         │ reclama con FOR UPDATE SKIP LOCKED
                                         │
 CampaignDispatcherJob (cada 5–10 s) ────┘
   · por cada inbox/número con pendientes vencidos:
       toma hasta N = fichas disponibles del número   ◄── token bucket en Redis
   · reparte por turnos entre cuentas (round-robin)   ◄── reparto justo
   · encola CampaignSendJob(tracking_id) en cola propia
                     │
                     ▼
 Cola campaign_sends  (proceso Sidekiq dedicado, escala horizontal)
   CampaignSendJob:
     1. reclama: UPDATE … SET status='active' WHERE status='scheduled'  (lock corto)
     2. FUERA de transacción: (IA en cola ai_generation si hace falta) → Meta
     3. guarda resultado: Message + entry.wamid / error_code
     4. error pasajero (límite, 5xx) → reprograma con espera; definitivo → failed con motivo

 Meta ──webhooks──► cola webhooks_status (proceso propio, rápido)
     · actualiza Message.status y entry por wamid
     · suma ±1 a contadores de la campaña (sin recalcular)
     · calidad del número / plantilla pausada → pausa campañas de ese número
```

---

## 4. Fases

### F0 — Medir antes de tocar (solo lectura + métricas)
- Consultas en la BD: envíos por campaña/minuto, fallas por motivo, tiempo entre `scheduled_for` y el envío real.
- Latencia por cola de Sidekiq (`Sidekiq::Queue#latency`) y tamaño del ZSET de programados.
- Leer de Meta el nivel y la velocidad de cada número conectado.
- **Entregable:** tabla con valores reales que reemplaza la sección 2.

### F1 — Aislar y quitar transacciones largas (H1, H2, H3, H5)
- Cola nueva `campaign_sends` con proceso Sidekiq propio; los envíos dejan de competir con webhooks y correos.
- Cola `webhooks_status` para los estados de WhatsApp, separada de `low`.
- Reclamar el seguimiento con un UPDATE condicional y **enviar fuera del lock**.
- El cron pasa a ser solo una red de seguridad: encola lo vencido hace más de X minutos, no todo.

### F2 — Despachador con ritmo y reparto justo (H4, H6, H7, H8)
- `CampaignDispatcherJob`: la BD manda (`scheduled_for` ya tiene índice `status, scheduled_for`); se dejan de programar millones de `wait_until` en Redis.
- Token bucket por número en Redis (`Redis::LockManager`/Alfred ya existen): no pasar la velocidad de Meta.
- Turnos entre cuentas: ninguna campaña grande bloquea a las demás.
- El escalonado sale solo: ya no importa que todos tengan la misma `send_at`.

### F3 — Registro por destinatario (H9, H10, H11) — la idea de wacrm
- En `tracking_campaign_entries`: `wamid`, `sent_at`, `delivered_at`, `read_at`, `failed_at`, `error_code`, `error_message` + índice único por `wamid`.
- El webhook de estado actualiza la inscripción por `wamid`.
- Contadores en la campaña (`sent_count`, `delivered_count`, …) que se ajustan ±1 en cada cambio, como el trigger de wacrm (`supabase/migrations/005_…`). La pantalla deja de recalcular.
- Clasificar errores de Meta en **definitivos** (número inválido, opt-out, plantilla pausada) y **pasajeros** (límite, 5xx), con reintento solo para los pasajeros.
- Arreglar el `update!` sobre el mensaje temporal (H10).

### F4 — Cuidar el número del cliente
- Escuchar los webhooks de calidad del número y de estado de plantilla: si baja la calidad o se pausa la plantilla, **pausar** las campañas de ese número.
- Tope diario automático según el nivel de Meta (hoy `daily_cap` es manual).

### F5 — Lote grande (H13)
- Subir `MAX_BULK_ASSIGN` por plan o licencia (encaja con el módulo de Licencias).
- Inscribir por bloques (`find_in_batches` + `insert_all`), con progreso visible.
- Conversación y nota privada **al momento del envío**, no al inscribir (hoy se crean miles de conversaciones antes de mandar nada).

### F6 — IA en su carril
- Generar mensajes con IA en una cola `ai_generation` con límite por cuenta (cada cuenta usa su llave y tiene su propio límite en OpenAI).
- Revisar qué callbacks de `Message` (H12) sobran para mensajes de campaña.

### F7 — Infraestructura
- Procesos Sidekiq por rol: web/crítico · webhooks · envíos de campaña · IA. Cada uno escala por separado.
- PgBouncer y `pool` acorde a la concurrencia total.
- Redis de Sidekiq separado del de caché.
- Archivar o particionar `tracking_campaign_entries` y `contact_trackings` viejos.

### F8 — Prueba de carga
- Un Meta falso (servidor que responde como `/messages` y manda webhooks) + script que simula 1 000 cuentas.
- Meta: sostener el pico de la sección 2 con latencia de cola < 1 min.

---

## 4.1 Impacto en el sistema actual y riesgos

Hoy no afecta nada: es solo plan. El impacto aparece al implementar.

Servidor actual (16/10/2026): 8 núcleos, 31 GB RAM (~17 GB disponibles). En el mismo servidor
corren `chatwoot-dev` y `chatwoot_staging` y **comparten el mismo Postgres**:
`max_connections=100`, 27 ocupadas (11 dev, 10 staging, 6 de otros procesos).

| Punto | ¿Afecta? | Qué cuidar |
|---|---|---|
| **Enviar fuera del lock (F1)** | Sí: cambia el envío de **todos** los seguimientos, no solo los de campaña | Hoy el `with_lock` es lo que evita **mensajes duplicados al cliente**: impide que dos jobs manden el mismo seguimiento y descarta el que llega adelantado o repetido en < 60 s (`contact_tracking_job.rb:21-49`). El reemplazo tiene que conservar esa protección: un UPDATE condicional que aparta el seguimiento antes de enviar. Si se hace mal, el cliente recibe dos mensajes. Probar con agentes de prueba e inbox 493, nunca en clientes reales |
| **6 procesos × 25 hilos (F7)** | **Sí: en este servidor lo tumba** | ~150 conexiones contra un máximo de 100 (27 ya ocupadas): se acaban las conexiones y fallan dev, staging y la web. 6 Sidekiq × >1 GB = >6 GB de RAM. Es para producción a escala, con servidores propios |
| **PgBouncer (F7)** | Poco, si se configura bien | Revisado: ActionCable usa Redis (`config/cable.yml:2`); el código no usa bloqueos de sesión (advisory locks) ni LISTEN/NOTIFY. `config/database.yml` no define `prepared_statements` (vienen activados): en modo transacción apagarlos o usar PgBouncer ≥ 1.21. Las migraciones van directo a Postgres, sin pasar por PgBouncer |
| **Despachador (F2)** | Sí, en los tiempos | Los mensajes salen según el ritmo de cada número: algunos se retrasan segundos o minutos respecto a la hora exacta. Si se aplica a **todos** los seguimientos (D2), también cambia los de la automatización y los individuales |

Cómo hacerlo sin riesgo:
- **F1 y F2 detrás de una bandera por cuenta** (como `erp_connection`): se prenden solo en una cuenta
  de prueba y lo demás sigue igual.
- **F7 no se hace en este servidor**: aquí basta con 1 proceso de Sidekiq.
- **RSpec corre contra `chatwoot_dev`** y ya borró conversaciones reales: antes de las pruebas de
  F1/F2 conviene una base de pruebas aparte.

---

## 4.2 Producción (hostdime) — datos reales del 16/10/2026

Obtenidos con un script de solo lectura (`~/diag_servidor.sh`) a las 12:33 CST.

```
 UN SOLO SERVIDOR (todo junto)                  8 núcleos · 31 GB RAM · 915 GB disco (51%)
 ┌───────────────────────────────────────────────────────────────────────────┐
 │ nginx ─► Puma: 4 procesos × 5 hilos (~3 GB)                                │
 │ Sidekiq 7.3.1: 1 proceso × 20 hilos ── 5.7 GB RAM ── «20 of 20 busy» ⚠    │
 │ PostgreSQL 16 (wintook_db 11 GB) · max_connections 100 · 47 en uso        │
 │            shared_buffers 128 MB ⚠ (valor de fábrica)                      │
 │ Redis 7.4 · 34 MB · programados 12 376 · muertos 9 999 ⚠                   │
 └───────────────────────────────────────────────────────────────────────────┘
 Chatwoot 3.13.6 · Ubuntu 24.04 · carga 1.1–1.4 de 8 núcleos · encendido 367 días
```

### Volumen actual

| Dato | Valor | Contra la referencia oficial |
|---|---|---|
| Cuentas | 285 | — |
| Conversaciones nuevas / 24 h | 516 | 5 % del nivel de 4 núcleos (10 000/día) |
| Mensajes / 24 h | 11 279 | ≈ 0.13 msg/s de promedio |
| Hora pico (últimos 7 días) | 1 241 mensajes/h | ≈ 0.35 msg/s; picos a las 15–17 h UTC (9–11 h CST) |

Si se crece **al mismo ritmo por cuenta** a 1 000 cuentas: ~40 000 mensajes/día, ~4 400 en la hora
pico (~1.2 msg/s). El hardware lo aguanta. El escenario de la sección 2 (1 000 000 envíos/día) es
**~90 veces** el volumen total de hoy: sigue siendo un supuesto y depende de D1.

### Hallazgos

| # | Hallazgo | Por qué importa | Qué hacer |
|---|---|---|---|
| P1 | **Ráfagas que llenan los 20 hilos.** Panel de Sidekiq (`/monitoring/sidekiq`, 16/10): 19 de 20 ocupados, **224 en espera**, y en *Busy* casi todo es `Inboxes::FetchImapEmailsJob` (cada minuto, uno por inbox de correo, `config/schedule.yml:24`) y `Channels::Whatsapp::TemplatesSyncJob` (cada 5 min, hasta 25 canales, `templates_sync_scheduler_job.rb`). **No** eran envíos de campaña | Son jobs de Chatwoot base que esperan red (servidor de correo, Meta) y arrancan todos en el mismo segundo. Mientras duran, ocupan los hilos y lo demás espera, **incluidos** los mensajes entrantes y los envíos. Con más cuentas hay más inboxes, y las ráfagas crecen solas | Separar Sidekiq en 2 procesos (ver nota P1): uno para lo urgente y otro para lo lento. Es configuración, no código |
| P2 | **9 999 jobs muertos** (el máximo de Sidekiq es 10 000: el cajón está lleno y ya descarta los más viejos). Revisada la 1.ª página el 16/10: **ninguno es de envíos**; son 4 errores que se repiten (ver nota P2) | Ruido que tapa errores reales: si mañana falla algo importante, se pierde entre estos | Corregir los 4 y después vaciar el cajón (con OK) |
| P3 | **Sidekiq usa 5.7 GB** (la documentación habla de 1 GB+) | Crecimiento de memoria acumulado; con más carga puede terminar en un corte por falta de memoria | Tope de memoria con reinicio controlado (`MemoryMax` en el servicio) y `MALLOC_ARENA_MAX=2` |
| P4 | **`shared_buffers` = 128 MB** en un servidor de 31 GB con una BD de 11 GB | Postgres casi no usa RAM propia como caché; todo depende del sistema operativo | Ajustar a ~25 % de la RAM (≈ 8 GB) y `effective_cache_size` ≈ 20 GB. **Requiere reiniciar Postgres**: hacerlo en horario sin carga |
| P5 | 12 376 jobs programados en Redis | Es H6: un job programado por seguimiento | Lo resuelve el despachador (F2) |
| P6 | Conexiones: web 4 × 5 = 20 + Sidekiq 20 = 40 (47 en uso de 100) | Hay margen para **un** proceso Sidekiq más de 20 hilos; no para 6 × 25 | PgBouncer antes de crecer más |
| P7 | Todo en un solo servidor (web, Sidekiq, Postgres, Redis) | Un pico de Sidekiq o de Postgres afecta a todo lo demás | Para el crecimiento: Sidekiq y Postgres en servidores propios (F7) |

**Nota P1 — separar Sidekiq por urgencia (sin código):**

```
 hoy: 1 proceso × 20 hilos para TODO
      ráfaga IMAP + plantillas (esperan red) ──► 19/20 ocupados ──► 224 en espera, incluido lo urgente

 propuesta: 2 procesos
   worker 1 (urgente)  · critical, high, medium, default, mailers   · 10–15 hilos
   worker 2 (lento)    · low, scheduled_jobs y demás               · 10–15 hilos
   → una ráfaga de IMAP o de plantillas ya no frena los mensajes entrantes
```
Cabe en producción: +1 proceso ≈ +1–2 GB de RAM (hay 21 GB disponibles) y +10–15 conexiones
(47 de 100 en uso). Se hace con un segundo servicio `chatwoot-worker.2` con su lista de colas.
Pide OK y una ventana; no se toca hasta entonces. Panel del 16/10: 175 M procesados, 488 k fallidos
(0.28 %).

**Nota P2 — qué hay en los muertos (1.ª página, 16/10):**

| Job | Error | Causa (en el código) | ¿Pierde algo? |
|---|---|---|---|
| `Webhooks::WhatsappEventsJob` (el más repetido) | `Down::ClientError: 400` | Ecos `smb_message_echoes` de tipo **`edit`** y **`revoke`** (el negocio editó o borró un mensaje desde la app de WhatsApp Business). `Whatsapp::EchoMessageService` (código propio) solo descarta `reaction/ephemeral/unsupported/request_welcome` (`incoming_message_service_helpers.rb:48`), así que trata el eco como mensaje nuevo, intenta bajar un archivo que no existe y Meta responde 400 | No: el mensaje original ya estaba guardado. Solo no se refleja la edición o el borrado hecho desde el celular |
| `ActionMailbox::RoutingJob` | `undefined method 'active?' for nil` | Correo que llega a un canal de correo cuya **cuenta ya no existe** (`support_mailbox.rb:39` → `incoming_email_validity_helper.rb:21`) | No para cuentas activas: son correos a canales huérfanos |
| `Channels::Whatsapp::TemplatesSyncJob` (canal 40, cada 3 h) | `undefined method 'update_cache_key' for nil` | Canal de WhatsApp **sin cuenta** (`account_cache_revalidator.rb:9`) | No: es un canal huérfano que se sigue sincronizando |
| `Internal::CheckNewVersionsJob` / `RoutingJob` | `[]` for nil / `Invalid email to address header` | Revisión de versión de Chatwoot / correo mal formado | No |

Arreglos (pequeños, se planean aparte): agregar `edit`/`revoke` a los tipos que se descartan
o se manejan en el eco; que el ruteo de correo y el sync de plantillas ignoren canales sin cuenta;
limpiar los canales huérfanos.

### Contexto de uso (16/10/2026)
Las campañas (TrackingCampaign) **todavía no se usan en producción**: se esperan los resultados de
este análisis de capacidad. Por eso producción no muestra carga de envíos masivos y la sección 2
sigue siendo un supuesto.

### Qué cambia en el plan
- **F0 ya tiene dónde mirar:** P1 y P2 explicados; ninguno viene de envíos masivos.
- **Mejoras rápidas sin código:** P3 y P4. Son cambios de configuración que se hacen aparte y
  con ventana de mantenimiento; ninguno se aplica sin OK.
- **D4 respondida:** producción es un solo servidor con Postgres y Redis locales.

---

## 5. Orden recomendado

```
F0 ──► F1 ──► F3 ──► F2 ──► F5 ──► F4 ──► F6 ──► F7 ──► F8
medir  aislar  saber   ritmo   lotes   cuidar   IA     infra   probar
       (barato, qué pasó  y       grandes número
        alto    con cada  turnos
        impacto) envío
```
F1 es barata y quita el riesgo más grande (H1 + H3). F3 va antes que F2 para que el
despachador ya sepa distinguir errores pasajeros de definitivos.

### 5.1 Orden con los datos de producción (16/10/2026) — de menor a mayor riesgo

| Paso | Qué | ¿Código? | ¿Afecta lo que funciona hoy? |
|---|---|---|---|
| 1 | **P1** separar Sidekiq en 2 procesos · **P4** memoria de Postgres · **P3** tope de memoria de Sidekiq | No: configuración del servidor | Los jobs hacen lo mismo; al reiniciar Sidekiq los jobs en curso se reencolan. **Reiniciar Postgres deja Chatwoot sin servicio unos segundos** → ventana de mantenimiento |
| 2 | **P2** arreglar los 4 errores de los muertos y vaciar el cajón | Poco: unas líneas en el eco de WhatsApp, el ruteo de correo y el sync de plantillas | Solo cambia lo que hoy ya falla. Vaciar con *Delete*, **nunca con *Retry*** |
| 3 | **F3** registro por destinatario | Sí, pero se suma: columnas nuevas + una línea en el webhook de estado | No: las campañas no se usan en producción |
| 4 | **F1** enviar fuera del lock | Sí: `ContactTrackingJob`, que manda **todos** los seguimientos del Agente IA (sí se usan en producción) | Riesgo de **mensaje doble** si se hace mal → bandera por cuenta, probar en el inbox 493 y luego prender cuenta por cuenta |

Los pasos 1 y 2 ayudan **aunque nunca se usen las campañas**: hoy las ráfagas de IMAP y de
plantillas frenan a todo el sistema. Cada paso pide OK; los de servidor, además, una ventana.

---

## 6. Decisiones abiertas
- **D1** — ¿Volumen real esperado por cuenta (campañas/día, contactos/campaña)? Cambia la sección 2.
- **D2** — ¿El despachador reemplaza `wait_until` para **todos** los seguimientos o solo los de campaña?
- **D3** — ¿Tope de contactos por campaña según la licencia de la cuenta?
- ~~**D4** — ¿Dónde vive producción?~~ **Respondida (16/10/2026):** un solo servidor (hostdime) con
  Postgres 16 y Redis 7.4 locales; ver §4.2.
- **D5** — ¿Si la ventana de 24 h está abierta, una campaña masiva debe usar IA o la plantilla? La IA multiplica costo y tiempo por envío.
