# Plan — Módulo de Licencias de Plataforma (por cuenta)

> **Estado:** PLAN (solo revisión, sin implementar). Rama `feat/licencias`.
> **Objetivo de negocio:** Wintook **licencia el uso de la plataforma (Chatwoot) a cada
> cuenta**. Cada cuenta nace en **demo** (15 días / 2 agentes por defecto) y luego pasa a
> **licencias de pago por tiempo + nº de agentes** (30 días/5, 180 días/10, etc.). El nº de
> agentes es un **tope real** (no se pueden agregar más) y se **avisa antes del vencimiento**;
> al vencer se **suspende la cuenta**.

---

## 0. Hallazgo clave — el enforcement YA existe en Chatwoot

No hay que inventar la parte delicada (bloquear el alta de agentes ni suspender):

```
Alta de agente
  AgentsController#create ──before_action──▶ validate_limit
        └─ can_add_agent?  →  Current.account.usage_limits[:agents] - agents.count > 0
                                              │
             si NO alcanza  ──▶ 402 "Account limit exceeded. Please purchase more licenses"

Acceso a cuenta suspendida
  ensure_current_account_helper.rb:11
        └─ render_unauthorized('Account is suspended') unless account.active?
  Account enum status: { active: 0, suspended: 1 }
```

**Implicación de diseño (todo el módulo se apoya aquí):**
1. Basta con que **`account.usage_limits[:agents]` devuelva el `max_agents` de la licencia
   activa** → el tope de agentes queda enforced sin tocar el controlador ni la UI de agentes.
2. **Vencer = `account.update!(status: :suspended)`** → el acceso ya se bloquea solo.

> Hoy `usage_limits` lo resuelve `Enterprise::Account#agent_limits`, que lee
> `accounts.limits['agents']` (o cae a `max_limit` = 100.000 ≈ ilimitado). Solo hay que
> hacer que esa fuente sea **la licencia activa**.

---

## 1. Alcance

### En alcance (v1)
- **Catálogo de planes personalizables** (`license_plans`): cada plan con **nombre**,
  **duración (días)**, **nº de agentes por defecto** y **set de canales/funciones habilitados**
  (feature flags); uno marcado como demo de registro.
- **Entitlements por plan (canales + funciones):** el plan define qué canales
  (WhatsApp/Telegram/FB/…) y funciones (campañas/reportes/KB/…) puede usar la cuenta,
  aplicándolos vía los feature flags nativos al activar la licencia (ver §13).
- **Licencia por cuenta** (`account_licenses`), con **historial**; la efectiva = la **activa**.
  Al emitir, se elige un plan (precarga nombre/días/agentes) y se puede ajustar; los valores
  quedan **copiados** en la licencia (snapshot).
- **El licenciamiento aplica solo a cuentas CON licencia.** Cuentas **nuevas** nacen con
  **demo** automática (entran desde el día 1). Cuentas **existentes** quedan **"fuera de
  licencia"** (sin fila en `account_licenses`) y se comportan **como hoy** (sin tope, sin
  vencimiento, sin suspensión) **hasta que un `SuperAdmin` les asigne una licencia**.
- **Demo automática** solo para cuentas nuevas (usa el plan `signup_default`, ej. 15d/2).
- **Dashboard de Licencias (`SuperAdmin`)** — superficie principal: KPIs (activas, por vencer
  7/14/30/60d, vencidas, demo, sin licencia, utilización de agentes, conversión demo→pago),
  **gráficos nativos** (doughnut de estado, curva de vencimientos, cuentas por plan, heatmap
  de calendario) y **tabla filtrable con paginado** (VeTable) con acciones
  **Activar / Renovar / Gestionar** por cuenta. Todo con componentes nativos de Chatwoot.
  Incluye la vista cruzada "sin licencia" y la referencia legacy (🟢/🔴).
- **Upgrade demo → pago** y **renovación** desde el **dashboard normal**, en la página
  `settings/license`, con controles visibles **solo para usuarios `SuperAdmin` de Wintook**:
  elegir **días** + **nº de agentes** (presets 30/5, 180/10 o personalizado). El admin de la
  cuenta cliente ve la misma página en **solo lectura**.
- **Licencias encadenadas (pago por adelantado):** si se paga estando aún vigente la actual,
  la nueva queda **programada** (`scheduled`) y **arranca al terminar la vigente** — sin cortar
  el servicio. Se puede **encolar** más de un periodo (cola: 1 activa + N programadas).
- **Enforcement del tope de agentes** vía `usage_limits[:agents]` = `max_agents` de la licencia.
  Bajar de plan / vencer **solo bloquea agregar nuevos** (los agentes actuales se quedan).
- **Avisos 10 y 5 días antes** del vencimiento: **correo a los admins de la cuenta** +
  **banner en el dashboard** de la cuenta.
- **Al vencer: suspender la cuenta** (`accounts.status: suspended`) → acceso bloqueado hasta renovar.
- **Vista de solo lectura** dentro de la cuenta (admin ve su licencia: tipo, vence, agentes
  usados/tope). La **administración** (asignar/cambiar) es **solo super admin**.

