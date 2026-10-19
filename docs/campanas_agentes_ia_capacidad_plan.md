# Campañas de Agentes IA — Diagnóstico de capacidad y plan por fases

> **Rama:** `diag/campanas_agentes_ia` (creada desde `origin/develop`, commit `0d860df88`)
> **Fecha del diagnóstico:** 2026-10-16
> **Alcance:** análisis. **Fase 0 hecha** (PR #87, mergeado) y **Fase 1 hecha** (PR #88, pendiente de merge), ambas el 2026-10-19 (§13). La Fase 2 no tiene cambios de código todavía.
> **Corrección 2026-10-19:** las cifras de entrega de §3.4 estaban infladas (la consulta contaba un mismo mensaje una vez por cada seguimiento de la conversación e incluía canales que no son WhatsApp) y la afirmación de que los fallidos no guardaban el motivo de Meta era falsa (sí lo guardan; la consulta no lo veía por cómo está almacenado). Se corrigieron §1, §3.4, §6, §7, §10 y §13.
> **Importante:** el módulo de campañas de Agentes IA está **en desarrollo** y solo existe en el servidor de desarrollo; **en producción no se ha usado**. Las cifras de uso de campañas y seguimientos de este documento son de **pruebas en desarrollo**, no de clientes. Lo que vale para producción es el análisis del código (misma versión 3.13.6) y los datos del servidor productivo de la §3.6.
> **Meta del negocio:** 500 cuentas × 2 campañas × 1,000 contactos (~1,000,000 contactos), programadas en horarios distintos. Lo que no se entregue se reintenta; lo que ya se entregó nunca se reenvía.

---

## Índice

1. [Resumen ejecutivo](#1-resumen-ejecutivo)
2. [Cómo funciona hoy el módulo](#2-cómo-funciona-hoy-el-módulo)
3. [Mediciones reales](#3-mediciones-reales)
4. [Capacidad estimada actual](#4-capacidad-estimada-actual)
5. [Limitaciones y cuellos de botella](#5-limitaciones-y-cuellos-de-botella)
6. [Problemas encontrados en el camino](#6-problemas-encontrados-en-el-camino)
7. [Qué afecta hoy el código tal como está](#7-qué-afecta-hoy-el-código-tal-como-está)
8. [¿Soporta envío masivo con 255–500 cuentas?](#8-soporta-envío-masivo-con-255500-cuentas)
9. [¿Es necesario `ExecutePendingJob`?](#9-es-necesario-executependingjob)
10. ["Enviado" no es "entregado"](#10-enviado-no-es-entregado)
11. [Comparación con Chatwoot oficial (v4.4 → v4.18)](#11-comparación-con-chatwoot-oficial-v44--v418)
12. [¿Se puede traer esa funcionalidad a esta versión?](#12-se-puede-traer-esa-funcionalidad-a-esta-versión)
13. [Plan por fases](#13-plan-por-fases)
    - [Fase 0 — Arreglos rápidos](#fase-0--arreglos-rápidos-1-día)
    - [Fase 1 — Entrega confirmada](#fase-1--entrega-confirmada-35-días)
    - [Fase 2 — Volumen](#fase-2--volumen-12-semanas-con-prueba-de-carga)
14. [Resumen de fases](#14-resumen-de-fases)
15. [Pendientes y observaciones aparte](#15-pendientes-y-observaciones-aparte)
16. [Fuentes](#16-fuentes)

---

## 1. Resumen ejecutivo

- El módulo está **en desarrollo** y **no se ha usado en producción**. En el servidor de desarrollo, las pruebas suman 1 cuenta, 5 campañas, ~125 seguimientos vivos y un pico de 27 envíos/hora.
- **Funciona bien para cientos o pocos miles de contactos repartidos**, pero **no está diseñado para ~1M**.
- El primer techo con volumen **no es el servidor**, sino:
  1. los niveles de envío de **WhatsApp (Meta)** por número,
  2. los límites de las **llaves de OpenAI** (varias cuentas comparten llave y no se maneja el error 429),
  3. un defecto interno: **la cola se auto-amplifica** cuando se atrasa (`ExecutePendingJob`) y **`cancel_existing_jobs` crece al cuadrado** con el volumen.
- El sistema **no sabe si un mensaje se entregó**: cuenta como éxito que Meta acepte la petición. En las pruebas del último mes en desarrollo, **~16 %** de los mensajes de seguimiento por WhatsApp quedaron fallidos o sin confirmar y se contaron como intentos exitosos.
- Chatwoot oficial (v4.4+) tiene campañas de WhatsApp, pero **más simples** (una plantilla fija, sin IA) y el seguimiento por destinatario es **Enterprise**. **No conviene actualizar**; conviene **portar el patrón** a nuestro módulo.
- La versión local **ya tiene ~80 % de la infraestructura** necesaria para confirmar entregas (ID del mensaje en Meta, webhook de estados, código de error).
- Propuesta: **Fase 0** (arreglos rápidos, ~1 día), **Fase 1** (entrega confirmada, ~3–5 días), **Fase 2** (volumen, ~1–2 semanas con prueba de carga).

---

## 2. Cómo funciona hoy el módulo

### 2.1 Piezas

| Pieza | Archivo | Qué hace |
|---|---|---|
| `TrackingCampaign` | `app/models/tracking_campaign.rb` | La campaña. Estados `saved`, `draft`, `running`, `paused`, `finished`. Modos `batch` (por lote) y `continuous` (la inscriben automatizaciones). Ventana: `scheduled_for` (inicio), `ends_at` (fin), `entry_delay_minutes`, `respect_working_hours`, `daily_cap`. |
| `TrackingCampaignEntry` | `app/models/tracking_campaign_entry.rb` | Registro de cada contacto que entró o se intentó meter (`enrolled` / `skipped` con motivo). Índice único que impide inscribir dos veces al mismo contacto. |
| `ContactTrackings::BulkAssignService` | `app/services/contact_trackings/bulk_assign_service.rb` | Fase síncrona: valida, crea la campaña y encola. Fase background (`process!`): recorre contactos y los inscribe. **`MAX_BULK_ASSIGN = 100`**. |
| `ContactTrackings::BulkAssignJob` | `app/jobs/contact_trackings/bulk_assign_job.rb` | Cola `medium`. Procesa **todos** los contactos de la campaña en **un solo trabajo**, uno por uno. |
| `TrackingCampaigns::Enroll` | `app/services/tracking_campaigns/enroll.rb` | Único camino para inscribir. Revisa: campaña cerrada, ya inscrito, tope diario, Agente IA activo, contactabilidad, fuera de ventana. |
| `TrackingCampaigns::Schedule` | `app/services/tracking_campaigns/schedule.rb` | Calcula la hora de envío: inicio + espera, dentro del horario del inbox, antes del fin. |
| `TrackingCampaigns::TrackingBuilder` | `app/services/tracking_campaigns/tracking_builder.rb` | Crea (o reusa) la conversación + nota privada, inserta el `ContactTracking` y encola `ContactTrackingJob.set(wait_until: scheduled_for)`. |
| `TrackingCampaigns::Launch` | `app/services/tracking_campaigns/launch.rb` | Pone en curso una campaña Guardada. |
| `TrackingCampaigns::WindowJob` | `app/jobs/tracking_campaigns/window_job.rb` | Cada 5 min: abre (`draft` → `running`) y cierra (`→ finished`) campañas por su ventana. |
| `ContactTrackingJob` | `app/jobs/contact_tracking_job.rb` | Cola `scheduled_jobs`. Ejecuta un intento: genera mensaje (IA si hay hook OpenAI), envía plantilla o mensaje de sesión, reprograma el siguiente intento. **Todo dentro de `with_lock`.** |
| `ContactTrackings::ExecutePendingJob` | `app/jobs/contact_trackings/execute_pending_job.rb` | Cada **1 minuto**: encola `ContactTrackingJob` para **todos** los seguimientos vencidos (`pending`, `scheduled`, `active` con `scheduled_for <= now`). |
| `ContactTrackingResponseAnalyzerJob` | `app/jobs/contact_tracking_response_analyzer_job.rb` | Cola `default`. Responde con IA cuando el cliente escribe (RouterService, KBase, respuestas, etc.). |
| `ContactTrackings::CleanupJob` | `app/jobs/contact_trackings/cleanup_job.rb` | Diario 2 AM, cola `low_priority`. Borra seguimientos terminados de más de 90 días. |

### 2.2 Flujo de una campaña por lote

1. El usuario crea la campaña → `BulkAssignService#call` valida (máx. 100 contactos), crea `TrackingCampaign` y encola `BulkAssignJob`.
2. `BulkAssignJob` → `process!` → por cada contacto, `TrackingCampaigns::Enroll`:
   - si se omite: crea `TrackingCampaignEntry` `skipped` con motivo;
   - si entra: crea la entrada `enrolled`, abre/reusa conversación (con nota privada), inserta `ContactTracking` y encola `ContactTrackingJob` para su hora.
3. A la hora, `ContactTrackingJob`:
   - toma `with_lock` sobre el seguimiento;
   - descarta si está pausado/cancelado/completado/activo, si es duplicado (<60 s del último intento) o si llegó antes de hora;
   - genera el mensaje (OpenAI si la cuenta tiene hook) y envía (plantilla o sesión);
   - si Meta acepta → cuenta el intento como **exitoso** y reprograma el siguiente (o completa);
   - si falla → marca `failed`.
4. Al reprogramar, el callback `reschedule_job_if_needed` llama a `cancel_existing_jobs` (recorre todas las colas) y `schedule_job`.
5. En paralelo, cada minuto `ExecutePendingJob` re-encola todo lo vencido (red de seguridad).
6. Cuando el cliente responde, `Message#analyze_for_active_trackings` encola `ContactTrackingResponseAnalyzerJob`.

---

## 3. Mediciones reales

> Las secciones 3.1 a 3.5 se midieron en el **servidor de desarrollo** (donde vive el módulo de campañas). La §3.6 es el **servidor productivo** y la §3.7 compara ambos.

### 3.1 Infraestructura del servidor de desarrollo

| Elemento | Valor |
|---|---|
| Servidor | 8 vCPU, 31 GB RAM (~21 GB disponibles) |
| Compartido con | 3 instancias de desarrollo (`luis`, `mariana`, `jose_luis`, cada una con su BD y su DB de Redis), app Laravel en `wintook_dev`, zabbix |
| Puma producción | 1 proceso (`chatwoot-web.1`), `RAILS_MAX_THREADS=5` |
| Sidekiq producción | **1 proceso** (`chatwoot-worker.1`), **10 hilos**, todas las colas en **prioridad estricta** |
| Orden de colas (`config/sidekiq.yml`) | critical, high, medium, default, mailers, action_mailbox_routing, low, **scheduled_jobs**, async_database_migration, active_storage_* , action_mailbox_incineration |
| Pool de BD | Sidekiq 10, Puma 5 |
| Postgres | `max_connections = 100`, **72 en uso** (zabbix 32, wintook_dev 16, dev 18, otras 6) |
| Redis | 11 MB usados, sin `maxmemory` |
| Backups de `wintook_dev` | **No activos** (ver memoria del proyecto) |

### 3.2 Uso actual del módulo

| Dato | Valor |
|---|---|
| Cuentas en producción | 249 en BD (el negocio reporta 255) |
| Cuentas con hook OpenAI activo | 80 |
| Llaves OpenAI distintas | 58 (una llave compartida por 5 cuentas; 2 llaves por 3; 7 llaves por 2) |
| Cuentas usando campañas | **1** (cuenta 568) |
| Campañas | 3 `running` batch, 1 `saved` batch, 1 `running` continua |
| Seguimientos por estado | completed 670, cancelled 555, paused 65, failed 64, scheduled 36, pending 25 |
| Seguimientos vivos | ~125 (123 de la cuenta 568) |
| Pico de envíos de seguimiento | **27 por hora** (2026-10-16 14:00) |
| Pico de mensajes entrantes en conversaciones con seguimiento | **230 por hora** (2026-10-13 19:00) |
| Modelo por defecto | `gpt-4o-mini` (configurable por inbox) |
| `TRACKING_GPT_HISTORY_ENABLED` | `true` (manda historial de hasta 20 mensajes) |

### 3.3 Tiempos de los trabajos (logs de 2 días)

| Trabajo | Ejecuciones | p50 | p90 | p99 | máx. |
|---|---|---|---|---|---|
| `ExecutePendingJob` | 2,879 | 0.0 s | 0.0 s | 0.1 s | 12.4 s |
| `KeywordCheckerJob` | 839 | 0.0 s | 0.0 s | 0.1 s | 0.3 s |
| `BotSeller::OutgoingDispatchJob` | 566 | 0.1 s | 0.2 s | 0.3 s | 0.9 s |
| `ContactTrackingJob` | 549 | 0.0 s | 2.0 s | 3.2 s | 7.6 s |
| `ContactTrackingResponseAnalyzerJob` | 465 | 0.1 s | 3.1 s | 9.2 s | 10.5 s |
| `Assistant::InterviewJob` | 23 | 21.6 s | 37.1 s | 69.5 s | 69.5 s |
| `BulkAssignJob` | 9 | 0.3 s | 9.2 s | 9.2 s | 9.2 s |

Detalle de trabajo real (ejecuciones ≥ 0.8 s):

| Trabajo | Total | Con trabajo real | Promedio real |
|---|---|---|---|
| `ContactTrackingJob` | 549 | 163 | **1.9 s** |
| `ContactTrackingResponseAnalyzerJob` | 465 | 187 | **2.9 s** |

→ **386 de 549** ejecuciones de `ContactTrackingJob` (70 %) no hicieron nada: eran duplicados o adelantados.

### 3.4 Entrega real de WhatsApp (últimos 30 días, conversaciones con seguimiento, mensajes salientes públicos)

| Estado | Mensajes | % |
|---|---|---|
Solo canales de WhatsApp, cada mensaje contado una vez, del 2026-09-16 al 2026-10-16 (cifras corregidas el 2026-10-19).

| Estado | Mensajes | % |
|---|---|---|
| Leído (`read`) | 1,195 | 60.5 % |
| Entregado (`delivered`) | 460 | 23.3 % |
| **Solo enviado (`sent`, nunca confirmado)** | **281** | **14.2 %** |
| **Fallido (`failed`)** | **38** | **1.9 %** |
| Total | 1,974 | |

Los 38 fallidos **sí tienen el motivo de Meta guardado** en el mensaje (`external_error`):

| Código | Significado | Mensajes |
|---|---|---|
| 131047 | Fuera de la ventana de 24 h sin plantilla | 21 |
| 131049 | Meta limitó el marketing a ese usuario | 14 |
| 130472 | El número participa en un experimento de Meta | 2 |
| 131026 | No entregable (sin WhatsApp o bloqueó) | 1 |

Lo que faltaba era ese motivo **en el seguimiento**: guardaba solo "Failed to send message" (corregido en la Fase 0, §13).

> **Ojo con consultas propias:** `content_attributes` está guardado como texto JSON dentro de JSON, así que el operador `?` de `jsonb` no encuentra `external_error`; hay que buscarlo con `LIKE` o leerlo por el modelo (`message.external_error`).

### 3.5 Estado de Sidekiq

| Conjunto | Tamaño | Detalle |
|---|---|---|
| Programados (`schedule`) | 571 | 510 `ActionMailbox::IncinerationJob`, 61 `ContactTrackingJob` |
| Reintentos (`retry`) | 0 | |
| Muertos (`dead`) | 709 | 178 `Internal::CheckNewVersionsJob`, 240 `Webhooks::WhatsappEventsJob`, 122 `CalendarAlertJob`, 17 `TrackingCampaigns::WindowJob` (StatementInvalid, sep), etc. |
| Cola `low_priority` | **249** | `ContactTrackings::CleanupJob` desde **2026-02-10** — nunca procesados. **Vaciada el 2026-10-19 (Fase 0).** |
| Cola `knowledge_base` | **49** | `KnowledgeBaseArticleProcessorJob` desde **2025-12-17** — nunca procesados; esa clase no existe en el repo. **Vaciada el 2026-10-19 (Fase 0).** |

### 3.6 Servidor productivo (hostdime, 2026-10-16 12:33 CST)

> Las campañas de Agentes IA **no** se usan aquí todavía. Estos datos muestran la carga que ya tiene la plataforma y que las campañas compartirán al desplegarse.

| Elemento | Valor |
|---|---|
| Sistema | Ubuntu 24.04.1, 8 núcleos, 31 GB RAM (21 GB disponibles), disco 915 GB (51 % usado), arriba 367 días |
| Carga | load average 1.10 / 1.34 / 1.37 (sobre 8 núcleos) |
| Versión | Chatwoot 3.13.6, PostgreSQL 16.15, Redis 7.4.1 |
| Puma | `WEB_CONCURRENCY=4`, `RAILS_MAX_THREADS=5` (4 procesos, ~640–800 MB c/u) |
| Sidekiq | 1 proceso, `SIDEKIQ_CONCURRENCY=20`, 5.7 GB RAM, **20 de 20 hilos ocupados con todas las colas vacías** |
| Postgres | `max_connections` 100, 47 en uso, **`shared_buffers` 128 MB (valor de fábrica)**, BD de 11 GB |
| Uso | 285 cuentas, 516 conversaciones y 11,279 mensajes en 24 h; pico de 1,241 mensajes/hora |
| Redis | 33.6 MB; **12,376 trabajos programados**, 0 reintentos, **9,999 muertos (tope de la lista)** |

Lectura:
1. **20 de 20 hilos ocupados con colas vacías:** los hilos estaban atorados en trabajos largos (sospechosos: llamadas externas sin timeout). Mientras dure, cualquier trabajo nuevo espera.
2. **12,376 programados:** si la mayoría son `ContactTrackingJob` (bot de seguimiento normal), `cancel_existing_jobs` ya recorre esa lista en cada reprogramación.
3. **9,999 muertos:** la lista de muertos está llena y Sidekiq descarta los más viejos; hay un error constante sin revisar.
4. **`shared_buffers` 128 MB:** con 11 GB de BD y 31 GB de RAM, Postgres casi no usa memoria como caché. Recomendado: `shared_buffers` 8 GB, `effective_cache_size` 20 GB, `work_mem` 16 MB, `maintenance_work_mem` 1 GB, `random_page_cost` 1.1 si es SSD.
5. **Capacidad de envío con 20 hilos:** ~600 envíos/minuto teóricos (6–7 campañas de 100 en el mismo minuto antes de la espiral de duplicados), **siempre que los hilos estén libres**.

Pendiente: correr el script de solo lectura `diag_campanas_prod.sh` en producción para desglosar programados, muertos y trabajos que ocupan los hilos.

### 3.7 ¿El servidor de desarrollo soporta la configuración de producción?

> Medido el 2026-10-16. Sirve para decidir si las pruebas (incluida la prueba de carga de la Fase 2, paso 2.9) se pueden hacer aquí con la misma configuración que producción.

**Respuesta corta:** sí, con un ajuste obligatorio: **las conexiones de Postgres**. Lo demás cabe. Además, el Postgres de desarrollo está **mejor afinado** que el de producción.

#### 3.7.1 Comparación de recursos

| Recurso | Producción | Desarrollo | ¿Soporta la config de producción? |
|---|---|---|---|
| CPU | 8 núcleos, carga ~1.3 | 8 núcleos, carga ~0.3 | ✅ Sobra |
| RAM disponible | 21 GB | 21.5 GB | ✅ Sí (ver §3.7.2) |
| Disco | 915 GB, 51 % usado | 908 GB, 22 % usado | ✅ Sí |
| PostgreSQL | 16.15 | 16.15 | ✅ Misma versión |
| Redis | 7.4.1 | 8.4.0 | ✅ Compatible con Sidekiq 7.3 |
| Puma | 4 procesos × 5 hilos | 1 proceso × 5 hilos | ✅ Se puede subir |
| Sidekiq | 20 hilos | 10 hilos | ✅ Se puede subir |
| **Conexiones de Postgres** | 47 de 100 | **75 de 100** | ❌ **No alcanzan** (ver §3.7.3) |

#### 3.7.2 Memoria

Subir a la configuración de producción agrega unos **3–6 GB**:
- 3 procesos más de Puma: ~0.5–0.8 GB cada uno.
- Sidekiq con 20 hilos: ~1.5–3 GB. En producción usa 5.7 GB, pero lleva 367 días sin reiniciarse y la memoria se acumula.

De 21.5 GB disponibles quedarían ~15 GB libres. Las 3 instancias de desarrollo (`luis`, `mariana`, `jose_luis`) ya usan ~1.5 GB cada una solo en webpack.

#### 3.7.3 El bloqueo: conexiones de Postgres

Uso actual en desarrollo: **75 de 100**.

| Quién | Conexiones |
|---|---|
| zabbix | 32 |
| Chatwoot (`wintook_dev`) | 16 |
| Instancias de desarrollo (`jose_luis`, `luis`, `mariana`) | 21 |
| Sistema | 6 |

Con la configuración de producción, Chatwoot puede llegar a **40** (Puma 4 × 5 = 20 + Sidekiq 20). El total quedaría en **~99–100 de 100**: a la primera carga fuerte aparecería "too many connections", y afectaría también a las instancias de desarrollo y a la app Laravel.

- **Solución:** subir `max_connections` a **200**. Con la memoria que tiene este Postgres no hay problema.
- **Costo:** requiere **reiniciar Postgres**, lo que corta unos segundos todas las bases del servidor: `wintook_dev` (8.5 GB), `chatzeus` (4.2 GB), zabbix y las de desarrollo.
- **Aparte:** zabbix usa 32 conexiones, que es mucho para monitoreo; conviene revisarlo.

#### 3.7.4 Postgres: desarrollo está mejor afinado que producción

| Parámetro | Producción | Desarrollo |
|---|---|---|
| `shared_buffers` | 128 MB (de fábrica) | **~7.8 GB** |
| `effective_cache_size` | ~4 GB | **~23 GB** |
| `work_mem` | 4 MB | **~31 MB** |
| `maintenance_work_mem` | 64 MB | **~2 GB** |
| `random_page_cost` | 4 | 1.1 |
| `max_connections` | 100 | 100 |

Consecuencias:
1. **La configuración de desarrollo se puede llevar a producción**, que tiene la misma RAM (31 GB). Es el cambio con mejor relación costo-beneficio disponible allá. Requiere reiniciar Postgres de producción en una ventana de mantenimiento.
2. **Una prueba de carga en desarrollo saldría más optimista que la realidad**, porque su base de datos rinde más. Para una prueba fiel: igualar producción a esta configuración antes, o tomar en cuenta la diferencia al leer los resultados.

**Cuidado con `random_page_cost`:** en desarrollo está en 1.1 (valor para SSD), pero **sus discos son mecánicos** (2 × HGST HUS722T1TAL, 7200 rpm). Lo correcto sería ~2–4. Hoy no se nota porque casi toda la base cabe en memoria. **En producción hay que confirmar el tipo de disco antes de poner 1.1.**

#### 3.7.5 Pasos para igualar desarrollo a la configuración de producción

No aplicado. Requiere confirmación, en un momento en que nadie use las instancias de desarrollo:

1. En `.env` de Chatwoot: `WEB_CONCURRENCY=4` y `SIDEKIQ_CONCURRENCY=20`.
2. En `postgresql.conf`: `max_connections = 200` → reiniciar Postgres (**corta todas las bases unos segundos**).
3. Reiniciar `chatwoot-web.1` y `chatwoot-worker.1` (siempre ambos).
4. Verificar: conexiones totales en `pg_stat_activity`, RAM con `free -m`, y que Sidekiq muestre `[0 of 20 busy]`.

---

## 4. Capacidad estimada actual

> Estimaciones extrapoladas de las mediciones (1.9 s por envío, 2.9 s por respuesta IA, 10 hilos compartidos). **No** se hizo prueba de carga.

| Flujo | Máximo teórico (10 hilos dedicados) | Realista (hilos compartidos) |
|---|---|---|
| Respuestas IA a clientes | ~12,000 / hora | **~4,000–6,000 / hora** (≈20× el pico actual) |
| Envíos de campaña | ~18,000 / hora | Mucho menos: su cola `scheduled_jobs` casi no recibe hilos si hay trabajo en colas de mayor prioridad |

Límites de producto:
- Campaña por lote: **máximo 100 contactos** (`MAX_BULK_ASSIGN`).
- Campaña continua: sin tope salvo `daily_cap` opcional.

---

## 5. Limitaciones y cuellos de botella

En el orden en que aparecen al crecer la carga:

### 5.1 WhatsApp (Meta) — externo
- Cada número tiene un **nivel de mensajes iniciados por el negocio en 24 h**: 250 / 1K / 10K / 100K contactos distintos. Un número nuevo empieza en 250.
- Fuera de la ventana de 24 h **solo se pueden mandar plantillas aprobadas**.
- La **calificación de calidad** del número puede bajar el nivel.
- 2 campañas de 1,000 contactos en un día requieren nivel 2K o 10K. Lo que pase el límite **falla y hoy el sistema no se entera**.

### 5.2 OpenAI — límites por llave
- 80 cuentas con OpenAI, **58 llaves**: las cuentas que comparten llave comparten el límite.
- **No hay manejo de 429 en ningún llamado** (`ContactTrackingJob`, RouterService, analizador, KBase, casos). Si OpenAI limita, el bot manda un mensaje simple sin IA o no contesta, sin alerta.
- Con historial de 20 mensajes, cada respuesta consume muchos tokens.
- **Cada envío de campaña llama a OpenAI** para personalizar el mensaje → 1M de envíos = 1M de llamadas, aunque al contacto frío solo se le puede mandar plantilla.

### 5.3 Sidekiq — un proceso, prioridad estricta
- 1 proceso, 10 hilos para **todo** Chatwoot (webhooks, correos, respuestas, campañas).
- `scheduled_jobs` está casi al final: un pico de entrantes **detiene los envíos**; un pico de envíos **atrasa todo lo demás**.

### 5.4 `ExecutePendingJob` amplifica el atraso
- Cada minuto re-encola **todos** los vencidos, estén o no ya en cola.
- Con 25,000 pendientes atrasados → ~25,000 trabajos nuevos **por minuto**, cada uno abriendo un bloqueo en BD aunque no haga nada. 10 hilos no lo vacían → espiral.

### 5.5 `cancel_existing_jobs` crece al cuadrado
- `contact_tracking.rb:572`. Se ejecuta en cada reprogramación (después de cada intento).
- Recorre **todo** el `ScheduledSet`, 5 colas (`default`, `scheduled_jobs`, `mailers`, `low`, `high`) y el `RetrySet`, parseando cada trabajo.
- Hoy: 571 trabajos → barato. Con 25,000–1M programados → cada reprogramación revisa decenas de miles → **O(N²)**, Redis se satura.

### 5.6 Llamadas externas dentro del bloqueo de BD
- `ContactTrackingJob` hace OpenAI **y** envío a Meta dentro de `with_lock` (transacción abierta).
- La llamada a OpenAI **no tiene `read_timeout`** → hasta 60 s ocupando una conexión de BD y bloqueando la fila.

### 5.7 Postgres
- 72 de 100 conexiones en uso. Escalar Sidekiq (más hilos o procesos) requiere subir `max_connections` o PgBouncer.

### 5.8 Servidor único compartido
- Producción comparte host con 3 entornos de desarrollo, Laravel y zabbix. Sin redundancia y sin backups activos.

### 5.9 Inscripción
- `BulkAssignJob` procesa toda la campaña en **un solo trabajo**. Con 1,000 contactos puede tardar minutos; un reinicio de Sidekiq (timeout 25 s) lo corta y lo repite desde el inicio (no duplica seguimientos gracias al índice único, pero genera entradas `skipped` de ruido).
- Al inscribir se crea **conversación + nota privada por contacto** de inmediato: con 1M serían 1M de conversaciones por adelantado, y posiblemente notificaciones de asignación al agente (por verificar).

---

## 6. Problemas encontrados en el camino

| # | Problema | Dónde | Impacto |
|---|---|---|---|
| 1 | Cola `low_priority` no está en `sidekiq.yml` | `config/sidekiq.yml` | `CleanupJob` nunca ha corrido (249 atorados desde feb). `contact_trackings` crece sin límite. **Fase 0:** job apagado (borraría seguimientos que usan las campañas). |
| 2 | Cola `knowledge_base` no está en `sidekiq.yml` | `config/sidekiq.yml` | 49 trabajos de una clase que no existe en el repo (desde dic 2025). **Fase 0:** borrados. |
| 3 | 70 % de `ContactTrackingJob` son no-ops | `ExecutePendingJob` | Trabajo desperdiciado; se vuelve espiral con atraso. |
| 4 | Recorrido completo de colas en cada reprogramación | `contact_tracking.rb:572` | O(N²) con volumen. |
| 5 | OpenAI sin timeout dentro de `with_lock` | `contact_tracking_job.rb` (~línea 290) | Conexiones de BD bloqueadas hasta 60 s. **Fase 0:** tope de 15 s. |
| 6 | Sin manejo de 429 de OpenAI | todo el bot | Respuestas degradadas sin aviso. |
| 7 | Éxito = Meta aceptó, no entregado | `contact_tracking_job.rb` | En pruebas de desarrollo, ~16 % de mensajes no entregados contados como exitosos. |
| 8 | Motivo del error no llega al seguimiento | envío de seguimiento | El mensaje sí guarda el código de Meta, pero el seguimiento solo decía "Failed to send message". **Fase 0:** el seguimiento guarda el código y detalle de Meta. |
| 9 | `Job adelantado` termina sin reprogramarse | `contact_tracking_job.rb:44-48` | Depende de `ExecutePendingJob` para recuperarse. |
| 10 | `schedule_job` traga errores | `contact_tracking.rb:565` | Seguimientos sin trabajo programado, sin aviso. |

---

## 7. Qué afecta hoy el código tal como está

**El módulo de campañas está en desarrollo y no se ha usado en producción**, así que hoy no afecta a clientes. Lo que sigue describe qué pasaría **al desplegarlo tal como está**, más dos cosas que sí ocurren ya en el servidor de desarrollo.

### 7.1 Lo que se observa ya en el servidor de desarrollo

**1. Mensajes que no llegaron y el sistema da por enviados**
- En las pruebas de los últimos 30 días, de 1,974 mensajes de seguimiento por WhatsApp, **319 no llegaron o nunca se confirmaron** (38 fallidos y 281 sin confirmar). Parte puede deberse a números de prueba.
- El seguimiento siguió como si se hubieran entregado. **Nunca se reintentó.** En producción pasaría lo mismo con clientes reales.
- Las métricas de la campaña los cuentan como enviados, así que **muestran mejores resultados que los reales**.
- Los 38 fallidos tienen el motivo en el mensaje (sobre todo ventana de 24 h cerrada y límite de marketing de Meta), pero el seguimiento no lo mostraba. Desde la Fase 0 sí.

**2. Trabajos de base de conocimiento atorados desde diciembre**
- 49 trabajos llevaban desde diciembre de 2025 en la cola `knowledge_base`, que Sidekiq no atiende.
- La clase `KnowledgeBaseArticleProcessorJob` **no existe en el repo** (ni en su historial), así que no había contenido pendiente: solo habrían fallado. Se borraron en la Fase 0.
- **En producción conviene revisar si esa cola también tiene trabajos** y borrarlos igual.
- No es del módulo de campañas.

### 7.2 Lo que no afecta hoy pero aparecería al usar campañas

| Problema | ¿Afecta hoy? | Cuándo empieza a afectar |
|---|---|---|
| 70 % de envíos son trabajos duplicados | No: cada duplicado tarda ~0 s | Cuando la cola se atrasa (ver §7.3) |
| `cancel_existing_jobs` recorre todas las colas | No: hay 571 trabajos | A partir de unos miles de seguimientos programados |
| OpenAI dentro del bloqueo y sin timeout | No: el envío más lento tardó 7.6 s | Cuando OpenAI se pone lento o caído |
| Sin manejo de 429 de OpenAI | Probablemente no | Cuando varias cuentas que comparten llave envían a la vez |
| Envíos y respuestas compiten por 10 hilos | No: el pico es de 230 entrantes por hora | Cuando un pico de entrantes coincide con una campaña |
| La limpieza (`CleanupJob`) nunca ha corrido | Mínimo: ~1,400 seguimientos | Con el tiempo, la tabla crece sin límite. Apagada a propósito en la Fase 0: hay que rediseñarla para que no borre seguimientos de campañas |

### 7.3 El umbral concreto

- En desarrollo (10 hilos, ~1.9 s por envío) el sistema despacha como máximo **~300 envíos por minuto**; en producción (20 hilos) serían **~600**, y solo si los hilos están libres (en el diagnóstico productivo estaban 20 de 20 ocupados, §3.6).
- Si en **el mismo minuto** vencen más de ~300 seguimientos, lo que no alcanzó a salir se vuelve a encolar en el minuto siguiente (`ExecutePendingJob`) y empieza la espiral de duplicados (§5.4).
- Con el límite actual de 100 contactos por campaña, basta con **que 3–4 campañas (desarrollo) o 6–7 (producción) arranquen a la misma hora** (por ejemplo, todas a las 9:00 con horario de atención) para cruzar ese umbral. **No hacen falta 500 cuentas.**

### 7.4 En resumen

- **Al desplegar tal como está:** los mensajes que no se entreguen (~16 % en las pruebas) se perderían sin aviso y las métricas lo ocultarían.
- **Para crecer:** el sistema aguanta pocas campañas simultáneas; el problema aparece desde unas pocas campañas que salen en el mismo minuto, no desde cientos de cuentas.
- Por eso conviene hacer **Fase 0 y Fase 1 antes de desplegar campañas a producción**, y **Fase 2 antes de abrirlas a muchas cuentas**.

---

## 8. ¿Soporta envío masivo con 255–500 cuentas?

**Sí, si las cuentas envían escalonadas. No, si muchas lanzan a la misma hora** (el caso común: 9:00 am o al abrir horario de atención).

| Escenario | Mensajes | Tiempo en salir | ¿Aguanta? |
|---|---|---|---|
| Pruebas actuales en desarrollo (1 cuenta) | ~30 / hora | inmediato | ✅ Sí |
| 10–20 cuentas por día, horarios distintos | 1,000–2,000 / día | minutos | ✅ Sí |
| 50 cuentas a la misma hora (100 c/u) | 5,000 | ~45–90 min | ⚠️ Con atraso; respuestas a clientes también se retrasan |
| 255 cuentas a la misma hora (100 c/u) | 25,500 | horas | ❌ No: la cola se desborda |
| 500 cuentas × 2 campañas × 1,000 | ~1,000,000 | — | ❌ No con el diseño actual |

Por qué falla con muchas cuentas a la vez:
1. **La cola crece sola** (`ExecutePendingJob`, §5.4).
2. **Todo sale a la misma hora**: con "respetar horario", lo inscrito fuera de horario se programa para el minuto exacto de apertura.
3. **Envíos y respuestas compiten** por los mismos 10 hilos (§5.3).
4. **Cada envío llama a OpenAI** (§5.2).
5. WhatsApp **no** es el problema con 100 contactos por campaña (menos que el nivel mínimo de 250), sí lo es con 1,000 o con varias campañas al día.

Con 1M de contactos además: ~1M de entradas en Redis (un trabajo programado por seguimiento), `cancel_existing_jobs` inviable, ~53 horas de envíos solo para el primer intento con 10 hilos.

---

## 9. ¿Es necesario `ExecutePendingJob`?

**Sí, es necesario como red de seguridad, pero no como funciona ahora.**

### 8.1 Por qué existe
Cada seguimiento se programa a su hora con `ContactTrackingJob.set(wait_until:)`. `ExecutePendingJob` rescata los casos en que ese trabajo se pierde:

1. `schedule_job` atrapa el error y no lo relanza (`contact_tracking.rb:565`) → seguimiento sin trabajo.
2. Un trabajo que llega antes de hora termina sin reprogramarse (`contact_tracking_job.rb:44-48`).
3. Cambios con `update_columns`, `update_all` o `insert!` no disparan `reschedule_job_if_needed`.
4. Trabajos muertos tras reintentos, Redis limpiado o trabajos borrados a mano (hoy hay 709 muertos).

Sin él, esos seguimientos se quedan congelados en "programado" sin aviso.

### 8.2 Cómo dejarlo sin riesgo (si se mantiene el diseño actual)
1. **Margen de gracia:** solo lo atrasado más de 5 min (`scheduled_for <= 5.minutes.ago`).
2. **No encolar dos veces:** marca en Redis por seguimiento con `SET NX` y vida de ~10 min.
3. **Tope por corrida:** p. ej. máximo 500 por minuto.

En la Fase 2 se reemplaza por el despachador (§13, paso 2.1–2.2).

### 8.3 `cancel_existing_jobs` puede eliminarse
`ContactTrackingJob` ya descarta lo que no corresponde (estado, adelantado, duplicado <60 s). Basta con guardar el `scheduled_for` esperado en los argumentos del trabajo y descartarlo si no coincide con el actual, en lugar de buscar y borrar trabajos viejos.

---

## 10. "Enviado" no es "entregado"

- Hoy un intento es exitoso cuando **Meta acepta la petición** y devuelve un ID.
- El webhook de estado (`delivered`, `read`, `failed`) **sí llega y sí actualiza el `Message`**, pero **nadie lo relaciona con el seguimiento ni con la campaña**.
- Resultado en pruebas de desarrollo (§3.4): 14.2 % "solo enviado" + 1.9 % "fallido" = **~16 %** contados como exitosos. Parte puede deberse a números de prueba; la proporción con clientes reales está por medir.
- A 1M de contactos ≈ **160,000 mensajes perdidos sin aviso**.

---

## 11. Comparación con Chatwoot oficial (v4.4 → v4.18)

- **Versión local:** `3.13.6` (`config/app.yml`). No tiene campañas nativas de WhatsApp.
- **Última oficial:** `v4.18.0`.

### 10.1 Cuándo llegó cada cosa

| Versión | Qué agregó |
|---|---|
| v1.15.0 | Enviar plantillas en un inbox de WhatsApp (una conversación, no masivo) |
| v4.4.0 (jul 2025) | Campañas de WhatsApp en **alpha**: plantilla aprobada a contactos por etiqueta |
| v4.14.2 | Estado de procesamiento en campañas de SMS y WhatsApp |
| v4.16.1 | Correcciones de seguridad/API: límites de velocidad, cuotas de agentes |
| v4.16.2 | Monitoreo de salud de WhatsApp, mensajería BSUID |
| v4.17.0 | Gestión de plantillas Cloud API y Twilio. **Seguimiento de entrega por destinatario [Enterprise]** |
| v4.18.0 | Campañas y llamadas para contactos solo-BSUID |

### 10.2 Cómo lo resuelven (código revisado)

- **`Whatsapp::OneoffCampaignService`** (MIT): tandas de **100** contactos con cursor por `contact.id`.
- **`Campaigns::SendWhatsappBatchJob`** (MIT): procesa una tanda y se vuelve a encolar con el siguiente cursor; al final marca la campaña `completed` con `with_lock`. Cola **`low`**.
- **`Enterprise::Whatsapp::OneoffCampaignService`** (**Enterprise**): un `campaign_recipient` por contacto con estados `queued` / `sent` / `failed` / `skipped`; guarda `source_id` y el error del proveedor; **solo procesa los `queued`** → nunca reenvía lo enviado.

Lo que **no** tienen:
- **No reintentan** (`failed` se queda así).
- **No limitan velocidad** (sin pausa, sin límite por número).
- Solo **plantilla fija**, solo **Cloud API**, audiencia solo por **etiquetas**, **sin agente IA** después.

### 10.3 Conclusión
- **No conviene actualizar** de 3.13 a 4.18 para esto: ~30 versiones sobre un fork con mucho código propio (contact tracking, casos, KBase, campañas…) → semanas de merge con riesgo alto, y el resultado es más simple que lo que ya tienen, con la parte útil detrás de licencia Enterprise.
- **Sí conviene copiar el patrón**: tandas con cursor + registro por destinatario ligado al ID de Meta. Y mejorarlo con reintentos por tipo de error, confirmación por webhook y límite por número.

---

## 12. ¿Se puede traer esa funcionalidad a esta versión?

**Sí, portando el patrón, no copiando el código.**

### 11.1 Por qué no copiar tal cual
1. **Licencia:** el registro por destinatario está en `enterprise/` (licencia Enterprise, no MIT). Solo lo de fuera de `enterprise/` se puede copiar libremente.
2. **Dependencias de v4:** `Campaign` nativo, Liquid, `TemplateProcessorService`, `AuthenticationTemplateGuard`, BSUID, `PhoneNumberNormalizationService`, `channel.last_provider_error`.
3. **Otro flujo:** allá una plantilla y se acabó; aquí seguimiento con varios intentos, IA y conversación.

### 11.2 Lo que la versión local ya tiene

| Pieza | ¿Existe en 3.13.6? |
|---|---|
| `send_template` devuelve el ID del mensaje en Meta | ✅ `app/services/whatsapp/providers/whatsapp_cloud_service.rb:19` |
| El seguimiento guarda el `Message` con ese `source_id` | ✅ `app/jobs/contact_tracking_job.rb` ("Mensaje creado en BD con source_id") |
| El webhook actualiza `message.status` (`sent`/`delivered`/`read`/`failed`) | ✅ `app/services/whatsapp/incoming_message_base_service.rb:52` |
| Guarda el código de error de Meta (`external_error = "código: título"`) | ✅ mismo archivo |
| `Message` dispara evento al actualizarse | ✅ `after_update_commit :dispatch_update_event` |
| `Message.status` enum | ✅ `progress: -1, sent: 0, delivered: 1, read: 2, failed: 3` |

### 11.3 Lo que falta construir
1. Ligar cada intento a su mensaje (tabla de entregas).
2. Escuchar el cambio de estado del mensaje y actualizar la entrega.
3. Reintentar según el tipo de error.
4. Envío por tandas con despachador y límite por número.

---

## 13. Plan por fases

### Fase 0 — Arreglos rápidos (~1 día)

**Estado: ✅ hecha el 2026-10-19.**

Independientes del resto; quitan problemas que ya existen hoy. Rama `fix/campanas_fase0` (desde `origin/develop`), commits `ac5fe9568` y `1d6477467`, **PR #87 mergeado** a develop.

**0.1 Colas que Sidekiq no atendía** — resuelto distinto a lo planeado
- **`CleanupJob` (cola `low_priority`) se apagó en lugar de activarse.** Hace `delete_all` de seguimientos completados, cancelados y fallidos de más de 90 días; aquí serían 628. Las llaves foráneas de `tracking_campaign_entries` y `case_tickets` son `ON DELETE SET NULL`, así que las entradas de campaña perderían su seguimiento y se rompería el historial.
  - En `config/schedule.yml` quedó con `status: disabled`, no se quitó: `load_from_hash` no borra de Redis los cron que ya existen, así que quitarlo lo dejaría vivo en los servidores donde ya está cargado.
  - La limpieza se rediseña más adelante para no tocar seguimientos de campañas ni de tickets.
- **`knowledge_base`:** los 49 trabajos eran de `KnowledgeBaseArticleProcessorJob`, una clase que no existe en el repo; solo podían fallar. Se borraron y no se agregó la cola.
- En el Redis de desarrollo: `low_priority` 252 → 0, `knowledge_base` 49 → 0 y el cron deshabilitado.

**0.2 Tope de tiempo en `ContactTrackingJob`**
- OpenAI: `open_timeout` 5 s y `read_timeout` 15 s (antes hasta 60 s dentro del bloqueo). Si se pasa, se envía el mensaje simple sin IA, como con cualquier otro error.
- Consulta del idioma de la plantilla a la Graph API de Meta: `timeout` 10 s.

**0.3 Motivo del error en el seguimiento**
- Cuando Meta rechaza el envío al momento (plantilla o mensaje de sesión), `last_error` del seguimiento guarda `Meta <código>: <detalle>`, por ejemplo `Meta 100: Param text cannot have new-line/tab characters or more than 4 consecutive spaces`, en lugar de "Failed to send message".
- Los rechazos que llegan después por webhook ya guardaban el código en el mensaje (§3.4); pasarlos al seguimiento es parte de la Fase 1 (paso 1.3).

**Hallazgo para la Fase 1:** cuando Meta rechaza al momento, `process_response` hace `update!` sobre el mensaje temporal (`Message.new`) y lo **inserta** como mensaje fallido sin remitente (20 casos en desarrollo), lo que además dispara `SendReplyJob`. El paso 1.2 debe evitarlo.

**Verificación:**
- ✅ Colas vacías y cron deshabilitado en desarrollo.
- ✅ Resumen del error probado con un error real de Meta guardado en la base.
- ⏳ Pendiente: reiniciar Sidekiq en desarrollo y hacer un envío fallido de prueba en un canal de WhatsApp de prueba.

**Al desplegar en producción:** reiniciar Puma y Sidekiq (el cron se apaga al cargar `schedule.yml`) y revisar si allá también hay trabajos atorados en `low_priority` y `knowledge_base` para borrarlos.

---

### Fase 1 — Entrega confirmada (~3–5 días)

**Estado: ✅ hecha el 2026-10-19.** Rama `feat/campanas_fase1_entregas`, commit `397030d1c`, **PR #88** a develop (pendiente de merge). La migración ya corrió en el servidor de desarrollo.

**Objetivo:** saber si cada mensaje llegó, reintentar solo lo que tiene sentido y nunca reenviar lo entregado.

**1.1 Migración `20261019120000_create_tracking_deliveries`** ✅

Tabla `tracking_deliveries`, un registro por cada envío real por WhatsApp:

| Campo | Para qué |
|---|---|
| `contact_tracking_id`, `tracking_campaign_id`, `account_id` | Relación con seguimiento y campaña |
| `attempt_number`, `repetition` | Qué intento era (`attempt_count + 1`) y su repetición en modo reagenda (`response_adjustments_count`) |
| `retry_count`, `next_retry_at` | Cuántas veces se reenvió este intento y, si hay reenvío programado, cuándo |
| `message_id`, `source_id` | El mensaje en Chatwoot y su ID en Meta |
| `kind` | `template` o `session` |
| `status` | `sent` → `delivered` → `read`, o `failed` / `unconfirmed` |
| `error_code`, `error_title`, `error_kind` | Código de Meta, detalle y tipo (ver 1.4) |
| `sent_at`, `delivered_at`, `read_at`, `failed_at` | Tiempos, para métricas |

- Índices: `message_id` (único), `source_id`, `(tracking_campaign_id, status)` y uno parcial por `sent_at` para los que esperan confirmación.
- Además: `tracking_campaigns.paused_reason` / `paused_at` y `contact_trackings.paused_by_campaign` (para la pausa por configuración, 1.5).
- Cambio respecto al plan: **no hay estado `queued` ni `skipped`.** El registro se crea cuando Meta responde: `sent` si aceptó, `failed` si rechazó al momento.

**1.2 Registrar el envío en `ContactTrackingJob`** ✅ (`TrackingDeliveries::Recorder`)
- **Meta acepta:** envío `sent` con su `Message` y `source_id`, tanto plantilla como mensaje de sesión.
- **Meta rechaza al momento:** envío `failed` con el código de la respuesta, y `HandleFailure` decide (1.5).
- **Bug corregido:** el proveedor hacía `update!` sobre el `Message.new` temporal cuando Meta rechazaba, así que lo **insertaba** como mensaje fallido sin `source_id`, y `SendReplyJob` lo volvía a mandar. Ahora el mensaje temporal no se guarda (`Recorder.unsaved_message`).
- Cambio respecto al plan: **no se agregó la guarda "si ya tiene entrega no se envía".** El registro se escribe dentro de la misma transacción del `with_lock`: si algo truena después de que Meta aceptó, se revierte junto con todo lo demás, así que esa guarda no protegería el caso que importa. La protección real llega con la Fase 2 (paso 2.5: sacar el envío del bloqueo). Contra los trabajos duplicados sigue la guarda de 60 s que ya existía.
- Solo se registran los envíos por WhatsApp. Los otros canales siguen igual.

**1.3 Escuchar los cambios de estado del mensaje** ✅ (concern `TrackingDeliverySync` en `Message`)
- `after_update_commit` cuando cambia `status` de un mensaje saliente: si es de un seguimiento, se actualiza su envío. Si quedó `failed`, se encola `TrackingDeliveries::FailureJob`, que bloquea el seguimiento y aplica `HandleFailure`.
- No se toca el procesamiento de webhooks del core.
- **El estado solo avanza:** un `delivered` que llega después de un `read` no lo pisa, y un `failed` tardío no deshace una entrega confirmada. Un `delivered` que llega después de "sin confirmar" sí se registra.

**1.4 Clasificar los errores de Meta** ✅ (`TrackingDeliveries::ErrorClassifier`)

| Tipo | Códigos | Qué se hace |
|---|---|---|
| **Temporal** | 1, 2, 4, 80007, 130429, 131000, 131016, 131048, 131056, 132069, 133004 | Reenviar el mismo intento con espera |
| **Marketing** | 131049 | Un solo reenvío a las 24 h |
| **Permanente** | 131026, 131047, 100, 130472 y **cualquier código desconocido** | No se reenvía (reintentar a ciegas puede duplicar) |
| ↳ contacto inalcanzable | 131021, 131026, 131050 | Además, el seguimiento queda **fallido** con el motivo |
| **Configuración** | 0, 3, 10, 190, 200–299, 368, 131031, 131037, 131042, 131045, 133010, 132000, 132001, 132005, 132007, 132012, 132015, 132016, 132068 | **Pausar la campaña** con el motivo |

**1.5 Política de reintento** ✅ (`TrackingDeliveries::HandleFailure`)
- **Reintentar = regresar el seguimiento al intento que falló y reprogramarlo:** `attempt_count` y la repetición vuelven a como estaban antes del envío, y `scheduled_for` pasa a la hora del reintento. El envío normal lo vuelve a mandar y decide de nuevo entre plantilla y sesión según la ventana de 24 h. Así no hay un segundo camino de envío.
- **Temporal:** a los 5 min, 30 min y 2 h; máximo 3. **Marketing:** una vez a las 24 h. Después se trata como permanente.
- **Solo se reintenta si** es el último envío del seguimiento (no hay uno más nuevo) y el contacto no respondió después del envío. Por webhook, además, el seguimiento debe estar `pending`, `scheduled` o `completed`. Si falló el último intento, el seguimiento se reabre.
- **Permanente:** rechazo al momento → seguimiento `failed` con el motivo (como antes). Por webhook → el seguimiento sigue su curso, con el motivo en `last_error`, porque el siguiente intento puede ir por otro camino.
- **Configuración (decisión 2026-10-19: pausar y agregar botón Reanudar):**
  - la campaña pasa a **Pausada** con el motivo (`TrackingCampaigns::Pause`) y deja de aceptar inscripciones;
  - sus seguimientos **no se pausan todos de golpe**: cada uno se pausa (`paused_by_campaign`) cuando le toca enviar, para no recorrer las colas de Sidekiq por cada uno;
  - el seguimiento del envío fallido se regresa al intento, para que al reanudar lo vuelva a mandar;
  - el detalle muestra un aviso con el motivo y el botón **"Reanudar campaña"** (`POST tracking_campaigns/:id/resume`). `TrackingCampaigns::ResumeJob` reanuda solo los que pausó la campaña, a partir de 1 minuto y escalonados 1 s;
  - si la ventana terminó mientras estaba pausada, queda Finalizada.
- **Entregado o leído:** el seguimiento sigue su curso normal. Nunca se reenvía.
- Límite conocido: en modo reagenda (repeticiones), si el reintento cae justo cuando el seguimiento ya había pasado al siguiente intento, la marca de modo reagenda puede perderse y la siguiente vuelta cuenta como intento normal.

**1.6 Enviados que nunca se confirman** ✅ (`TrackingDeliveries::UnconfirmedJob`, cron `17 * * * *`)
- Envíos con más de 24 h en `sent` → `unconfirmed`. **No se reenvían.** Se cuentan aparte.

**1.7 Métricas de la campaña** ✅
- `TrackingCampaigns::DeliveryStats` (sale del controlador): por prospecto, el **último envío registrado** del seguimiento → Entregados, Esperando confirmación, Sin confirmar (+24 h), En reintento, Error de entrega, más los **5 motivos de fallo más comunes** con su código de Meta.
- Los seguimientos sin envíos registrados (de antes de la Fase 1) siguen usando el último mensaje saliente de su conversación.
- Lista de prospectos: `delivery_status`, `delivery_error` y `delivery_retry_at`. Los filtros por grupo coinciden con los números, y el tooltip dice el motivo y cuándo es el reintento.
- Listado de campañas: el estado Pausada lleva ⚠️ y el motivo en el tooltip.
- Esto corrige además el hallazgo de que "Entregados" tomaba el último saliente de la conversación aunque fuera de antes de la campaña (solo para seguimientos nuevos).

**1.8 Pruebas** ✅
- 31 specs nuevos:
  - `tracking_delivery_spec` (orden de estados, lectura de errores, clasificador);
  - `tracking_delivery_sync_spec` (webhook → envío, `UnconfirmedJob`);
  - `handle_failure_spec` (reintentos, respuesta del contacto, envío más nuevo, marketing, configuración, inalcanzable, rechazo al momento);
  - `resume_spec` (pausa, reanudación, ventana terminada, guarda del job);
  - `contact_tracking_job_deliveries_spec` (Meta simulada con webmock: aceptado, temporal sin guardar el mensaje rechazado, permanente);
  - 3 en el spec del controlador (entrega registrada y endpoint de reanudar).
- 94 specs del módulo en verde. Vitest de `contactTrackings` en verde.
- ⏳ **Pendiente: prueba real** en un canal de WhatsApp de prueba, con un número válido y uno inválido (para forzar 131026).

**Al desplegar:** `rails db:migrate`, reiniciar Puma y Sidekiq (carga el cron `tracking_deliveries_unconfirmed`) y hacer la prueba real.

**Resultado de la Fase 1:** se sabe exactamente qué llegó, qué no y por qué; lo temporal se reintenta solo, lo entregado nunca se repite y un error de configuración detiene la campaña en vez de quemar todos sus envíos. **Todavía no resuelve el volumen.**

---

### Fase 2 — Volumen (~1–2 semanas, con prueba de carga)

**Objetivo:** soportar ~1M de contactos repartidos, sin cuellos de botella y sin que una cuenta frene a las demás.

**2.1 Despachador en lugar de un trabajo programado por seguimiento**
- `TrackingCampaigns::DispatchJob` cada 15–30 s.
- Toma un lote de vencidos con `FOR UPDATE SKIP LOCKED` (dos procesos nunca toman el mismo), los pasa a un estado nuevo `sending` con `claimed_at` y encola su envío en tandas.
- Los que lleven >10 min en `sending` se liberan solos (proceso que murió a medias).

**2.2 Quitar lo que deja de hacer falta**
- `ContactTrackingJob.set(wait_until:)` por seguimiento (sería ~1M de entradas en Redis).
- `cancel_existing_jobs` (recorre todas las colas en cada reprogramación).
- `ExecutePendingJob` (el despachador cumple la función de red de seguridad).

**2.3 Límite de velocidad por número (WhatsApp)**
- Límite en Redis por inbox, p. ej. 20 mensajes/s por número (Meta permite hasta 80).
- **Tope diario según el nivel de Meta** (250 / 1K / 10K / 100K por 24 h): consultado en la Graph API, guardado en el canal; el despachador no lo rebasa y lo que sobra pasa al siguiente horario disponible.

**2.4 Reparto justo entre cuentas**
- Por vuelta, máximo K seguimientos por inbox, por turnos. Una cuenta con 2,000 envíos no tapa a otra con 50.

**2.5 Sacar las llamadas externas del bloqueo de BD**
- El bloqueo solo para tomar el seguimiento y cambiar su estado.
- OpenAI y envío a Meta fuera del bloqueo, con la protección contra duplicados del paso 1.2.

**2.6 Primer mensaje con plantilla y sin IA**
- Para contactos fríos WhatsApp solo permite plantillas: parámetros llenados con datos del contacto, sin OpenAI.
- La IA entra cuando el cliente responde. Configurable por Agente IA.
- Evita ~1M de llamadas a OpenAI y su costo.

**2.7 Subir el límite por campaña de 100 a 1,000**
- Cambiar `MAX_BULK_ASSIGN` y revisar si la pantalla tiene su propio límite de 100.
- `BulkAssignJob` por tandas de 100 con cursor (como la versión oficial): un reinicio de Sidekiq no lo corta a medias y al reanudar no repite contactos.
- **Crear la conversación al enviar, no al inscribir:** evita 1M de conversaciones vacías por adelantado y posibles notificaciones de asignación (por verificar).

**2.8 Infraestructura**
- Proceso de Sidekiq dedicado a una cola `campaign_dispatch`, para que los envíos no compitan con las respuestas.
- PgBouncer frente a Postgres, o subir `max_connections` (hoy 72 de 100).
- Separar los entornos de desarrollo (`luis`, `mariana`, `jose_luis`) del servidor de producción, o al menos limitarles CPU.

**2.9 Prueba de carga en la instancia de `luis`**
- Meta y OpenAI simulados con latencias reales (~1–2 s).
- Escenarios:
  - 50 cuentas a la misma hora;
  - 500 cuentas × 2 campañas × 1,000 contactos repartidas en el día;
  - pico de respuestas entrantes durante el envío.
- Medir: envíos por minuto, tiempo de respuesta a clientes, memoria de Redis, conexiones de Postgres.

**2.10 Despliegue gradual**
- Bandera por cuenta: primero la 568, luego unas pocas, después todas.
- Los seguimientos en curso al desplegar terminan con el mecanismo viejo; los nuevos usan el despachador.

**Resultado de la Fase 2:** el volumen pasa a ser cuestión de capacidad (más hilos en el worker de envíos), no de diseño.

---

## 14. Resumen de fases

| Fase | Entrega | Esfuerzo | Riesgo |
|---|---|---|---|
| 0 ✅ | Colas atoradas, timeout de OpenAI, motivo de error | ~1 día (hecha 2026-10-19) | Bajo |
| 1 ✅ | Entrega confirmada, reintento por tipo de error, sin reenvíos, pausa y reanudación por error de configuración | ~3–5 días (hecha 2026-10-19, PR #88) | Bajo–medio (se monta sobre lo actual) |
| 2 | Despachador, límites por número, 1,000 por campaña, infraestructura | ~1–2 semanas | Medio (cambia cómo salen los envíos; lleva prueba de carga y bandera por cuenta) |

Tiempos estimados; la Fase 2 puede moverse según la prueba de carga.

---

## 15. Pendientes y observaciones aparte

- **Subir el límite a 1,000 por campaña:** la revisión detallada de su impacto en el código actual quedó pendiente (se interrumpió); lo conocido está en §5.9 y §13 paso 2.7.
- **Cambios sin commitear arrastrados a la rama:** 19 archivos (anotaciones de modelos regeneradas, `TicketDetail.vue`, manifest de sprockets). Si vienen de `wintook_dev` pueden traer tablas de Laravel → **no commitearlos** en esta rama.
- **Token de GitHub en la URL del remoto de git:** visible con `git remote -v` y en `.git/config`. Recomendado revocarlo, crear otro y guardarlo con un credential helper.
- **Trabajos muertos (709):** varios son de módulos no relacionados (`CheckNewVersionsJob`, `CalendarAlertJob`, `WhatsappEventsJob`); conviene revisarlos aparte.
- **Backups de `wintook_dev`:** siguen sin estar activos.

---

## 16. Fuentes

- Releases de Chatwoot: https://github.com/chatwoot/chatwoot/releases
- v4.17.0: https://github.com/chatwoot/chatwoot/releases/tag/v4.17.0
- Blog "WhatsApp campaigns and more" (v4.4.0): https://www.chatwoot.com/blog/whatsapp-campaigns-and-workflow-improvements
- `oneoff_campaign_service.rb`: https://raw.githubusercontent.com/chatwoot/chatwoot/develop/app/services/whatsapp/oneoff_campaign_service.rb
- `send_whatsapp_batch_job.rb`: https://raw.githubusercontent.com/chatwoot/chatwoot/develop/app/jobs/campaigns/send_whatsapp_batch_job.rb
- Enterprise `oneoff_campaign_service.rb`: https://raw.githubusercontent.com/chatwoot/chatwoot/develop/enterprise/app/services/enterprise/whatsapp/oneoff_campaign_service.rb