### Fuera de alcance (v1 — futuro)
- Cobros/facturación / pasarela de pago (solo marcamos periodo y tope).
- Auto-renovación con cobro. Portal de autoservicio para que la cuenta se renueve sola.
- Límites de otros recursos (inboxes, contactos, mensajes) — hoy solo **agentes** y **tiempo**.
- Periodo de gracia post-vencimiento (se decidió **suspender directo**; se puede sumar luego).
- Desactivar agentes sobrantes automáticamente (se decidió **solo bloquear nuevos**).

---

## 2. Modelo de datos

```
                         ┌──────────────────────────────┐
                         │           accounts           │
                         │  status: active | suspended   │  ← se suspende al vencer
                         └──────────────┬───────────────┘
                                        │ 1
                                        │ N (historial; 1 activa)
        ┌───────────────────────────────▼───────────────────────────────┐
        │                       account_licenses                         │
        ├────────────────────────────────────────────────────────────────┤
        │ id                bigint  PK                                   │
        │ account_id        bigint  FK → accounts       (not null)       │
        │ license_plan_id   bigint  FK → license_plans  (nullable)       │  plan de origen (opcional)
        │ created_by_id     bigint  FK → users          (nullable)       │  super admin (null = demo auto)
        │ name              string                                       │  ← SNAPSHOT del nombre del plan
        │ license_type      integer default 0 (enum: demo | paid)        │
        │ status            integer default 0 (enum: active|scheduled|expired|cancelled) │
        │ max_agents        integer  not null                            │  ← TOPE (snapshot, editable)
        │ duration_days     integer  not null                            │  fuente del periodo (snapshot)
        │ starts_at         datetime not null                            │
        │ expires_at        datetime not null   (= starts_at + duration) │
        │ reminded_at       jsonb  default '{}'  {"10": ts, "5": ts}     │  anti-spam de avisos
        │ notes             text                                         │
        │ metadata          jsonb  default '{}'                          │
        │ created_at / updated_at                                        │
        └───────────────────────────────▲────────────────────────────────┘
                                         │ N
                                         │ 1
        ┌────────────────────────────────┴───────────────────────────────┐
        │                        license_plans                           │  (CATÁLOGO personalizable)
        ├────────────────────────────────────────────────────────────────┤
        │ id                 bigint  PK                                  │
        │ name               string  not null   (ej. "Plan Básico")      │  ← nombre del periodo/plan
        │ duration_days      integer not null   (ej. 30, 180)            │  ← periodo personalizable
        │ default_max_agents integer not null   (ej. 5)                  │  ← agentes por defecto
        │ features           jsonb default '[]'                          │  ← canales/funciones habilitados
        │                    ["channel_whatsapp","channel_telegram",      │     (nombres de features.yml)
        │                     "campaigns","reports", …]                   │
        │ license_type       integer default 1  (demo | paid)            │
        │ signup_default     boolean default false                       │  ← el que se asigna al registrar (demo)
        │ active             boolean default true                        │  ← visible al emitir
        │ position           integer default 0                           │  orden en la UI
        │ notes              text                                        │
        │ created_at / updated_at                                        │
        └────────────────────────────────────────────────────────────────┘

Enums
─────
license_type:  0 demo · 1 paid
status:        0 active · 1 scheduled · 2 expired · 3 cancelled
               (scheduled = pagada por adelantado, en cola; cancelled = reemplazada por upgrade)

Índices
───────
account_licenses:
  (account_id)
  (account_id, status)                  partial UNIQUE WHERE status = 0 (active)  ← 1 activa por cuenta
  (account_id, starts_at)               ← ordenar la cola de programadas
  (status, expires_at)                  ← barrido del job de vencimientos
  (license_plan_id)
license_plans:
  (active, position)                    ← listar planes al emitir
  partial UNIQUE WHERE signup_default   ← solo UN plan default de registro (demo)

Regla de "una activa + cola de programadas"
───────────────────────────────────────────
· Efectiva de la cuenta = la única con `status = active`.
· Al emitir un UPGRADE inmediato (p. ej. demo→pago ya): la activa anterior → `cancelled`
  y la nueva queda `active` (empieza hoy).
· Al PAGAR POR ADELANTADO estando vigente: la nueva queda `scheduled` con
  `starts_at = expires_at de la última licencia de la cola` (activa o última programada) y
  `expires_at = starts_at + duration_days`. Se pueden encolar varias (periodos consecutivos).
· Cuando la activa vence, el job PROMUEVE la siguiente `scheduled` (menor `starts_at`) a
  `active` en vez de suspender (ver §5).
```

**Notas de diseño**
- Se calca el estilo del repo: `status`/`license_type` como **enum entero**, `metadata` jsonb
  not null default `{}`.
- `duration_days` es la **fuente** del periodo; `expires_at` se calcula al emitir/renovar
  (6 meses = `180` días, "en días" como pediste).
- Sin columna aparte de "current": la activa es el único registro con `status = active`
  (garantizado por el índice único parcial).
- **`license_plans` = plantillas personalizables** (nombre + días + agentes por defecto). Al
  emitir, se **copia** (snapshot) `name` / `max_agents` / `duration_days` a `account_licenses`.
  Así, si luego editas o borras un plan, las licencias ya emitidas **no cambian** (conservan
  sus valores). `license_plan_id` es solo trazabilidad (nullable).
- **Demo = un plan** con `signup_default = true` (p. ej. "Demo" 15d/2). Editas la demo desde el
  mismo catálogo. Solo puede haber uno (índice único parcial).

---

## 3. Enforcement del tope de agentes (wiring)

```
account.usage_limits[:agents]
        │
        ▼
Enterprise::Account#agent_limits   (se modifica para preferir la licencia)
        │
        ├─ NO tiene licencia (fuera de licencia)  →  comportamiento actual (max_limit / limits)
        │                                             = cuenta NO gestionada, sin tope nuestro
        ├─ tiene licencia activa y vigente         →  license.max_agents
        └─ licencia vencida                        →  0 (bloquea nuevos; existentes quedan)
                                                       (aunque de todas formas se suspende, §5)

Efecto (sin tocar AgentsController ni la UI):
  · cuenta SIN licencia (existente)  → como hoy, sin límite nuestro
  · cuenta demo (2)   → al intentar el 3er agente: 402 "purchase more licenses"
  · plan 5 agentes    → topa en 5
  · bajar de 5 a 2     → NO expulsa; simplemente ya no deja agregar hasta estar <2
```

- Se añade a `Account` un helper `current_license` (concern `AccountLicensable`).
- Se ajusta **una sola** fuente (`agent_limits`) para leer `current_license&.max_agents`.
  Mínimo y reversible; si el módulo se desactiva (§7 flag global), vuelve al comportamiento actual.

### Relación con los campos existentes de `accounts` (reutilizar vs. descartar)

```
accounts.limits               jsonb  {agents, inboxes}   → REUTILIZAR (canal de enforcement)
accounts.status               int    active|suspended     → REUTILIZAR (suspender al vencer)
accounts.custom_attributes    jsonb
   ├─ plan_name               → MUERTO (billing Stripe cloud; ya no aplica)
   └─ subscribed_quantity     → MUERTO y ESTORBA (ver precedencia abajo)
accounts.feature_flags        bigint → sin relación (features opt-in por cuenta)
```

- `plan_name` / `subscribed_quantity` **solo los escriben** los servicios de Stripe
  (`enterprise/app/services/enterprise/billing/*`). Sin ese billing corriendo, están vacíos.
- **Precedencia a corregir:** hoy `agent_limits = subscribed_quantity || limits['agents']`,
  es decir `subscribed_quantity` **gana**. El nuevo orden debe ser:
  ```
  current_license&.max_agents  ||  subscribed_quantity  ||  limits['agents']  ||  fallback
  ```
  (la licencia primero; los campos Stripe quedan como cola muerta).
- **`account_licenses` es la fuente de verdad**; opcionalmente se **sincroniza**
  `limits['agents'] = current_license.max_agents` al emitir/promover, para que cualquier
  código legado que lea `limits` siga coherente. Sin duplicar lógica: un solo write en el service.
- La página `settings/billing` (lee `plan_name`/`subscribed_quantity`) queda **obsoleta**:
  ocultarla del menú o dejarla sin uso (decisión menor, no bloquea el módulo).
- **No** se agregan columnas de licencia a `accounts` (no caben historial ni cola) → tabla
  dedicada `account_licenses` (§2).

---

## 4. Ciclo de vida

```
   Registro de cuenta
        │  AccountBuilder#create_account  (o Account after_create, guardado)
        ▼
   ┌─────────┐   upgrade inmediato (super admin)  ┌──────────┐
   │  DEMO   │ ─────────────────────────────────▶ │  ACTIVE   │
   │ 15d/2   │   (activa anterior → cancelled)     │ paid 30/5 │
   └────┬────┘                                     └────┬──────┘
        │                                               │ pago por adelantado (vigente)
        │                                               ▼
        │                                       ┌──────────────┐   cola (N periodos)
        │                                       │  SCHEDULED    │◀── starts_at = expires_at
        │                                       │ inicia al fin │    de la última en cola
        │                                       └──────┬────────┘
        │  vence (job)                                  │  la activa vence (job)
        ▼                                               ▼
   ┌────────────────────────────┐          ┌───────────────────────────────┐
   │ ¿hay SCHEDULED en cola?     │          │ activa → EXPIRED                │
   │   sí → promover a ACTIVE     │◀────────│ ¿siguiente SCHEDULED?           │
   │   no → EXPIRED + suspend acct│          │   sí → esa pasa a ACTIVE (sigue)│
   └────────────────────────────┘          │   no → suspender la cuenta      │
                                            └───────────────────────────────┘

Transiciones
────────────
  demo automática (registro) : copia el plan signup_default (name/días/agentes) → active
  emitir/upgrade (inmediato) : elige plan del catálogo → nueva active, cancela la anterior,
                               expires_at = hoy + días (valores copiados del plan, editables)
  pago por adelantado        : nueva SCHEDULED, starts_at = fin de la última en cola
  renovar cuenta vencida     : nueva active hoy + account.status = active (reactiva)
  expirar (job)              : activa → expired; promueve la siguiente scheduled a active;
                               si no hay cola → account.update!(status: :suspended)
```

---

## 5. Avisos + vencimiento (job + mailer + banner)

```
Sidekiq-cron (diario, p. ej. 08:00)  →  LicenseExpiryScanJob
        │   (SOLO cuentas con licencia; las "fuera de licencia" se ignoran por completo)
        │
        ├── licencia active con expires_at en {10, 5} días  y reminded_at["N"] vacío
        │        └─▶ LicenseNotificationJob(license, days_left)
        │                ├─ LicenseMailer.expiring → correo a los ADMINS de la cuenta
        │                └─ set license.reminded_at["N"] = now   (anti-spam)
        │
        └── licencia active con expires_at < ahora
                 └─▶ license.update!(status: :expired)
                     ¿hay siguiente `scheduled` (menor starts_at)?
                        SÍ → next.update!(status: :active)       ← se activa sola, sin cortar
                             (nota: puede recalcular starts_at = now si hubo desfase)
                             LicenseMailer.activated → "tu nuevo periodo inició"
                        NO → account.update!(status: :suspended) ← bloquea acceso (ya existe)
                             LicenseMailer.expired → correo a los admins

Banner en el dashboard (cuenta)
───────────────────────────────
El payload de la cuenta expone un resumen de licencia (jbuilder):
   { license: { type, status, expires_at, days_left, max_agents, agents_used,
                next: { starts_at, expires_at, max_agents } | null } }
El front muestra banner cuando days_left ≤ 10:
   · con licencia programada  → "Tu licencia vence en N días; ya tienes un periodo
                                 pagado que inicia el DD/MM (renovación automática)."
   · sin licencia programada  → "Tu licencia vence en N días. Contacta a soporte para renovar."
```

- Reusa el patrón ya presente (`case_collaborator_notification_job` + `_mailer` + vistas
  en `app/views/mailers/…`).
- Destinatarios: **admins de la cuenta** (rol administrator) + **banner** (no correo a Wintook).

---

## 6. Administración — desde el dashboard, solo `SuperAdmin` de Wintook

Se gestiona en la **misma página** de settings de licencia (`settings/license`), NO en un panel
aparte. La diferencia la marca **quién** está logueado:

```
Chatwoot distingue dos niveles:
  · SuperAdmin  (modelo SuperAdmin < User, columna type)  → personal de WINTOOK
  · account_user role administrator                        → admin de la CUENTA cliente

Página  accounts/:accountId/settings/license
  ├─ admin de la cuenta        → SOLO LECTURA (estado, vence, agentes, próximo periodo)
  └─ usuario SuperAdmin        → MISMA vista + panel de GESTIÓN:
        [Activar / definir agentes] [Emitir pago] [Renovar] [Programar (cola)] [Cancelar programada]
        elegir PLAN del catálogo (precarga nombre + días + agentes) y ajustar si hace falta
        al emitir estando vigente: [Iniciar ya (upgrade)] vs [Programar al vencer (cola)]

Catálogo de planes (personalizable, solo SuperAdmin)
  Página aparte (o sección): CRUD de license_plans
     nombre · duración (días) · agentes por defecto · tipo (demo/paid) · activo · orden
     marcar UNO como "por defecto al registrar" (la demo)
  Estos planes son los que aparecen al emitir una licencia a una cuenta.

Vista cruzada de cuentas (solo SuperAdmin) — para "fuera de licencia" + agregar
  Listado de TODAS las cuentas con su estado de licencia:
     cuenta · estado(● con licencia / ○ sin licencia / ▲ por vencer / ✕ vencida) ·
     plan · agentes(usados/tope) · vence · [Agregar licencia] / [Gestionar]
     + REFERENCIA del sistema anterior (solo lectura, ver §12):
        licencia vieja: fechas · agentes · 🟢 vigente / 🔴 vencida
  Filtro rápido: "sin licencia" → cuentas existentes que aún no entran al sistema
  Acción "Agregar licencia": elige plan del catálogo (puede venir PRE-LLENADO con la
     referencia vieja) → crea account_license NUEVA (entra a enforcement + notificaciones).
     NO se importa la vieja; solo informa la decisión (flujo tipo "renovar/activar").
  Nota: es una vista NO scopeada a una cuenta → va en área SuperAdmin (ruta propia, o el
     listado de Accounts de /super_admin con columna + filtro de licencia). Reusa LicenseIssueService.

Visibilidad del LINK en el menú de Configuraciones
  · "Licencia" (solo lectura)      → visible para administrator
  · controles de gestión           → renderizados SOLO si current_user es SuperAdmin
    (el front lee un flag is_super_admin del payload del usuario actual)
```

**Seguridad (imprescindible):** los endpoints de escritura (emitir/renovar/programar/definir
agentes) exigen en la **policy** que `current_user.is_a?(SuperAdmin)`. Un `administrator` de la
cuenta **no** puede modificar su propia licencia (si no, se auto-asigna agentes ilimitados).
El `SuperAdmin` debe ser miembro de la cuenta (account_user) para entrar a su dashboard; la
policy suma la verificación de tipo.

Piezas:
- `app/controllers/api/v1/accounts/licenses_controller.rb` — index/show (lectura, admin) +
  create/update/transition (escritura, **solo SuperAdmin** vía policy).
- `app/policies/license_policy.rb` — lectura: administrator; escritura: `user.is_a?(SuperAdmin)`.
- payload del usuario actual + `is_super_admin` para gating del link en el front.

Opcional (v2): recurso **Administrate** en `/super_admin` (`account_license_dashboard.rb`) como
vista CRUZADA de todas las cuentas/licencias, para reportes; no es la vía principal de gestión.

---

## 7. Backend — piezas Ruby

```
db/migrate/ …_create_license_plans.rb             catálogo personalizable + seed "Demo 15d/2"
db/migrate/ …_create_account_licenses.rb
db/migrate/ …_backfill_account_licenses.rb        (o rake task; ver §9)
app/models/license_plan.rb                        catálogo (name, duration_days, default_max_agents)
app/models/account_license.rb                     enums, validaciones, scopes
app/models/concerns/account_licensable.rb         current_license, after_create demo,
                                                  override de usage_limits/agent_limits
enterprise/app/models/enterprise/account.rb       agent_limits ← current_license.max_agents
app/services/license_issue_service.rb             emitir/upgrade/renovar (cancela anterior, recalcula)
app/services/license_dashboard_service.rb         métricas agregadas (KPIs + series de gráficos)
app/services/legacy_license_reference.rb          lectura defensiva de columnas viejas (§12)
app/controllers/.../licenses/dashboard_controller  endpoint métricas (solo SuperAdmin)
app/jobs/license_expiry_scan_job.rb               barrido diario
app/jobs/license_notification_job.rb              envía aviso + set reminded_at
app/mailers/license_mailer.rb  + vistas           expiring / expired
config/sidekiq schedule                           + LicenseExpiryScanJob (diario)
app/builders/account_builder.rb                   crear demo al registrar (o after_create)
app/views/.../accounts/*.json.jbuilder            + resumen de licencia (banner)
```

Config global (sin feature flag por cuenta porque aplica a TODAS):
```
LICENSE_ENFORCEMENT_ENABLED   (default false → rollout seguro; on = enforce + suspender)
```
> Los defaults de la demo (15 días / 2 agentes) NO van en env: viven en el **plan marcado
> `signup_default`** del catálogo `license_plans` (editable desde la UI). El seed inicial crea
> ese plan "Demo 15d/2"; luego se edita ahí.
> Nota: NO es un feature flag de `features.yml` (esos son opt-in por cuenta). El enforcement
> es infra global; se controla por InstallationConfig/env para desplegar sin romper cuentas.

---

## 8. Frontend — Dashboard de Licencias (SuperAdmin) + vista de cuenta

> No es solo un panel de control: es un **DASHBOARD** con métricas, gráficos y una tabla
> filtrable. Todo con **componentes nativos de Chatwoot** (cero librerías nuevas).

### 8.1 Componentes nativos que se reutilizan
```
Gráficos     chart.js + vue-chartjs → woot-bar (BarChart), HorizontalBarChart,
             DoughnutChart, + Heatmap.vue (calendario tipo mapa de calor)
Tarjetas     MetricCard.vue / ReportMetricCard.vue (las del Overview de reportes)
Molde página LiveReports.vue / ReportContainer.vue (tarjetas + gráficos + filtros)
Tabla        VeTable + paginado nativo (como gestorTickets/Index.vue, contactTrackings)
Filtros      ReportFilters.vue / FilterSelector.vue · date pickers nativos
```

### 8.2 Dashboard de Licencias  (ruta SuperAdmin, no scopeada a una cuenta)
```
┌───────────────────────────────────────────────────────────────────────────┐
│  Licencias · Dashboard                         [7d] [14d] [30d] [60d]  ⟳    │  chips rápidos "por vencer"
├───────────────────────────────────────────────────────────────────────────┤
│  KPIs (MetricCard):                                                         │
│  ┌─Activas─┐ ┌─Por vencer─┐ ┌─Vencidas─┐ ┌─En demo─┐ ┌─Sin licencia─┐        │
│  │  128    │ │   9 (≤7d)  │ │    4     │ │   17    │ │     23        │        │
│  └─────────┘ └────────────┘ └──────────┘ └─────────┘ └──────────────┘        │
│  ┌─Agentes licenciados─┐ ┌─Utilización─┐ ┌─Conversión demo→pago─┐            │
│  │  640 / 512 usados    │ │    80%      │ │        62%           │            │
│  └──────────────────────┘ └─────────────┘ └──────────────────────┘            │
├───────────────────────────────────────────────────────────────────────────┤
│  Gráficos:                                                                  │
│  ┌── Doughnut: estado ──┐  ┌── Bar: curva de vencimientos (próx. 8 sem) ──┐  │
│  │ activa/demo/porvencer│  │  ▁▂▅█▃▂▁▁  (cuántas vencen por semana)        │  │
│  │ vencida/sin licencia │  └──────────────────────────────────────────────┘  │
│  └──────────────────────┘  ┌── HorizontalBar: cuentas por plan ───────────┐  │
│  ┌── Heatmap: calendario ┐ │ Básico ███ Pro █████ Premium ██               │  │
│  │ vencimientos del mes   │ └──────────────────────────────────────────────┘  │
│  └────────────────────────┘                                                  │
├───────────────────────────────────────────────────────────────────────────┤
│  Filtros: [estado ▾] [plan ▾] [tipo ▾] [vence entre __ y __] [buscar cuenta] │
│  Tabla (VeTable + paginado):                                                │
│  Cuenta │ Estado │ Plan │ Agentes(u/tope) │ Inicia │ Vence(días) │ Cola │ Legacy │ Acciones │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Acme   │ ●activa│ Pro  │ 4/5  ▓▓▓▓░      │ 01/07  │ 12/08 (19d) │ –    │ 🟢    │[Gestionar]│
│  Beta   │ ▲porven│ Básic│ 2/2  ▓▓        │ 20/06  │ 31/07 (7d)  │ +30d │ 🔴    │[Renovar]  │
│  Gamma  │ ○sin   │ –    │ 6/∞            │ –      │ –           │ –    │ 🟢    │[Activar]  │
│  … paginado nativo · orden por vence/agentes/estado · export CSV (bonus)     │
└───────────────────────────────────────────────────────────────────────────┘
```

### 8.3 Interacciones interesantes ("qué más podría ser")
- **Chips 7/14/30/60 días** → filtran la tabla + resaltan la curva de vencimientos.
- **Click en segmento del doughnut** → filtra la tabla por ese estado (drill-down).
- **Cola de renovaciones accionable:** las "por vencer" con botón [Renovar] directo.
- **Alertas arriba:** "N licencias vencen esta semana" · "M cuentas topadas en agentes".
- **Utilización de agentes** (usados/licenciados): detecta cuentas **topadas** (candidatas a
  upgrade) o **sub-usadas** (posible downgrade).
- **Conversión demo→pago** y **churn** (vencidas no renovadas) como métricas de negocio.
- **Referencia legacy** (§12) integrada como semáforo 🟢/🔴 en la tabla para decidir activar.
- **Proyección de ingresos (futuro, opcional):** si se agrega `price` a `license_plans`,
  KPIs de MRR / ingreso por vencer. (No en v1; el modelo lo permite sumar después.)

### 8.4 Vista dentro de la cuenta (admin, solo lectura) — distinta del dashboard
```
accounts/:accountId/settings/license  (permiso: administrator) — NO el perfil personal
  Molde: settings/billing (lee currentAccount del payload; sin endpoints nuevos)
  Menú:  Settings → "Licencia"
     tipo · estado · vence (fecha + días) · agentes usados/tope · barra de progreso
     + "Próximo periodo" si hay licencia programada
  Banner global cuando days_left ≤ 10 (o suspendida → pantalla "licencia vencida")
  (El SuperAdmin gestiona desde el Dashboard §8.2, no desde aquí.)
```

- i18n `en` + `es`. El banner lee el resumen de licencia del payload de la cuenta (§5).
- Endpoints del dashboard: un `licenses/dashboard` (métricas agregadas) + `licenses` (tabla
  paginada con filtros), **solo SuperAdmin** por policy.

---

## 9. Fases de entrega

```
Fase 0  Cimientos + enforcement
        · migración license_plans (+ seed "Demo 15d/2") + account_licenses
        · modelos + enums + scopes + snapshot al emitir
        · concern AccountLicensable (current_license) + wiring usage_limits/agent_limits
        · config global (LICENSE_ENFORCEMENT_ENABLED)
        ── entregable: setear max_agents en consola topa el alta de agentes (402)

Fase 1  Demo automática (solo cuentas NUEVAS)
        · AccountBuilder crea demo copiando el plan signup_default al registrar
        · cuentas existentes: NO se tocan → quedan "fuera de licencia" (como hoy, sin enforcement)
        ── entregable: cuenta nueva nace en demo; las existentes siguen igual que hoy

Fase 2  Gestión + catálogo + tabla cruzada (solo SuperAdmin)
        · CRUD de license_plans (nombre/días/agentes + set de canales/funciones = features §13)
        · LicenseIssueService aplica features del plan (enable/disable_features) al activar
        · página settings/license (por cuenta) + endpoints escritura (policy: user.is_a?(SuperAdmin))
        · tabla cruzada (VeTable + paginado) + filtros + acción "Agregar/Activar licencia"
        · referencia legacy (§12): lectura defensiva de columnas viejas + semáforo 🟢/🔴 (solo si existen)
        · flag is_super_admin en el payload del usuario → gating del link/controles
        · LicenseIssueService (elige plan, snapshot, cancela activa anterior, reactiva cuenta)
        ── entregable: un SuperAdmin ve cuáles cuentas están fuera de licencia y les agrega una

Fase 3.5  Dashboard de Licencias (KPIs + gráficos)
        · LicenseDashboardService (métricas agregadas + series) + endpoint dashboard
        · KPIs (MetricCard) + gráficos nativos (doughnut/bar/horizontalbar/heatmap)
        · chips 7/14/30/60d + drill-down (click en gráfico filtra tabla) + alertas
        ── entregable: dashboard con filtros por vencimiento, estado de licencias y utilización

Fase 3  Vencimientos + cola + avisos + suspensión
        · LicenseExpiryScanJob (cron diario) + LicenseNotificationJob + LicenseMailer
        · avisos 10/5 días (correo admins)
        · al vencer: promover licencia `scheduled` a `active` si existe; si no → expired + suspend
        · emitir "pago por adelantado" como `scheduled` (cola) desde el super admin
        ── entregable: encadenar periodos sin corte; suspensión solo si no hay cola

Fase 4  UI de cuenta (solo lectura) + banner
        · Settings "Licencia" (solo lectura) + banner days_left ≤ 10 + pantalla "vencida"
        · resumen de licencia en el payload de la cuenta
        ── entregable: el admin ve su estado y recibe el aviso en el dashboard
```

---

## 10. Riesgos / puntos finos

- **Cuentas existentes = fuera de licencia (por diseño):** NO se les fuerza licencia; se
  comportan como hoy hasta que un SuperAdmin les agregue una. Esto elimina el riesgo de
  bloquear cuentas al encender el enforcement (sin licencia = no gestionado). Ya NO hay backfill.
- **"Fuera de licencia" debe ser distinguible de "vencida":** sin fila = fuera (no gestionada);
  con fila `expired` = vencida y suspendida. El wiring y el job tratan cada caso distinto.
- **Super admin / instancia propia:** asegurar que el super admin y cuentas internas no se
  auto-suspendan (excluir por lista o darles licencia perpetua interna).
- **Reactivación:** al renovar una cuenta suspendida, hay que **volver `status: active`**
  explícitamente (no basta con la licencia).
- **Agentes ya por encima del tope:** por diseño (solo bloquear nuevos) no se expulsa a nadie;
  el conteo puede quedar temporalmente > tope sin error.
- **Zona horaria de vencimiento:** definir si `expires_at` es fin de día en la TZ de la cuenta.
- **Continuidad de la cola:** cada `scheduled` arranca donde termina la anterior
  (`starts_at = expires_at previa`); si el job corre tarde y hay desfase, al promover se
  recalcula `starts_at = now` para no "regalar" ni "comer" días. Definir la política exacta.
- **Cambio de agentes entre periodos encolados:** si el periodo programado tiene menos
  agentes que el vigente, al promover aplica el nuevo tope (solo bloquea nuevos, no expulsa).
- **Cancelar un periodo programado:** el super admin debe poder borrar/cancelar una licencia
  `scheduled` de la cola sin afectar la activa.

---

## 11. Decisiones ya tomadas (contigo)

| Tema | Decisión |
|------|----------|
| Sujeto de la licencia | La **cuenta** (uso de la plataforma), no software vendido a terceros |
| Alcance | Solo cuentas **con licencia**. Nuevas → demo auto. Existentes → **fuera de licencia** (como hoy) hasta que un SuperAdmin les asigne una. Sin backfill forzado |
| Campo que suspende | **`accounts.status`** (enum active:0 / suspended:1); suspended bloquea el acceso |
| Ver/incorporar cuentas | Vista cruzada SuperAdmin con estado de licencia + filtro "sin licencia" + acción "Agregar licencia" |
| Planes personalizables | Catálogo `license_plans` con **nombre + días + agentes por defecto**; se elige al emitir (snapshot en la licencia) |
| Demo por defecto | Un **plan** marcado `signup_default` (seed "Demo 15d/2", editable desde el catálogo) |
| Al vencer | **Suspender toda la cuenta** (bloquear acceso) |
| Administración | **Solo `SuperAdmin` de Wintook**, desde el **dashboard normal** (`settings/license`); controles visibles solo a SuperAdmin, admin de la cuenta ve solo lectura. Administrate queda opcional (vista cruzada) |
| Avisos (10 y 5 días antes) | **Correo a admins de la cuenta** + **banner en el dashboard** |
| Tope de agentes al bajar/vencer | **Solo bloquear nuevos** (no expulsar existentes) |
| Pago por adelantado | **Licencia encadenada:** nueva `scheduled` que inicia al vencer la vigente (cola de periodos); al vencer se promueve sola, sin cortar el servicio |
| Data del sistema viejo | **NO importar.** Se muestra como **referencia** (🟢 vigente / 🔴 vencida + fechas + agentes) para decidir; "Activar licencia" crea una **nueva** en el sistema nuevo (flujo tipo renovar) |
| Superficie principal | **Dashboard de Licencias** (SuperAdmin) con KPIs + gráficos + tabla filtrable/paginada, filtros por vencimiento 7/14/30/60d, drill-down. **Solo componentes nativos** de Chatwoot (chart.js/vue-chartjs, MetricCard, VeTable, Heatmap) |
| Limitar canales/funciones | El **plan** define un set de **feature flags** (canales + funciones); se aplican con `enable/disable_features` al activar. Apagar un canal oculta su alta de inbox (los existentes siguen). Enforcement runtime = fuera de v1 |

---

## 12. Sistema de licencias ANTERIOR (solo referencia, NO se importa)

En **producción** (no en este código ni en dev) la tabla `accounts` tiene columnas de un
intento previo que nunca funcionó, más dos catálogos:

```
accounts.date_start        → inicio de la licencia vieja
accounts.date_end          → vencimiento (🟢 si > hoy · 🔴 si < hoy)
accounts.date_alert        → fecha de aviso que usaban
accounts.license_period_id → FK a license_periods  (duración; ahí vive el nº de agentes)
accounts.type_license_id   → FK a license_types    (tipo)
license_periods (tabla)    → catálogo viejo de periodos  [estructura a confirmar]
license_types   (tabla)    → catálogo viejo de tipos     [estructura a confirmar]
```

**No están en `schema.rb` ni en el código** → se agregaron a mano en producción.

**Uso en el nuevo sistema (solo lectura):**
- Un `LegacyLicenseReference` (service/lectura defensiva) lee esas columnas **si existen**
  (chequeo de `column_exists?` para no romper en dev/otras instancias) y hace join a los
  catálogos viejos para obtener **nombre · días · nº de agentes · fechas**.
- La **vista cruzada** (§6) muestra esa referencia por cuenta con semáforo 🟢/🔴.
- Al pulsar **"Activar licencia"**, el formulario puede venir **pre-llenado** con esos valores,
  pero **crea una `account_license` nueva** (no hereda la vieja). El histórico viejo queda
  intacto como referencia hasta migrar todas las cuentas.
- **Limpieza futura (opcional):** una vez todas las cuentas estén "renovadas" al sistema nuevo,
  se pueden **dropear** las columnas y tablas viejas (migración de limpieza).

> ⏳ **Pendiente:** estructura y contenido de `license_periods` / `license_types` de producción
> (el usuario los describirá) para mapear el **nº de agentes** en la referencia.

---

## 13. Entitlements por plan — limitar canales y funciones

La licencia no solo limita **agentes**: cada **plan** define qué **canales y funciones** habilita,
reutilizando el sistema de feature flags que Chatwoot ya tiene por cuenta.

```
Mecanismo existente (NO se reinventa)
  accounts.feature_flags  (bigint, FlagShihTzu)
  app/models/concerns/featurable.rb → enable_features(*), disable_features(*), feature_enabled?(*)
  super_admin ya los togglea (accounts_controller#update → enabled_features)
  el front gatea la lista de canales al crear inbox por feature flag (Settings.vue)

Wiring con la licencia
  license_plans.features = ["channel_whatsapp","channel_telegram","campaigns","reports", …]
  LicenseIssueService, al emitir/activar:
     account.enable_features(*plan.features)
     account.disable_features(*(catálogo − plan.features))   ← lo que el plan NO incluye
  ⇒ el plan es el "paquete de entitlements": agentes + canales + funciones.
```

**Qué se puede limitar** (nombres de `config/features.yml`):
```
Canales:   channel_email · channel_facebook · channel_twitter · channel_website ·
           channel_sms · channel_whatsapp · channel_telegram · channel_line · channel_api
Funciones: campaigns · reports · help_center · agent_bots · macros · automations ·
           canned_responses · sla · crm · custom_roles · integrations · audit_logs ·
           voice_recorder · captain_integration · google_calendar · case_management ·
           erp_connection · whatsapp_templates · …  (cualquier feature del catálogo)
```

**Matiz (importante):** apagar un `channel_*` **oculta ese canal en la pantalla "Crear inbox"**
(el flag gatea el onboarding), pero los **inboxes ya creados de ese canal siguen funcionando**.
Cortar en runtime un canal existente sería enforcement extra → **fuera de v1** (se puede sumar).

**En el Dashboard (§8):** por cuenta se muestran los **canales/funciones habilitados** (chips);
se puede **filtrar** "cuentas que usan Telegram", o ver un breakdown "cuentas por canal".

**UI del plan (catálogo, §6):** al crear/editar un plan, checkboxes de canales y funciones
(agrupados) → se guardan en `license_plans.features`. La demo (`signup_default`) trae su set mínimo.

**Decisión a validar:** ¿el plan es **autoritativo** (aplica su set exacto y apaga lo demás) o
solo **habilita** (enable) sin apagar lo que el super admin prendió a mano? Propuesta:
autoritativo al emitir, pero el super admin puede ajustar features puntuales después.

---

> **Siguiente paso:** con esto aprobado, arranco **Fase 0** (migración `account_licenses`
> + modelo + wiring de `usage_limits` + config de defaults demo). La capa de referencia
> legacy (§12) entra en Fase 2 (vista cruzada); los entitlements por plan (§13) entran en
> Fase 2 (catálogo) + Fase 3.5 (mostrar/filtrar en el dashboard).
