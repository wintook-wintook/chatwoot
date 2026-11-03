# Módulo de Licencias de Plataforma — Plan v1.1

> **Versión:** 1.1 — documento vivo, se irá mejorando.
> **Rama:** `feat/licencias` · **Fecha:** 2026-10-23 (v1.0: 2026-08-07) · **Estado:** PLAN (sin implementar)
> **Sujeto de la licencia:** la **cuenta** (su uso de la plataforma), no software vendido a terceros.
> **Administra:** personal de Wintook con permiso dado **desde el super admin** (no por `.env`). El cliente solo consulta.

> **Qué cambió en la v1.1 (23/10/2026):** quién ve y gestiona licencias se configura en el super
> admin por agente y por cuenta (§8); al vencer, además de bloquear el acceso, **se callan los
> Agentes IA, seguimientos y campañas** (§5.1); el interruptor general pasa del `.env` a la
> configuración del super admin; las fases se reordenan para que la licencia funcione antes que el
> tablero (§10); y se suman riesgos que aparecieron al revisar el código actual (§11).

---

## 1. Qué abarca el módulo

Hoy una cuenta de la plataforma no tiene vigencia ni tope real: se crea y funciona
indefinidamente, con los agentes que quiera. No hay forma de vender un periodo, de limitar por
plan, ni de saber de un vistazo quién está por vencer. Este módulo convierte el uso de la
plataforma en algo **contratado, medible y con fecha**.

<svg viewBox="0 0 880 330" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Los seis pilares que abarca el módulo de licencias">
  <g font-family="system-ui, sans-serif">
    <rect x="20" y="20" width="270" height="88" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
    <text x="38" y="46" font-size="13" font-weight="700" fill="#1E3A8A">⏱ Vigencia por cuenta</text>
    <text x="38" y="68" font-size="11.5" fill="#1E40AF">Cada cuenta tiene un periodo con inicio</text>
    <text x="38" y="84" font-size="11.5" fill="#1E40AF">y fin. Al vencer, se suspende el acceso</text>
    <text x="38" y="100" font-size="11.5" fill="#1E40AF">hasta que se renueve.</text>

    <rect x="305" y="20" width="270" height="88" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
    <text x="323" y="46" font-size="13" font-weight="700" fill="#1E3A8A">👥 Tope de agentes</text>
    <text x="323" y="68" font-size="11.5" fill="#1E40AF">El plan define cuántos agentes puede</text>
    <text x="323" y="84" font-size="11.5" fill="#1E40AF">tener. Al llegar al tope, no se pueden</text>
    <text x="323" y="100" font-size="11.5" fill="#1E40AF">dar de alta más.</text>

    <rect x="590" y="20" width="270" height="88" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
    <text x="608" y="46" font-size="13" font-weight="700" fill="#1E3A8A">🎁 Demo automática</text>
    <text x="608" y="68" font-size="11.5" fill="#1E40AF">Toda cuenta nueva nace con una prueba</text>
    <text x="608" y="84" font-size="11.5" fill="#1E40AF">(15 días / 2 agentes) sin intervención</text>
    <text x="608" y="100" font-size="11.5" fill="#1E40AF">de nadie.</text>

    <rect x="20" y="122" width="270" height="88" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="1.5"/>
    <text x="38" y="148" font-size="13" font-weight="700" fill="#78350F">📦 Planes personalizables</text>
    <text x="38" y="170" font-size="11.5" fill="#92400E">Catálogo propio: nombre, duración,</text>
    <text x="38" y="186" font-size="11.5" fill="#92400E">agentes y qué canales y funciones</text>
    <text x="38" y="202" font-size="11.5" fill="#92400E">incluye cada plan.</text>

    <rect x="305" y="122" width="270" height="88" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="1.5"/>
    <text x="323" y="148" font-size="13" font-weight="700" fill="#78350F">🔗 Periodos encadenados</text>
    <text x="323" y="170" font-size="11.5" fill="#92400E">Si el cliente paga por adelantado, el</text>
    <text x="323" y="186" font-size="11.5" fill="#92400E">nuevo periodo queda en cola y arranca</text>
    <text x="323" y="202" font-size="11.5" fill="#92400E">solo, sin cortar el servicio.</text>

    <rect x="590" y="122" width="270" height="88" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="1.5"/>
    <text x="608" y="148" font-size="13" font-weight="700" fill="#78350F">🔔 Avisos anticipados</text>
    <text x="608" y="170" font-size="11.5" fill="#92400E">Correo a los administradores y banner</text>
    <text x="608" y="186" font-size="11.5" fill="#92400E">en el dashboard 10 y 5 días antes del</text>
    <text x="608" y="202" font-size="11.5" fill="#92400E">vencimiento.</text>

    <rect x="20" y="224" width="840" height="88" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="2"/>
    <text x="38" y="250" font-size="13" font-weight="700" fill="#14532D">📊 Dashboard de Licencias — la superficie principal, solo para Wintook</text>
    <text x="38" y="272" font-size="11.5" fill="#166534">Cuántas cuentas activas, cuáles vencen en 7 / 14 / 30 / 60 días, cuáles ya vencieron, cuántas siguen en demo,</text>
    <text x="38" y="288" font-size="11.5" fill="#166534">cuáles están fuera del sistema, qué tan aprovechado está cada plan y cuántas demos se convirtieron en pago.</text>
    <text x="38" y="304" font-size="11.5" font-weight="700" fill="#15803D">Con acciones directas: activar, renovar, programar o gestionar la licencia de cualquier cuenta.</text>
  </g>
</svg>

**En una frase:** deja de venderse "acceso a la plataforma" y pasa a venderse **un plan, por un
periodo, con un número de agentes y un conjunto de canales y funciones** — con el cobro del
lado comercial y el control del lado del sistema.

### Por qué es un módulo fuerte

1. **Se apoya en lo que la plataforma ya sabe hacer** (§2). No hay que inventar el bloqueo: ya
   existe. Eso baja muchísimo el riesgo de la parte delicada.
2. **No pone en riesgo a los clientes actuales.** Las cuentas existentes quedan *fuera de
   licencia* y siguen exactamente como hoy hasta que alguien de Wintook decida darles una. No
   hay un día en que "se apaguen" solas.
3. **Convierte una gestión de memoria en un tablero.** Hoy saber quién vence esta semana implica
   preguntar; con esto es una pantalla.
4. **El plan es un paquete completo**, no solo un número de agentes: define también qué canales
   (WhatsApp, Telegram, Facebook…) y qué funciones (campañas, reportes, base de conocimiento…)
   puede usar la cuenta. Eso permite armar niveles comerciales reales.
5. **Nadie se puede auto-ampliar.** Un administrador de cuenta no puede tocar su propia licencia:
   solo la ve. La gestión es exclusiva de Wintook.
6. **El cobro adelantado no rompe nada.** Se encolan periodos y el sistema los va promoviendo
   solo, sin cortes ni trabajo manual el día del vencimiento.

---

## 2. El hallazgo que lo hace viable

La parte más delicada —bloquear el alta de agentes y cortar el acceso— **ya está implementada en
la plataforma**. El módulo solo tiene que alimentarla con los datos correctos.

<svg viewBox="0 0 880 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Los dos mecanismos de bloqueo que ya existen en la plataforma">
  <rect x="20" y="20" width="410" height="130" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="1.5"/>
  <text x="40" y="46" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#14532D">YA EXISTE · Tope de agentes</text>
  <text x="40" y="72" font-family="ui-monospace, monospace" font-size="11" fill="#166534">AgentsController#create → validate_limit</text>
  <text x="40" y="92" font-family="ui-monospace, monospace" font-size="11" fill="#166534">usage_limits[:agents] − agents.count &gt; 0 ?</text>
  <rect x="40" y="104" width="370" height="30" rx="5" fill="#FEE2E2" stroke="#EF4444"/>
  <text x="52" y="123" font-family="system-ui, sans-serif" font-size="11" fill="#991B1B">si no alcanza → 402 "Please purchase more licenses"</text>

  <rect x="450" y="20" width="410" height="130" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="1.5"/>
  <text x="470" y="46" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#14532D">YA EXISTE · Bloqueo de acceso</text>
  <text x="470" y="72" font-family="ui-monospace, monospace" font-size="11" fill="#166534">ensure_current_account_helper.rb</text>
  <text x="470" y="92" font-family="ui-monospace, monospace" font-size="11" fill="#166534">accounts.status: active | suspended</text>
  <rect x="470" y="104" width="370" height="30" rx="5" fill="#FEE2E2" stroke="#EF4444"/>
  <text x="482" y="123" font-family="system-ui, sans-serif" font-size="11" fill="#991B1B">suspended → "Account is suspended", sin acceso</text>

  <path d="M225 150 L225 178" stroke="#94A3B8" stroke-width="2" marker-end="url(#l1)"/>
  <path d="M655 150 L655 178" stroke="#94A3B8" stroke-width="2" marker-end="url(#l1)"/>
  <defs><marker id="l1" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 z" fill="#94A3B8"/></marker></defs>

  <rect x="20" y="178" width="410" height="52" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="2"/>
  <text x="40" y="200" font-family="system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#1E3A8A">LO QUE HAY QUE HACER</text>
  <text x="40" y="219" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">que ese tope venga de la licencia activa</text>

  <rect x="450" y="178" width="410" height="52" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="2"/>
  <text x="470" y="200" font-family="system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#1E3A8A">LO QUE HAY QUE HACER</text>
  <text x="470" y="219" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">que "vencer" ponga la cuenta en suspended</text>

  <rect x="20" y="248" width="840" height="40" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="1.5"/>
  <text x="40" y="273" font-family="system-ui, sans-serif" font-size="12.5" fill="#78350F">Ni el controlador de agentes ni la pantalla de agentes se tocan. Se modifica <tspan font-family="ui-monospace, monospace">una sola</tspan> función: la que resuelve el tope.</text>
</svg>

> **Revisado el 23/10/2026 contra el código actual:** los dos mecanismos siguen ahí
> (`AgentsController#validate_limit` → 402 leyendo `usage_limits[:agents]`;
> `ensure_current_account_helper.rb:11`). **Pero `suspended` solo cierra la puerta del
> dashboard y la API:** de todo lo que procesa mensajes, seguimientos y campañas, solo la entrada
> de WhatsApp revisa si la cuenta está activa. Una cuenta vencida seguiría recibiendo mensajes por
> Telegram, Instagram, Facebook o el chat web, y sus Agentes IA y campañas seguirían contestando y
> gastando OpenAI sin que nadie pudiera entrar. La v1.1 lo resuelve en §5.1.

---

## 3. Alcance

### Dentro de la v1

- Catálogo de **planes personalizables**: nombre, duración en días, agentes por defecto y set de
  canales y funciones habilitados. Uno marcado como demo de registro.
- **Licencia por cuenta** con historial; la efectiva es la activa. Al emitir se copian los
  valores del plan (snapshot), así editar el catálogo después no altera lo ya emitido.
- **Demo automática** solo para cuentas nuevas.
- **Cuentas existentes: fuera de licencia**, sin tope ni vencimiento, hasta que Wintook les
  asigne una.
- **Dashboard de Licencias** con KPIs, gráficos, tabla filtrable y acciones, visible solo en
  cuentas de Wintook para agentes con permiso dado en el super admin (§8).
- **Upgrade y renovación** desde el dashboard normal, con controles visibles solo a quien tenga
  «Gestionar licencias».
- **Periodos encadenados** para pagos por adelantado.
- **Avisos** 10 y 5 días antes por correo y banner.
- **Suspensión al vencer**, con reactivación al renovar, y **silencio del motor**: Agentes IA,
  seguimientos y campañas no responden ni envían mientras la cuenta esté vencida (§5.1).
- **Vista de solo lectura** para el administrador de la cuenta.

### Fuera de la v1

Cobros y facturación · auto-renovación con cargo · portal de autoservicio · límites de otros
recursos (inboxes, contactos, mensajes) · **límites de Agentes IA, mensajes de IA o envíos de
campaña** (pregunta abierta, §14) · periodo de gracia tras el vencimiento · desactivar agentes
sobrantes automáticamente · cortar en tiempo real un canal ya en uso.

---

## 4. Modelo de datos

<svg viewBox="0 0 880 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Modelo de datos: license_plans, account_licenses y accounts">
  <!-- license_plans -->
  <rect x="20" y="24" width="250" height="230" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
  <rect x="20" y="24" width="250" height="32" rx="8" fill="#8B5CF6"/>
  <text x="38" y="46" font-family="ui-monospace, monospace" font-size="12.5" font-weight="700" fill="#FFF">license_plans</text>
  <g font-family="ui-monospace, monospace" font-size="11" fill="#4C1D95">
    <text x="36" y="78">name</text>
    <text x="36" y="98">duration_days</text>
    <text x="36" y="118">default_max_agents</text>
    <text x="36" y="138">features  jsonb</text>
    <text x="36" y="158">license_type  demo|paid</text>
    <text x="36" y="178">signup_default  bool</text>
    <text x="36" y="198">active · position</text>
  </g>
  <rect x="32" y="210" width="226" height="34" rx="5" fill="#FFFFFF" stroke="#8B5CF6"/>
  <text x="42" y="224" font-family="system-ui, sans-serif" font-size="10" fill="#5B21B6">CATÁLOGO editable.</text>
  <text x="42" y="238" font-family="system-ui, sans-serif" font-size="10" fill="#5B21B6">Solo uno puede ser el de registro.</text>

  <path d="M270 130 L336 130" stroke="#8B5CF6" stroke-width="2" marker-end="url(#m1)"/>
  <text x="278" y="122" font-family="system-ui, sans-serif" font-size="10" fill="#6D28D9">se copia (snapshot)</text>
  <defs><marker id="m1" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 z" fill="#8B5CF6"/></marker></defs>

  <!-- account_licenses -->
  <rect x="336" y="24" width="270" height="290" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="2"/>
  <rect x="336" y="24" width="270" height="32" rx="8" fill="#F59E0B"/>
  <text x="354" y="46" font-family="ui-monospace, monospace" font-size="12.5" font-weight="700" fill="#FFF">account_licenses</text>
  <g font-family="ui-monospace, monospace" font-size="11" fill="#78350F">
    <text x="352" y="78">name</text>
    <text x="352" y="98">license_type  demo|paid</text>
    <text x="352" y="118">status</text>
    <text x="352" y="138">max_agents</text>
    <text x="352" y="158">duration_days</text>
    <text x="352" y="178">starts_at · expires_at</text>
    <text x="352" y="198">reminded_at  jsonb</text>
    <text x="352" y="218">created_by · notes</text>
  </g>
  <rect x="348" y="230" width="246" height="72" rx="5" fill="#FFFFFF" stroke="#F59E0B"/>
  <text x="358" y="248" font-family="system-ui, sans-serif" font-size="10" font-weight="700" fill="#78350F">Estados</text>
  <text x="358" y="264" font-family="system-ui, sans-serif" font-size="10" fill="#92400E">active · scheduled · expired · cancelled</text>
  <text x="358" y="282" font-family="system-ui, sans-serif" font-size="10" font-weight="700" fill="#B45309">Índice único: solo UNA activa por cuenta</text>
  <text x="358" y="296" font-family="system-ui, sans-serif" font-size="10" fill="#92400E">+ N programadas en cola</text>

  <path d="M606 130 L672 130" stroke="#F59E0B" stroke-width="2" marker-end="url(#m2)"/>
  <defs><marker id="m2" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 z" fill="#F59E0B"/></marker></defs>

  <!-- accounts -->
  <rect x="672" y="24" width="188" height="130" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <rect x="672" y="24" width="188" height="32" rx="8" fill="#3B82F6"/>
  <text x="690" y="46" font-family="ui-monospace, monospace" font-size="12.5" font-weight="700" fill="#FFF">accounts</text>
  <g font-family="ui-monospace, monospace" font-size="11" fill="#1E3A8A">
    <text x="688" y="78">status</text>
    <text x="688" y="98">  active | suspended</text>
    <text x="688" y="122">limits jsonb</text>
    <text x="688" y="142">  {agents, inboxes}</text>
  </g>

  <rect x="20" y="330" width="840" height="56" rx="8" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5"/>
  <text x="38" y="352" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#334155">Sin fila en account_licenses = cuenta FUERA DE LICENCIA</text>
  <text x="38" y="372" font-family="system-ui, sans-serif" font-size="11.5" fill="#475569">No es lo mismo que "vencida". Fuera de licencia = no gestionada, se comporta como hoy. Vencida = tuvo licencia y expiró, queda suspendida.</text>
</svg>

Dos tablas nuevas, ninguna columna añadida a `accounts`. El *snapshot* es la decisión clave:
editar o borrar un plan del catálogo **no altera** las licencias ya emitidas.

---

## 5. Ciclo de vida

<svg viewBox="0 0 880 380" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Ciclo de vida de una licencia: demo, activa, programada, vencida y suspensión">
  <rect x="330" y="16" width="220" height="42" rx="8" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5"/>
  <text x="352" y="42" font-family="system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#334155">Se registra una cuenta nueva</text>
  <path d="M440 58 L440 82" stroke="#94A3B8" stroke-width="2" marker-end="url(#n1)"/>
  <defs><marker id="n1" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 z" fill="#94A3B8"/></marker></defs>

  <rect x="330" y="82" width="220" height="56" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="2"/>
  <text x="352" y="106" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#1E3A8A">DEMO</text>
  <text x="352" y="126" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">15 días · 2 agentes · automática</text>

  <path d="M550 110 L640 110" stroke="#22C55E" stroke-width="2" marker-end="url(#n2)"/>
  <text x="556" y="102" font-family="system-ui, sans-serif" font-size="10" fill="#15803D">upgrade (Wintook)</text>
  <defs><marker id="n2" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 z" fill="#22C55E"/></marker></defs>

  <rect x="640" y="82" width="220" height="56" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="2"/>
  <text x="662" y="106" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#14532D">ACTIVA (de pago)</text>
  <text x="662" y="126" font-family="system-ui, sans-serif" font-size="11.5" fill="#166534">la anterior queda cancelada</text>

  <path d="M750 138 L750 172" stroke="#8B5CF6" stroke-width="2" marker-end="url(#n3)"/>
  <text x="758" y="160" font-family="system-ui, sans-serif" font-size="10" fill="#6D28D9">paga por adelantado</text>
  <defs><marker id="n3" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 z" fill="#8B5CF6"/></marker></defs>

  <rect x="640" y="172" width="220" height="56" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="2"/>
  <text x="662" y="196" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#4C1D95">PROGRAMADA (cola)</text>
  <text x="662" y="216" font-family="system-ui, sans-serif" font-size="11.5" fill="#5B21B6">arranca cuando termina la vigente</text>

  <path d="M440 138 L440 262" stroke="#94A3B8" stroke-width="2" marker-end="url(#n1)"/>
  <text x="450" y="200" font-family="system-ui, sans-serif" font-size="10.5" fill="#64748B">llega la fecha de vencimiento</text>
  <text x="450" y="216" font-family="system-ui, sans-serif" font-size="10.5" fill="#64748B">(revisión diaria automática)</text>

  <rect x="290" y="262" width="300" height="46" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="2"/>
  <text x="312" y="290" font-family="system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#78350F">¿Hay un periodo en cola?</text>

  <path d="M290 285 L180 285" stroke="#22C55E" stroke-width="2" marker-end="url(#n2)"/>
  <text x="196" y="277" font-family="system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#15803D">SÍ</text>
  <rect x="20" y="262" width="160" height="46" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="1.5"/>
  <text x="34" y="282" font-family="system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#14532D">Se promueve sola</text>
  <text x="34" y="298" font-family="system-ui, sans-serif" font-size="10.5" fill="#166534">sin cortar el servicio</text>

  <path d="M590 285 L700 285" stroke="#EF4444" stroke-width="2" marker-end="url(#n4)"/>
  <text x="620" y="277" font-family="system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#B91C1C">NO</text>
  <defs><marker id="n4" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 z" fill="#EF4444"/></marker></defs>
  <rect x="700" y="262" width="160" height="46" rx="8" fill="#FEE2E2" stroke="#EF4444" stroke-width="2"/>
  <text x="714" y="282" font-family="system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#7F1D1D">Vencida + suspendida</text>
  <text x="714" y="298" font-family="system-ui, sans-serif" font-size="10.5" fill="#991B1B">acceso bloqueado</text>

  <rect x="20" y="326" width="840" height="40" rx="8" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5"/>
  <text x="38" y="351" font-family="system-ui, sans-serif" font-size="11.5" fill="#334155">🔔 Antes de todo esto: aviso por correo a los administradores y banner en el dashboard, <tspan font-weight="700">10 y 5 días antes</tspan> del vencimiento. Al renovar una cuenta suspendida, se reactiva.</text>
</svg>

### 5.1 Qué pasa con la cuenta cuando vence (nuevo en v1.1)

**Decisión 23/10/2026:** los mensajes siguen entrando y quedan guardados, pero **nada responde
ni envía solo** hasta que se renueve.

```
 Licencia vencida (sin cola)  →  accounts.status = suspended
 ┌──────────────────────────────┬──────────────────────────────────────────────┐
 │ Sigue funcionando            │ Se detiene                                   │
 ├──────────────────────────────┼──────────────────────────────────────────────┤
 │ Entrada de mensajes de todos │ Entrar al dashboard y usar la API            │
 │ los canales (quedan en la    │   (ya existe: «Account is suspended»)        │
 │ conversación, sin perderse)  │ Agentes IA: no contestan                     │
 │                              │ Seguimientos: no envían ni analizan          │
 │                              │ Campañas: se pausan, no despachan            │
 │                              │ Mensajes automáticos de llamadas perdidas    │
 └──────────────────────────────┴──────────────────────────────────────────────┘
 Al renovar: accounts.status = active y todo retoma; lo que entró queda en sus conversaciones.
```

- Se hace con **un solo chequeo compartido** (`account.active?`) en las puertas del motor: la
  respuesta del Agente IA (`ContactTrackingResponseAnalyzerJob`, `KnowledgeBaseResponseService`),
  el primer mensaje del seguimiento (`ContactTrackingJob`), el despacho de campañas
  (`TrackingDispatch::SendJob`) y las acciones automáticas de llamada perdida. Es el mismo patrón
  que ya usa `ContactTrackings::PendingSetup` para callar un agente con datos sin llenar.
- La entrada de WhatsApp hoy **ignora** los mensajes de una cuenta suspendida
  (`WhatsappChannelLookup#channel_is_inactive?`). Para que todos los canales se comporten igual,
  ese chequeo se cambia: el mensaje entra y se guarda, y es el motor el que no contesta.
- Las cuentas «fuera de licencia» (sin fila) y las «de Wintook» nunca se suspenden.

---

## 6. Cómo se aplica el tope de agentes

<svg viewBox="0 0 880 260" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Precedencia para resolver el tope de agentes de una cuenta">
  <rect x="300" y="16" width="280" height="42" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="2"/>
  <text x="318" y="42" font-family="ui-monospace, monospace" font-size="12" font-weight="700" fill="#1E3A8A">¿cuántos agentes puede tener?</text>
  <path d="M440 58 L440 78" stroke="#94A3B8" stroke-width="2"/>
  <path d="M150 78 L730 78" stroke="#94A3B8" stroke-width="2"/>
  <path d="M150 78 L150 100" stroke="#94A3B8" stroke-width="2" marker-end="url(#o1)"/>
  <path d="M440 78 L440 100" stroke="#94A3B8" stroke-width="2" marker-end="url(#o1)"/>
  <path d="M730 78 L730 100" stroke="#94A3B8" stroke-width="2" marker-end="url(#o1)"/>
  <defs><marker id="o1" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 z" fill="#94A3B8"/></marker></defs>

  <rect x="30" y="100" width="240" height="100" rx="8" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5"/>
  <text x="48" y="126" font-family="system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#334155">Sin licencia</text>
  <text x="48" y="148" font-family="system-ui, sans-serif" font-size="11.5" fill="#475569">(cuentas existentes)</text>
  <text x="48" y="172" font-family="system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#334155">→ como hoy, sin tope</text>
  <text x="48" y="190" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#64748B">no gestionada por el módulo</text>

  <rect x="320" y="100" width="240" height="100" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="2"/>
  <text x="338" y="126" font-family="system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#14532D">Licencia vigente</text>
  <text x="338" y="148" font-family="system-ui, sans-serif" font-size="11.5" fill="#166534">demo o de pago</text>
  <text x="338" y="172" font-family="system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#14532D">→ el tope del plan</text>
  <text x="338" y="190" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#15803D">al llegar al tope: 402</text>

  <rect x="610" y="100" width="240" height="100" rx="8" fill="#FEE2E2" stroke="#EF4444" stroke-width="2"/>
  <text x="628" y="126" font-family="system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#7F1D1D">Licencia vencida</text>
  <text x="628" y="148" font-family="system-ui, sans-serif" font-size="11.5" fill="#991B1B">y sin cola</text>
  <text x="628" y="172" font-family="system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#7F1D1D">→ no admite nuevos</text>
  <text x="628" y="190" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#B91C1C">(y la cuenta queda suspendida)</text>

  <rect x="30" y="212" width="820" height="36" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="1.5"/>
  <text x="48" y="235" font-family="system-ui, sans-serif" font-size="12" fill="#78350F">Bajar de plan o vencer <tspan font-weight="700">nunca expulsa agentes</tspan>: los que ya existen se quedan, simplemente no se pueden agregar más.</text>
</svg>

---

## 7. El plan como paquete: agentes + canales + funciones

La licencia no limita solo el número de agentes. Cada plan define **qué canales y qué funciones**
tiene disponibles la cuenta, apoyándose en el sistema de activación por cuenta que la plataforma
ya usa.

<svg viewBox="0 0 880 290" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Un plan agrupa agentes, canales y funciones">
  <rect x="20" y="20" width="230" height="230" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="2"/>
  <text x="40" y="48" font-family="system-ui, sans-serif" font-size="14" font-weight="700" fill="#4C1D95">Plan "Profesional"</text>
  <rect x="36" y="62" width="198" height="46" rx="6" fill="#FFFFFF" stroke="#8B5CF6"/>
  <text x="48" y="82" font-family="system-ui, sans-serif" font-size="11.5" fill="#5B21B6">Duración</text>
  <text x="48" y="99" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#4C1D95">180 días</text>
  <rect x="36" y="118" width="198" height="46" rx="6" fill="#FFFFFF" stroke="#8B5CF6"/>
  <text x="48" y="138" font-family="system-ui, sans-serif" font-size="11.5" fill="#5B21B6">Agentes</text>
  <text x="48" y="155" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#4C1D95">10</text>
  <rect x="36" y="174" width="198" height="62" rx="6" fill="#FFFFFF" stroke="#8B5CF6"/>
  <text x="48" y="194" font-family="system-ui, sans-serif" font-size="11.5" fill="#5B21B6">Canales y funciones</text>
  <text x="48" y="212" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#4C1D95">las que marque</text>
  <text x="48" y="228" font-family="system-ui, sans-serif" font-size="10.5" fill="#6D28D9">el catálogo de abajo</text>

  <path d="M250 135 L296 135" stroke="#8B5CF6" stroke-width="2" marker-end="url(#p1)"/>
  <text x="252" y="127" font-family="system-ui, sans-serif" font-size="10" fill="#6D28D9">al activar</text>
  <defs><marker id="p1" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 z" fill="#8B5CF6"/></marker></defs>

  <text x="300" y="40" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#64748B">CANALES</text>
  <g font-family="system-ui, sans-serif" font-size="11">
    <rect x="300" y="52" width="120" height="26" rx="13" fill="#DCFCE7" stroke="#22C55E"/><text x="316" y="69" fill="#14532D">✓ WhatsApp</text>
    <rect x="430" y="52" width="120" height="26" rx="13" fill="#DCFCE7" stroke="#22C55E"/><text x="446" y="69" fill="#14532D">✓ Telegram</text>
    <rect x="560" y="52" width="120" height="26" rx="13" fill="#DCFCE7" stroke="#22C55E"/><text x="576" y="69" fill="#14532D">✓ Facebook</text>
    <rect x="690" y="52" width="120" height="26" rx="13" fill="#F1F5F9" stroke="#CBD5E1"/><text x="706" y="69" fill="#94A3B8">✕ SMS</text>
    <rect x="300" y="86" width="120" height="26" rx="13" fill="#DCFCE7" stroke="#22C55E"/><text x="316" y="103" fill="#14532D">✓ Sitio web</text>
    <rect x="430" y="86" width="120" height="26" rx="13" fill="#F1F5F9" stroke="#CBD5E1"/><text x="446" y="103" fill="#94A3B8">✕ Línea</text>
    <rect x="560" y="86" width="120" height="26" rx="13" fill="#DCFCE7" stroke="#22C55E"/><text x="576" y="103" fill="#14532D">✓ Correo</text>
    <rect x="690" y="86" width="120" height="26" rx="13" fill="#F1F5F9" stroke="#CBD5E1"/><text x="706" y="103" fill="#94A3B8">✕ API</text>
  </g>

  <text x="300" y="140" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#64748B">FUNCIONES</text>
  <g font-family="system-ui, sans-serif" font-size="11">
    <rect x="300" y="152" width="120" height="26" rx="13" fill="#DCFCE7" stroke="#22C55E"/><text x="316" y="169" fill="#14532D">✓ Campañas</text>
    <rect x="430" y="152" width="120" height="26" rx="13" fill="#DCFCE7" stroke="#22C55E"/><text x="446" y="169" fill="#14532D">✓ Reportes</text>
    <rect x="560" y="152" width="120" height="26" rx="13" fill="#DCFCE7" stroke="#22C55E"/><text x="576" y="169" fill="#14532D">✓ Tickets</text>
    <rect x="690" y="152" width="120" height="26" rx="13" fill="#F1F5F9" stroke="#CBD5E1"/><text x="706" y="169" fill="#94A3B8">✕ ERP</text>
    <rect x="300" y="186" width="120" height="26" rx="13" fill="#DCFCE7" stroke="#22C55E"/><text x="316" y="203" fill="#14532D">✓ Base conoc.</text>
    <rect x="430" y="186" width="120" height="26" rx="13" fill="#F1F5F9" stroke="#CBD5E1"/><text x="446" y="203" fill="#94A3B8">✕ SLA</text>
    <rect x="560" y="186" width="120" height="26" rx="13" fill="#DCFCE7" stroke="#22C55E"/><text x="576" y="203" fill="#14532D">✓ Macros</text>
    <rect x="690" y="186" width="120" height="26" rx="13" fill="#F1F5F9" stroke="#CBD5E1"/><text x="706" y="203" fill="#94A3B8">✕ Auditoría</text>
  </g>

  <rect x="300" y="224" width="510" height="42" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="1.5"/>
  <text x="316" y="242" font-family="system-ui, sans-serif" font-size="11" fill="#78350F">Apagar un canal lo <tspan font-weight="700">oculta al crear una bandeja nueva</tspan>; las bandejas</text>
  <text x="316" y="258" font-family="system-ui, sans-serif" font-size="11" fill="#78350F">que ya existen de ese canal siguen funcionando (cortarlas en vivo es v2).</text>
</svg>

---

## 8. Quién puede hacer qué — configurable en el super admin (v1.1)

**Decisión 23/10/2026:** quién ve y quién gestiona licencias **no** está fijo en el código ni en
el `.env`: se marca en el super admin, por agente y por cuenta. Mismo patrón que el permiso de
«Publicar prompts» (`users.custom_attributes['can_publish_prompts']`).

<svg viewBox="0 0 880 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Permisos de licencias configurables desde el super admin">
  <g font-family="system-ui, sans-serif">
    <rect x="20" y="16" width="840" height="150" rx="8" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5"/>
    <text x="38" y="42" font-size="13.5" font-weight="700" fill="#334155">Super admin de Wintook — donde se configura todo</text>

    <rect x="38" y="56" width="260" height="96" rx="6" fill="#FFFFFF" stroke="#8B5CF6"/>
    <text x="52" y="78" font-size="12" font-weight="700" fill="#4C1D95">Usuarios › editar agente</text>
    <text x="52" y="102" font-size="11.5" fill="#5B21B6">☑ Ver licencias</text>
    <text x="52" y="122" font-size="11.5" fill="#5B21B6">☑ Gestionar licencias</text>
    <text x="52" y="142" font-size="10.5" font-style="italic" fill="#6D28D9">users.custom_attributes</text>

    <rect x="310" y="56" width="260" height="96" rx="6" fill="#FFFFFF" stroke="#3B82F6"/>
    <text x="324" y="78" font-size="12" font-weight="700" fill="#1E3A8A">Cuentas › editar cuenta</text>
    <text x="324" y="102" font-size="11.5" fill="#1E40AF">☑ Cuenta de Wintook</text>
    <text x="324" y="122" font-size="10.5" fill="#1E40AF">ahí aparece el dashboard y</text>
    <text x="324" y="138" font-size="10.5" fill="#1E40AF">la cuenta nunca se suspende</text>

    <rect x="582" y="56" width="260" height="96" rx="6" fill="#FFFFFF" stroke="#F59E0B"/>
    <text x="596" y="78" font-size="12" font-weight="700" fill="#78350F">Configuración › Licencias</text>
    <text x="596" y="102" font-size="11.5" fill="#92400E">☐ Aplicar licencias</text>
    <text x="596" y="122" font-size="10.5" fill="#92400E">interruptor general (antes .env),</text>
    <text x="596" y="138" font-size="10.5" fill="#92400E">apagado al desplegar</text>

    <rect x="20" y="182" width="270" height="170" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="2"/>
    <text x="38" y="208" font-size="13" font-weight="700" fill="#14532D">Agente con «Gestionar»</text>
    <text x="38" y="226" font-size="10.5" font-style="italic" fill="#166534">en una cuenta de Wintook</text>
    <g font-size="11.5" fill="#166534">
      <text x="38" y="252">✓ Todo lo de «Ver»</text>
      <text x="38" y="274">✓ Activar, renovar, programar</text>
      <text x="38" y="296">✓ Cancelar un periodo en cola</text>
      <text x="38" y="318">✓ Crear y editar planes</text>
      <text x="38" y="340">✓ Ajustar agentes y días al emitir</text>
    </g>

    <rect x="305" y="182" width="270" height="170" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="2"/>
    <text x="323" y="208" font-size="13" font-weight="700" fill="#1E3A8A">Agente con «Ver»</text>
    <text x="323" y="226" font-size="10.5" font-style="italic" fill="#1E40AF">en una cuenta de Wintook (p. ej. ventas)</text>
    <g font-size="11.5" fill="#1E40AF">
      <text x="323" y="252">👁 Dashboard de Licencias completo</text>
      <text x="323" y="274">👁 Por vencer, vencidas, en demo</text>
      <text x="323" y="296">👁 Cuentas fuera de licencia</text>
      <text x="323" y="318">✕ No cambia nada</text>
    </g>

    <rect x="590" y="182" width="270" height="170" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="2"/>
    <text x="608" y="208" font-size="13" font-weight="700" fill="#78350F">Administrador de la cuenta</text>
    <text x="608" y="226" font-size="10.5" font-style="italic" fill="#92400E">el cliente, sin permisos de licencias</text>
    <g font-size="11.5" fill="#92400E">
      <text x="608" y="252">👁 Su plan y su vencimiento</text>
      <text x="608" y="274">👁 Agentes usados / disponibles</text>
      <text x="608" y="296">👁 Su próximo periodo, si hay</text>
      <text x="608" y="318">👁 Avisos y banner</text>
      <text x="608" y="340" font-weight="700" fill="#7F1D1D">✕ No modifica su licencia</text>
    </g>

    <rect x="20" y="364" width="840" height="28" rx="6" fill="#F1F5F9"/>
    <text x="38" y="383" font-size="11" fill="#334155">Un agente con permiso que también está en una cuenta de cliente NO ve el dashboard ahí. El servidor valida el permiso en cada consulta, no solo esconde el botón.</text>
  </g>
</svg>

| Dónde se marca | Qué | Se guarda en | Efecto |
|---|---|---|---|
| Super admin › Usuarios | «Ver licencias» | `users.custom_attributes['can_view_licenses']` | Ve el dashboard (solo lectura) |
| Super admin › Usuarios | «Gestionar licencias» | `users.custom_attributes['can_manage_licenses']` | Además emite, renueva, cancela y edita planes (incluye ver) |
| Super admin › Cuentas | «Cuenta de Wintook» | `accounts.custom_attributes['wintook_internal']` | El dashboard solo aparece en estas cuentas; nunca se suspenden |
| Super admin › Configuración | «Aplicar licencias» | `InstallationConfig` `LICENSE_ENFORCEMENT_ENABLED` (editable en pantalla) | Apagado: se registra todo pero no se bloquea ni se suspende |

- La **policy** de licencias revisa las tres cosas en el servidor: permiso del usuario, cuenta de
  Wintook y, para escribir, «Gestionar».
- El payload del usuario actual lleva `can_view_licenses` / `can_manage_licenses` para mostrar el
  enlace y los botones en el dashboard.
- El administrador de una cuenta cliente sigue viendo su propia licencia en
  Configuración › Licencia, en solo lectura, sin necesitar ningún permiso.

---

## 9. Dashboard de Licencias

Es la superficie principal del módulo: responde de un vistazo *"¿cómo va el negocio?"* y permite
actuar sin salir de ahí.

<svg viewBox="0 0 880 420" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Maqueta del Dashboard de Licencias con KPIs, gráficos y tabla">
  <rect x="10" y="10" width="860" height="400" rx="10" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>
  <rect x="10" y="10" width="860" height="44" rx="10" fill="#1E293B"/>
  <text x="34" y="38" font-family="system-ui, sans-serif" font-size="14" font-weight="700" fill="#FFF">Dashboard de Licencias</text>
  <g font-family="system-ui, sans-serif" font-size="11">
    <rect x="560" y="20" width="60" height="24" rx="12" fill="#3B82F6"/><text x="578" y="36" fill="#FFF">7 d</text>
    <rect x="626" y="20" width="60" height="24" rx="12" fill="#334155"/><text x="642" y="36" fill="#CBD5E1">14 d</text>
    <rect x="692" y="20" width="60" height="24" rx="12" fill="#334155"/><text x="708" y="36" fill="#CBD5E1">30 d</text>
    <rect x="758" y="20" width="60" height="24" rx="12" fill="#334155"/><text x="774" y="36" fill="#CBD5E1">60 d</text>
  </g>

  <!-- KPIs -->
  <g font-family="system-ui, sans-serif">
    <rect x="24" y="66" width="130" height="62" rx="8" fill="#DCFCE7" stroke="#22C55E"/>
    <text x="38" y="86" font-size="10" font-weight="700" fill="#166534">ACTIVAS</text>
    <text x="38" y="114" font-size="22" font-weight="700" fill="#14532D">128</text>

    <rect x="162" y="66" width="130" height="62" rx="8" fill="#FEF3C7" stroke="#F59E0B"/>
    <text x="176" y="86" font-size="10" font-weight="700" fill="#92400E">POR VENCER 7d</text>
    <text x="176" y="114" font-size="22" font-weight="700" fill="#78350F">9</text>

    <rect x="300" y="66" width="130" height="62" rx="8" fill="#FEE2E2" stroke="#EF4444"/>
    <text x="314" y="86" font-size="10" font-weight="700" fill="#991B1B">VENCIDAS</text>
    <text x="314" y="114" font-size="22" font-weight="700" fill="#7F1D1D">4</text>

    <rect x="438" y="66" width="130" height="62" rx="8" fill="#DBEAFE" stroke="#3B82F6"/>
    <text x="452" y="86" font-size="10" font-weight="700" fill="#1E40AF">EN DEMO</text>
    <text x="452" y="114" font-size="22" font-weight="700" fill="#1E3A8A">17</text>

    <rect x="576" y="66" width="130" height="62" rx="8" fill="#F1F5F9" stroke="#94A3B8"/>
    <text x="590" y="86" font-size="10" font-weight="700" fill="#475569">SIN LICENCIA</text>
    <text x="590" y="114" font-size="22" font-weight="700" fill="#334155">63</text>

    <rect x="714" y="66" width="132" height="62" rx="8" fill="#EDE9FE" stroke="#8B5CF6"/>
    <text x="728" y="86" font-size="10" font-weight="700" fill="#5B21B6">CONVERSIÓN</text>
    <text x="728" y="114" font-size="22" font-weight="700" fill="#4C1D95">41%</text>
  </g>

  <!-- gráficos -->
  <rect x="24" y="140" width="270" height="120" rx="8" fill="#FFFFFF" stroke="#CBD5E1"/>
  <text x="38" y="160" font-family="system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#475569">ESTADO DE LICENCIAS</text>
  <circle cx="110" cy="212" r="38" fill="none" stroke="#22C55E" stroke-width="16" stroke-dasharray="150 89"/>
  <circle cx="110" cy="212" r="38" fill="none" stroke="#F59E0B" stroke-width="16" stroke-dasharray="40 199" stroke-dashoffset="-150"/>
  <circle cx="110" cy="212" r="38" fill="none" stroke="#EF4444" stroke-width="16" stroke-dasharray="20 219" stroke-dashoffset="-190"/>
  <g font-family="system-ui, sans-serif" font-size="10" fill="#475569">
    <rect x="180" y="186" width="10" height="10" rx="2" fill="#22C55E"/><text x="196" y="195">Vigentes</text>
    <rect x="180" y="206" width="10" height="10" rx="2" fill="#F59E0B"/><text x="196" y="215">Por vencer</text>
    <rect x="180" y="226" width="10" height="10" rx="2" fill="#EF4444"/><text x="196" y="235">Vencidas</text>
  </g>

  <rect x="304" y="140" width="270" height="120" rx="8" fill="#FFFFFF" stroke="#CBD5E1"/>
  <text x="318" y="160" font-family="system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#475569">VENCIMIENTOS PRÓXIMOS 60 DÍAS</text>
  <g fill="#3B82F6">
    <rect x="322" y="216" width="22" height="30" rx="3"/>
    <rect x="352" y="200" width="22" height="46" rx="3"/>
    <rect x="382" y="228" width="22" height="18" rx="3"/>
    <rect x="412" y="188" width="22" height="58" rx="3"/>
    <rect x="442" y="210" width="22" height="36" rx="3"/>
    <rect x="472" y="224" width="22" height="22" rx="3"/>
    <rect x="502" y="196" width="22" height="50" rx="3"/>
    <rect x="532" y="232" width="22" height="14" rx="3"/>
  </g>

  <rect x="584" y="140" width="262" height="120" rx="8" fill="#FFFFFF" stroke="#CBD5E1"/>
  <text x="598" y="160" font-family="system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#475569">CUENTAS POR PLAN</text>
  <g font-family="system-ui, sans-serif" font-size="10" fill="#475569">
    <text x="598" y="184">Demo</text><rect x="660" y="174" width="60" height="12" rx="3" fill="#3B82F6"/>
    <text x="598" y="206">Básico</text><rect x="660" y="196" width="110" height="12" rx="3" fill="#3B82F6"/>
    <text x="598" y="228">Profesional</text><rect x="660" y="218" width="150" height="12" rx="3" fill="#3B82F6"/>
    <text x="598" y="250">Empresarial</text><rect x="660" y="240" width="80" height="12" rx="3" fill="#3B82F6"/>
  </g>

  <!-- tabla -->
  <rect x="24" y="272" width="822" height="28" fill="#F1F5F9" stroke="#CBD5E1"/>
  <g font-family="system-ui, sans-serif" font-size="10" font-weight="700" fill="#475569">
    <text x="40" y="291">CUENTA</text><text x="230" y="291">ESTADO</text><text x="360" y="291">PLAN</text>
    <text x="500" y="291">AGENTES</text><text x="600" y="291">VENCE</text><text x="740" y="291">ACCIÓN</text>
  </g>
  <g font-family="system-ui, sans-serif" font-size="11">
    <rect x="24" y="300" width="822" height="28" fill="#FFF" stroke="#E2E8F0"/>
    <text x="40" y="318" fill="#1E293B">Comercial del Norte</text>
    <circle cx="236" cy="313" r="4" fill="#22C55E"/><text x="246" y="318" fill="#166534">Vigente</text>
    <text x="360" y="318" fill="#334155">Profesional</text><text x="500" y="318" fill="#334155">7 / 10</text>
    <text x="600" y="318" fill="#334155">12 oct 2026</text>
    <rect x="740" y="305" width="80" height="18" rx="4" fill="#F1F5F9" stroke="#94A3B8"/><text x="756" y="318" font-size="10" fill="#334155">Gestionar</text>

    <rect x="24" y="328" width="822" height="28" fill="#FFFBEB" stroke="#E2E8F0"/>
    <text x="40" y="346" fill="#1E293B">Distribuidora Sur</text>
    <circle cx="236" cy="341" r="4" fill="#F59E0B"/><text x="246" y="346" fill="#92400E">Vence en 5 días</text>
    <text x="360" y="346" fill="#334155">Básico</text><text x="500" y="346" fill="#334155">5 / 5</text>
    <text x="600" y="346" fill="#B45309">12 ago 2026</text>
    <rect x="740" y="333" width="80" height="18" rx="4" fill="#22C55E"/><text x="760" y="346" font-size="10" fill="#FFF">Renovar</text>

    <rect x="24" y="356" width="822" height="28" fill="#FFF" stroke="#E2E8F0"/>
    <text x="40" y="374" fill="#1E293B">Servicios Integrales</text>
    <circle cx="236" cy="369" r="4" fill="#94A3B8"/><text x="246" y="374" fill="#64748B">Sin licencia</text>
    <text x="360" y="374" fill="#94A3B8">—</text><text x="500" y="374" fill="#334155">12 / ∞</text>
    <text x="600" y="374" fill="#94A3B8">—</text>
    <rect x="740" y="361" width="80" height="18" rx="4" fill="#3B82F6"/><text x="752" y="374" font-size="10" fill="#FFF">Activar</text>
  </g>
  <text x="40" y="400" font-family="system-ui, sans-serif" font-size="10" fill="#64748B">Mostrando 1 – 3 de 208 cuentas</text>
  <g font-family="system-ui, sans-serif" font-size="10">
    <rect x="700" y="390" width="24" height="16" rx="4" fill="#3B82F6"/><text x="709" y="402" fill="#FFF">1</text>
    <rect x="730" y="390" width="24" height="16" rx="4" fill="#F1F5F9" stroke="#CBD5E1"/><text x="739" y="402" fill="#334155">2</text>
    <rect x="760" y="390" width="24" height="16" rx="4" fill="#F1F5F9" stroke="#CBD5E1"/><text x="769" y="402" fill="#334155">3</text>
  </g>
</svg>

Todo con componentes que la plataforma ya tiene (gráficos nativos, tarjetas de métrica, tabla con
paginado): **cero librerías nuevas**.

---

## 10. Fases de entrega (reordenadas en v1.1)

**Por qué cambia el orden:** en la v1.0 el dashboard (F3.5) iba antes que los vencimientos (F3).
Pero una licencia que nunca vence ni suspende no vale nada: primero tiene que funcionar, después
se mira en un tablero.

<svg viewBox="0 0 880 352" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Fases del módulo de licencias en el orden de la v1.1">
  <g font-family="system-ui, sans-serif">
    <rect x="20" y="20" width="840" height="46" rx="6" fill="#DCFCE7" stroke="#22C55E"/>
    <text x="38" y="40" font-size="12.5" font-weight="700" fill="#14532D">F0 · Cimientos y tope</text>
    <text x="230" y="40" font-size="11.5" fill="#166534">tablas, modelos, interruptor en super admin y tope de agentes desde la licencia</text>
    <text x="230" y="57" font-size="10.5" font-style="italic" fill="#15803D">entregable: con el interruptor encendido, el tope impide dar de alta más agentes</text>

    <rect x="20" y="74" width="840" height="46" rx="6" fill="#DCFCE7" stroke="#22C55E"/>
    <text x="38" y="94" font-size="12.5" font-weight="700" fill="#14532D">F1 · Demo automática</text>
    <text x="230" y="94" font-size="11.5" fill="#166534">toda cuenta nueva nace con el plan de registro; las existentes no se tocan</text>
    <text x="230" y="111" font-size="10.5" font-style="italic" fill="#15803D">entregable: cuenta nueva con demo activa desde el registro</text>

    <rect x="20" y="128" width="840" height="46" rx="6" fill="#DBEAFE" stroke="#3B82F6"/>
    <text x="38" y="148" font-size="12.5" font-weight="700" fill="#1E3A8A">F2 · Permisos, catálogo y gestión</text>
    <text x="230" y="148" font-size="11.5" fill="#1E40AF">casillas en super admin, planes editables, vista cruzada y emitir licencias</text>
    <text x="230" y="165" font-size="10.5" font-style="italic" fill="#2563EB">entregable: un agente con «Gestionar» asigna un plan a una cuenta fuera de licencia</text>

    <rect x="20" y="182" width="840" height="46" rx="6" fill="#FEF3C7" stroke="#F59E0B"/>
    <text x="38" y="202" font-size="12.5" font-weight="700" fill="#78350F">F3 · Vencimientos, avisos y silencio</text>
    <text x="230" y="202" font-size="11.5" fill="#92400E">revisión diaria, cola de periodos, avisos 10 y 5 días, suspender y callar el motor</text>
    <text x="230" y="219" font-size="10.5" font-style="italic" fill="#B45309">entregable: vence → suspendida y sin bot ni campañas; renovar → todo retoma</text>

    <rect x="20" y="236" width="840" height="46" rx="6" fill="#EDE9FE" stroke="#8B5CF6"/>
    <text x="38" y="256" font-size="12.5" font-weight="700" fill="#4C1D95">F4 · Dashboard de Licencias</text>
    <text x="230" y="256" font-size="11.5" fill="#5B21B6">indicadores, gráficos, filtros 7/14/30/60 días y acciones directas</text>
    <text x="230" y="273" font-size="10.5" font-style="italic" fill="#6D28D9">entregable: tablero visible solo en cuentas de Wintook para agentes con permiso</text>

    <rect x="20" y="290" width="840" height="46" rx="6" fill="#F1F5F9" stroke="#94A3B8"/>
    <text x="38" y="310" font-size="12.5" font-weight="700" fill="#334155">F5 · Vista del cliente</text>
    <text x="230" y="310" font-size="11.5" fill="#475569">Configuración › Licencia en solo lectura, banner de aviso y pantalla de cuenta vencida</text>
    <text x="230" y="327" font-size="10.5" font-style="italic" fill="#64748B">entregable: el cliente ve su plan, sus agentes y cuándo vence</text>
  </g>
</svg>

Cada fase se entrega con el interruptor general **apagado**: se puede subir a producción sin que
ninguna cuenta cambie, y se enciende cuando todo esté probado.

---

## 11. Riesgos y puntos finos

- **Distinguir "fuera de licencia" de "vencida".** Sin licencia = no gestionada, se comporta como
  hoy. Vencida = tuvo y expiró, queda suspendida. El sistema debe tratarlas distinto siempre.
- **Cuentas internas de Wintook.** Hay que asegurarse de que no se auto-suspendan: lista de
  exclusión o licencia interna perpetua.
- **Reactivar no es automático.** Al renovar una cuenta suspendida hay que devolverla a activa
  explícitamente; no basta con emitir la licencia.
- **Continuidad de la cola.** Si la revisión diaria corre con retraso, al promover el siguiente
  periodo hay que recalcular su inicio para no regalar ni comer días.
- **Zona horaria del vencimiento.** Definir si vence al final del día en la zona de la cuenta.
- **Agentes por encima del tope.** Por diseño no se expulsa a nadie, así que el conteo puede
  quedar temporalmente por encima del límite. Es esperado, no un error.
- **Cancelar un periodo en cola** sin afectar al vigente debe ser posible.
- **Despliegue seguro:** el enforcement se controla con un interruptor general apagado por
  defecto, **en la configuración del super admin** (no en `.env`).
- **Ya casi no caben banderas (v1.1).** Los paquetes del plan usan las banderas de funciones de
  la cuenta (`accounts.feature_flags`, un entero de 63 posiciones) y van **62 usadas**. Una función
  nueva que se quiera vender aparte no tendría lugar. Si hace falta, la salida es una segunda
  columna de banderas; queda fuera de la v1 pero hay que tenerlo en cuenta al armar el catálogo.
- **La lista de funciones vendibles cambió desde agosto.** Hay módulos nuevos con bandera propia
  (por ejemplo llamadas de WhatsApp, `whatsapp_calls`): el catálogo del plan debe leer la lista
  de `config/features.yml` en vivo, no una copia escrita en el código.
- **Callar el motor sin perder mensajes (v1.1).** Hoy la entrada de WhatsApp descarta los
  mensajes de una cuenta suspendida; con §5.1 pasan a guardarse. Hay que cambiar ese chequeo y
  probar los demás canales.
- **El plan que apaga funciones.** Si el plan es autoritativo (§14.1), un cliente que hoy usa una
  función que su plan no incluye la pierde al emitirle la licencia. El formulario de emisión debe
  mostrar qué se va a apagar antes de confirmar.

---

## 12. El sistema de licencias anterior

En producción existen columnas y tablas de un intento previo que nunca llegó a funcionar
(fechas, periodo y tipo de licencia). **No se importan.** Se leen solo como **referencia** para
decidir: la vista cruzada muestra la licencia vieja con un semáforo 🟢 vigente / 🔴 vencida, y el
formulario de alta puede venir pre-llenado con esos valores — pero siempre crea una licencia
**nueva** en el sistema actual. Una vez migradas todas las cuentas, esas columnas se pueden
eliminar.

> ⏳ **Pendiente:** conocer la estructura de los catálogos viejos (`license_periods` y
> `license_types`) para poder mostrar el número de agentes en esa referencia.

---

## 13. Decisiones ya tomadas

| Tema | Decisión |
|---|---|
| Sujeto de la licencia | La cuenta y su uso de la plataforma |
| A quién aplica | Nuevas → demo automática. Existentes → fuera de licencia hasta que Wintook les asigne una |
| Al vencer | Suspender toda la cuenta |
| Tope al bajar de plan o vencer | Solo bloquear altas nuevas; nunca expulsar agentes |
| Pago por adelantado | Periodo encolado que arranca solo al terminar el vigente |
| Administración | Personal de Wintook con permiso; el cliente solo consulta |
| Permisos (v1.1) | En el super admin: «Ver licencias» y «Gestionar licencias» por agente; «Cuenta de Wintook» por cuenta. Nada en `.env` |
| Dónde se ve el dashboard (v1.1) | Solo en cuentas marcadas «de Wintook», que además nunca se suspenden |
| Al vencer (v1.1) | Se bloquea el acceso y se callan Agentes IA, seguimientos y campañas; los mensajes entrantes se guardan |
| Interruptor general (v1.1) | En la configuración del super admin, apagado al desplegar |
| Orden de fases (v1.1) | Tope → demo → gestión → vencimiento y silencio → dashboard → vista del cliente |
| Avisos | Correo a administradores + banner, 10 y 5 días antes |
| Planes | Catálogo propio con nombre, días, agentes y set de canales y funciones |
| Datos del sistema viejo | No se importan; se muestran como referencia para decidir |
| Superficie principal | Dashboard de Licencias con indicadores, gráficos y tabla filtrable |

---

## 14. Preguntas abiertas

1. **¿El plan es autoritativo?** Es decir, al activarlo, ¿debe apagar los canales y funciones que
   no incluye, o solo encender los suyos y dejar lo demás como esté? La propuesta es que sea
   autoritativo al emitir, con ajustes manuales posteriores permitidos.
2. **¿El vencimiento es al final del día** en la zona horaria de la cuenta?
3. ~~¿Qué cuentas internas deben quedar excluidas?~~ **Resuelta en v1.1:** las marcadas «Cuenta de
   Wintook» en el super admin.
4. **Estructura de los catálogos viejos** para completar la referencia (§12).
5. **¿Periodo de gracia?** (v1.1) Hoy la cuenta se suspende el mismo día que vence. ¿Unos días
   de gracia, o un modo «solo lectura» antes de suspender? Por omisión: sin gracia.
6. **¿Se licencia la IA?** (v1.1) El plan cuenta solo agentes humanos, y el costo está en los
   Agentes IA, los mensajes de IA y las campañas. ¿El plan debe limitar cuántos Agentes IA, cuántos
   mensajes de IA al mes o cuántos envíos? Por omisión: fuera de la v1.
7. **¿Extender la demo de una cuenta?** (v1.1) Hoy habría que emitirle una licencia nueva. ¿Un
   botón «Extender demo»? ¿Cuentas que se creen sin demo?
8. **Catálogo comercial.** La dirección define qué planes se venden; F2 lo necesita para el seed.


---

## 15. Avance por fase

### F0 — Cimientos y tope ✅ (23/10/2026)

**Qué se hizo**

| Pieza | Archivo |
|---|---|
| Catálogo de planes, con la Demo 15 días / 2 agentes ya creada y marcada de registro | `db/migrate/20261029100000_create_license_plans.rb`, `app/models/license_plan.rb` |
| Licencias por cuenta: a lo sumo una activa (índice único parcial) y N en cola | `db/migrate/20261029100100_create_account_licenses.rb`, `app/models/account_license.rb` |
| El tope de agentes desde la licencia | `app/models/concerns/account_licensable.rb`, `app/models/account.rb`, `enterprise/app/models/enterprise/account.rb` |
| Interruptor «Aplicar licencias», apagado | `app/services/licenses/enforcement.rb`, `config/installation_config.yml` |
| Tarjeta «Licencias» en Super admin › Configuración | `enterprise/app/helpers/super_admin/features.yml`, `enterprise/app/controllers/enterprise/super_admin/app_configs_controller.rb` |

**Cómo funciona**

```
 Alta de un agente → AgentsController#validate_limit (ya existía)
                       └─ usage_limits[:agents] ← Enterprise::Account#agent_limits
                                                     └─ license_agent_limit
   interruptor apagado ............ nil → manda lo de siempre (limits / config)
   cuenta de Wintook .............. nil
   sin ninguna licencia ........... nil → fuera de licencia, como hoy
   licencia activa ................ max_agents de la licencia
   tuvo licencia, ninguna activa .. 0   → no admite agentes nuevos
 Si no alcanza → 402 «Please purchase more licenses» (ya existía). Nadie es expulsado.
```

- El interruptor vive en `InstallationConfig` (`LICENSE_ENFORCEMENT_ENABLED`) y se cambia en
  Super admin › Configuración › Licencias. Guardar borra la caché de `GlobalConfig`: surte efecto
  al momento.
- Un plan marcado de registro desmarca al anterior (solo uno a la vez).
- Todavía no hay pantalla para planes ni licencias: llega en F2. La Demo y las licencias se pueden
  crear por consola para probar.

**Pila de pruebas** (26/27 en verde; la que falla es previa: `FB_APP_ID` ya existe en la base de dev)

- `spec/models/license_plan_spec.rb`: validaciones, `features` como lista, un solo plan de registro, el desactivado no cuenta.
- `spec/models/account_license_spec.rb`: una sola activa (también por índice), varias en cola, vence después de empezar, la copia no cambia al editar el plan.
- `spec/models/concerns/account_licensable_spec.rb`: interruptor apagado, sin licencia, activa por encima de `limits`, vencida → 0, cuenta de Wintook.
- `spec/services/licenses/enforcement_spec.rb`: apagado por omisión y encendido desde `InstallationConfig`.
- `spec/enterprise/controllers/api/v1/accounts/agents_license_spec.rb`: 402 al pasar el tope sin expulsar, alta con lugar.
- `spec/controllers/super_admin/app_config_controller_spec.rb`: el grupo «licenses» muestra y guarda el interruptor.
- Ojo: una prueba que enciende el interruptor deja su valor en la caché de Redis aunque la
  transacción se deshaga → `GlobalConfig.clear_cache` al terminar.

**Cómo probarlo a mano**: encender «Aplicar licencias» en el super admin, crear por consola
`AccountLicense.create!(account: cuenta, name: 'Prueba', max_agents: 2, duration_days: 30)` y
dar de alta agentes en esa cuenta: el tercero recibe el aviso de licencias.


### F1 — Demo automática ✅ (23/10/2026)

**Qué se hizo**

| Pieza | Archivo |
|---|---|
| Emitir la demo copiando el plan de registro | `app/services/licenses/demo_issuer.rb` |
| Engancharla al registro de cuentas | `app/builders/account_builder.rb` (`create_account`) |

**Cómo funciona**

```
 Registro (API v1/v2, Google, onboarding) → AccountBuilder#create_account
   └─ Account.create!
   └─ ¿super_admin? (instalación inicial = cuenta de Wintook) → sin demo
   └─ Licenses::DemoIssuer
        plan de registro activo? ── no → la cuenta nace sin licencia (como hoy)
        ¿ya tiene licencias?      ── sí → no se toca
        sí → AccountLicense activa: nombre, tipo, agentes y días copiados del plan;
             vence en starts_at + días; metadata.source = 'signup'
```

- **Se emite aunque el interruptor esté apagado** (decisión 23/10/2026): no limita nada hasta
  encenderlo, pero la cuenta ya nace con su vencimiento.
- **Nunca tumba un registro:** va en su propio savepoint; si falla, la cuenta nace sin licencia y
  queda `[LICENSES] demo no emitida…` en el log.
- Las cuentas creadas desde el panel del super admin o la API de plataforma (`Account.create!`
  directo) nacen sin licencia: Wintook se la asigna en F2.
- Los canales y funciones del plan todavía no se aplican a la cuenta (pregunta abierta 14.1, F2).

**Pila de pruebas** (todas las nuevas en verde)

- `spec/services/licenses/demo_issuer_spec.rb`: copia el plan con su vencimiento, no duplica, sin plan de registro → sin licencia, un error no rompe y queda en el log.
- `spec/builders/account_builder_license_spec.rb`: cuenta nueva con demo, la de instalación inicial sin demo, registro sin plan de registro sigue funcionando.
- Caminos de registro existentes (API v1/v2, enterprise v2): en verde. Onboarding y Google: 5 fallas que ya existían sin este cambio (comprobado apartándolo).

**Cómo probarlo a mano**: registrar una cuenta nueva (o `AccountBuilder.new(email: …, user_password: …, confirmed: true).perform` en consola) y revisar `cuenta.current_license`: Demo, 15 días, 2 agentes.


### F2a — Permisos, catálogo y gestión (servidor) ✅ (23/10/2026)

**Qué se hizo**

| Pieza | Archivo |
|---|---|
| Casillas «Ver licencias» / «Gestionar licencias» en Super admin › Usuarios | `app/models/user.rb`, `app/dashboards/user_dashboard.rb`, `_user.json.jbuilder` |
| Casilla «Cuenta de Wintook» en Super admin › Cuentas | `app/models/concerns/account_licensable.rb`, `app/dashboards/account_dashboard.rb` |
| La puerta doble de la API | `app/controllers/api/v1/accounts/licenses/base_controller.rb` |
| Catálogo de planes | `…/licenses/plans_controller.rb` (+ validación de funciones en `LicensePlan`) |
| Vista cruzada de cuentas con filtros | `…/licenses/accounts_controller.rb` |
| Emitir (ya / en cola) y cancelar programadas | `…/licenses/account_licenses_controller.rb`, `app/services/licenses/issuer.rb` |

**Cómo funciona**

```
 /api/v1/accounts/:cuenta/licenses/*
   ¿:cuenta es «Cuenta de Wintook»? ─ no → 401
   ¿el usuario tiene «Ver licencias»? ─ no → 401
   escribir (planes, emitir, cancelar) además pide «Gestionar licencias»

 GET   plans                       catálogo + available_features (de config/features.yml, en vivo)
 POST  plans · PATCH plans/:id     crear / editar (no se borran: active = false)
 GET   accounts?estado=&dias=&q=   sin_licencia · demo · vigente · por_vencer (7 d) · vencida
 GET   accounts/:id                la cuenta + historial de licencias
 POST  account_licenses            { target_account_id, license_plan_id, start: now|queue, max_agents?, duration_days?, name?, notes? }
 POST  account_licenses/:id/cancel solo una programada
```

- **Emitir «ya»** cancela la activa anterior y, si la cuenta estaba suspendida, la reactiva.
  **«En cola»** arranca al terminar la última vigente o programada; sin nada vigente, arranca ya.
- La licencia guarda quién la dio (`created_by`) y `metadata.source = 'manual'`.
- Los canales y funciones del plan **solo se guardan**; todavía no se aplican a la cuenta
  (decisión 23/10/2026, pregunta 14.1).
- «Gestionar» incluye «Ver». Un agente con permiso que entra desde una cuenta de cliente no ve nada.

**Pila de pruebas** (45 de licencias en verde)

- `spec/services/licenses/issuer_spec.rb`: activa ya y cancela la anterior, ajustes por cuenta sin tocar el plan, cola encadenada, cola sin vigente, reactiva suspendida, forma de arrancar inválida.
- `spec/models/user_licenses_spec.rb`: sin marcar, gestionar incluye ver, no pisa otros atributos.
- `spec/controllers/api/v1/accounts/licenses/licenses_api_spec.rb`: 401 sin permiso y desde cuenta de cliente, «Ver» no escribe, catálogo crear/editar/rechazar función inexistente, filtros por estado, detalle con historial, emitir a otra cuenta, cancelar solo programada.
- `spec/controllers/super_admin/licenses_permissions_spec.rb`: las casillas del usuario y de la cuenta se guardan.
- Fichas existentes del super admin: 3 fallas que ya existían sin este cambio (comprobado apartándolo).

**Cómo probarlo a mano**: en el super admin marcar una cuenta como «Cuenta de Wintook» y a un
agente suyo «Gestionar licencias»; con su sesión, `GET /api/v1/accounts/<esa cuenta>/licenses/accounts?estado=sin_licencia`.
La pantalla llega en F2b.


### F2b — Pantallas de gestión ✅ (23/10/2026)

**Qué se hizo**

| Pieza | Archivo |
|---|---|
| Entrada «Licencias» en el menú, solo en cuentas de Wintook y con «Ver licencias» | `sidebarItems/v2/index.js` (`licensesOnly`), `Sidebar.vue` (`canSeeLicenses`), `_account.json.jbuilder` (`wintook_internal`) |
| Ruta `/app/accounts/:id/licenses` | `routes/dashboard/licenses/routes.js` |
| Pantalla con pestañas Cuentas / Planes | `views/licenses/Index.vue`, `AccountsTab.vue`, `PlansTab.vue` |
| Formularios: plan, asignar licencia, historial | `views/licenses/PlanModal.vue`, `IssueModal.vue`, `HistoryModal.vue` |
| Cliente de la API y textos es/en | `api/licenses.js`, `i18n/locale/{es,en}/licenses.json` |

**Cómo se ve**

```
 Licencias
 Qué plan tiene cada cuenta, cuándo vence y cuántos agentes puede tener.
 [ Cuentas ] [ Planes ]

 Cuentas:  [ Buscar por nombre o número ] [ Todas ▾ ]  (Por vencer → [ 7 ] días)
   Cuenta              Estado        Plan          Agentes  Vence                Acciones
   Grúas del Sur #12   [Demo]        Demo          1 / 2    6/11/2026 en 14 días [+ Asignar licencia] [Historial]
   Comercial Norte #8  [Por vencer]  Profesional   7 / 10   26/10/2026 en 3 días
                       +1 en cola
   Servicios SA #5     [Sin licencia] —            12       —

 Planes:                                                       [ Nuevo plan ]
   Plan        Días  Agentes  Tipo     Canales y funciones  Cuentas activas
   Demo [De registro]  15  2  Demo     0 incluidas          17              [Editar]
```

- **Asignar licencia**: eliges un plan activo y se precargan nombre, agentes y días; se ajustan
  solo para esa cuenta. Si ya tiene licencia, propone «En cola» (empieza al terminar la actual);
  «Ya» la reemplaza.
- **Historial**: todas sus licencias con fechas, agentes y quién la dio; una programada se puede
  cancelar.
- **Planes**: crear y editar con días, agentes, tipo, «de registro», activo y canales/funciones
  (agrupados; por ahora solo se guardan).
- Sin «Gestionar licencias» se ve todo pero no aparecen los botones de asignar, editar ni cancelar.
- Una fila con 7 días o menos se marca «Por vencer» aunque el filtro sea «Todas».
- Solo componentes nativos del dashboard (BaseSettingsHeader, woot-tabs, woot-label, woot-button,
  Modal, TableFooter).

**Pila de pruebas**

- `views/licenses/licenses.spec.js` (5): filtros que se mandan a la API, fila «por vencer» y su color, agentes usados/tope, asignar precarga el plan y manda lo ajustado, con licencia vigente propone «en cola», el plan separa canales de funciones.
- `sidebarItems/v2/index.spec.js` (10): la entrada «Licencias» existe, va marcada `licensesOnly` y tiene su propio menú.
- `licenses_api_spec.rb`: la cuenta le dice al navegador si es de Wintook.
- En navegador: pendiente.

**Cómo probarlo**: en el super admin marcar la cuenta como «Cuenta de Wintook» y a tu usuario
«Gestionar licencias»; recargar el dashboard de esa cuenta: aparece «Licencias» en el menú.


### F3 — Vencimientos, avisos y silencio ✅ (23/10/2026)

**Qué se hizo**

| Pieza | Archivo |
|---|---|
| Vencer, promover la cola y suspender (cada hora, minuto 5) | `app/services/licenses/expiration_service.rb`, `app/jobs/licenses/expiration_job.rb`, `config/schedule.yml` |
| Avisos 10 y 5 días antes (diario 15:00 UTC = 9:00 CDMX) | `app/services/licenses/reminder_service.rb`, `app/jobs/licenses/reminder_job.rb` |
| Correo a los administradores, en el idioma de la cuenta | `app/mailers/administrator_notifications/license_notifications_mailer.rb` + `expiring.liquid` |
| Silencio del motor con la cuenta suspendida | `app/services/licenses/silence.rb` + analizador, `ContactTrackingJob`, `TrackingDispatch::Claim`/`SendJob`, `Calls::MissedCallService`, `WhatsappCallEventsJob` |
| WhatsApp guarda los mensajes de una cuenta suspendida | `app/jobs/concerns/whatsapp_channel_lookup.rb` |

**Cómo funciona**

```
 Cada hora — Licenses::ExpirationService
   activa con expires_at pasado → expired
     ├─ hay programada → se promueve (conserva su inicio; si también venció, sigue a la próxima)
     │                    y reactiva la cuenta si estaba suspendida
     └─ no hay → cuenta suspendida (interruptor encendido y no es «Cuenta de Wintook»)
   programada cuyo inicio ya pasó y sin activa → se promueve
   interruptor encendido: cuentas con licencia, sin activa ni cola y aún activas → suspendidas

 Diario — Licenses::ReminderService (solo con el interruptor encendido)
   activa con ≤ 10 días → correo «vence en N días» (una vez); ≤ 5 días → otro (una vez)
   no a cuentas de Wintook ni a las que ya tienen periodo en cola

 Cuenta suspendida — Licenses::Silence
   entran y se guardan los mensajes de todos los canales (WhatsApp incluido)
   Agente IA no contesta · primer mensaje del seguimiento se reprograma cada hora
   campañas no se toman / vuelven a la fila · llamada perdida sin mensaje al cliente
   llamadas entrantes ignoradas (nadie puede entrar a contestar)
 Al renovar (emitir «ya» o promover la cola) la cuenta se reactiva y todo retoma solo.
```

- El correo escribe la fecha como dd/mm/aaaa: el español del proyecto no trae
  `date.formats.long` y `I18n.l` habría fallado (lo detectó la prueba).
- El banner en el dashboard llega con la vista del cliente (F5).
- Los jobs se cargan al arrancar Sidekiq: en dev hay que reiniciar `chatwoot-dev` para que
  empiecen a correr.

**Pila de pruebas** (108 de licencias y de lo tocado, en verde)

- `expiration_service_spec.rb`: vence y suspende, promueve sin corte, encadena atrasadas, promover reactiva, Wintook nunca, suspende las viejas al encender, apagado solo marca, no toca vigentes.
- `reminder_service_spec.rb`: 10 y 5 días una sola vez, no con más de 10 / Wintook / con cola, apagado no avisa.
- `license_notifications_mailer_spec.rb`: destinatarios, asunto en español, plan y cuenta.
- `silence_spec.rb`: qué es callada, el despachador no toma de una suspendida, el primer mensaje se reprograma sin quedar fallido.
- `missed_call_service_spec.rb`: con la cuenta suspendida no se manda y queda dicho.
- `whatsapp_events_job_spec.rb`: actualizado — con la cuenta suspendida el mensaje se guarda.
- Existentes del despachador, `SendJob` y llamadas: en verde.


### F4 — Tablero de licencias ✅ (23/10/2026)

**Qué se hizo**

| Pieza | Archivo |
|---|---|
| Los números, en pocas consultas agregadas | `app/services/licenses/summary.rb` |
| `GET …/licenses/summary` (misma puerta: Wintook + «Ver licencias») | `…/licenses/summary_controller.rb`, `config/routes.rb` |
| Pestaña «Resumen» (la primera) | `views/licenses/SummaryTab.vue`, `Index.vue` |
| Cuentas puede abrirse ya filtrada | `views/licenses/AccountsTab.vue` (`initialEstado`, `initialDias`) |

**Cómo se ve**

```
 [ Resumen ] [ Cuentas ] [ Planes ]
 Por vencer en: (7 días) 14 días 30 días 60 días
 ┌──────────┬──────────┬────────────────────┬──────────┬──────────────┬────────────────────────┐
 │ De pago  │ En demo  │ Por vencer (7 días)│ Vencidas │ Sin licencia │ Conversión demo → pago │
 │    4     │    2     │         1          │    1     │      9       │          25%           │
 └──────────┴──────────┴────────────────────┴──────────┴──────────────┴────────────────────────┘
   clic en una tarjeta → Cuentas con ese filtro (conversión no filtra)
 ┌ Vencimientos de las próximas semanas ──┐  ┌ Cuentas por plan ───────────────┐
 │ ▁ ▁ █ ▁ ▃ ▁ ▁ ▁ ▁   (9 semanas, 60 d)  │  │ █ Profesional  ▆ Básico  ▂ Demo │
 └────────────────────────────────────────┘  └─────────────────────────────────┘
```

- **Forma elegida con la guía de visualización:** los indicadores son tarjetas (números, no
  gráficas); vencimientos por semana y cuentas por plan son barras de una sola serie, sin leyenda
  (el título la nombra), con tooltip al pasar el mouse.
- **Color:** el `woot-600` del tema activo, leído en el navegador. Validado con
  `validate_palette.js`: con el tema por omisión pasa luminosidad y contraste ≥ 3:1 en claro y
  oscuro (el `woot-500` fallaba en los dos). Los valores exactos están en el tooltip y en la
  tabla de Cuentas.
- Componentes nativos: `ReportMetricCard`, `BarChart` (vue-chartjs), `woot-button`, `woot-tabs`.
- Conversión = de las cuentas que alguna vez tuvieron demo, cuántas recibieron una licencia de pago
  después de su primera demo.

**Pila de pruebas**

- `spec/services/licenses/summary_spec.rb`: cada indicador (midiendo la diferencia: la base de
  pruebas es la de dev), conversión, 9 semanas de vencimientos y activas por plan.
- `spec/controllers/api/v1/accounts/licenses/summary_api_spec.rb`: responde con permiso, 401 sin él.
- `views/licenses/licenses.spec.js` (+3): tarjetas y ventana de días, clic abre Cuentas filtrada
  (conversión no), una sola serie con color del tema.
- En navegador: pendiente (incluye mirar la gráfica dibujada).


### F5 — Vista del cliente ✅ (23/10/2026)

**Qué se hizo**

| Pieza | Archivo |
|---|---|
| La cuenta sabe su licencia (`license` en accounts/show; nil = fuera de licencia) | `account_licensable.rb` (`license_summary`), `accounts/show.json.jbuilder` |
| El usuario sabe si su cuenta venció por licencia | `account_licensable.rb` (`license_expired?`), `_user.json.jbuilder` |
| Configuración › Licencia (solo lectura, administradores, solo si la cuenta tiene licencia) | `routes/dashboard/settings/license/`, `sidebarItems/settings.js` (`visibleGetter`), `store/modules/accounts.js` (`currentAccountHasLicense`) |
| Aviso arriba del dashboard a 10 días o menos | `components/app/LicenseExpiringBanner.vue`, `App.vue` |
| Pantalla de licencia vencida | `routes/dashboard/suspended/Index.vue` |

**Cómo se ve**

```
 Configuración › Licencia
   Profesional [Vigente]
   Agentes 4 / 5  ▓▓▓▓▓▓▓▓░░      Inicio 01/10/2026      Vence 30/10/2026 · Quedan 7 días
   Siguiente periodo: Profesional, del 30/10/2026 al 28/04/2027, con 5 agentes.
   Solo lectura. Para cambiar de plan o renovar, ponte en contacto con nosotros.

 Aviso (administradores, ≤ 10 días, sin periodo en cola; se cierra por el día):
   ⚠ Tu licencia vence en 7 días. Si no se renueva, la cuenta se suspende.   [ Ver licencia ] ✕

 Cuenta suspendida por licencia:
   Tu licencia venció — Nadie puede entrar hasta que se renueve. Los mensajes de tus clientes
   se siguen guardando y estarán aquí al renovar. Ponte en contacto con nosotros para renovarla.
```

- La sección y el aviso no salen en cuentas fuera de licencia: funcionan como siempre.
- Una cuenta suspendida a mano (sin licencia vencida) sigue viendo el aviso genérico de Chatwoot.
- Componentes nativos: `BaseSettingsHeader`, `woot-label`, `Banner`, `EmptyState`.

**Pila de pruebas**

- `spec/controllers/api/v1/accounts/licenses/account_license_view_spec.rb`: sin licencia nada, con licencia periodo/agentes/siguiente, el perfil marca la cuenta vencida.
- `components/app/LicenseExpiringBanner.spec.js`: 10 días sí / 11 no, no con cola / sin licencia / sin ser administrador, cerrado no vuelve el mismo día.
- Batería completa de licencias: 111 de servidor + 21 de pantallas en verde.
- En navegador: pendiente.

---

**Módulo completo (F0–F5).** Para encenderlo: Super admin › Configuración › Licencias ›
«Aplicar licencias». Antes conviene probar en el navegador las pantallas de F2b, F4 y F5.

---

### Ajustes tras traer develop (02/11/2026)

**Migraciones renumeradas.** `20261029100000` chocaba con `create_access_roles` de develop: en una base que recibiera
primero develop, la de planes contaría como aplicada y nunca se crearía. Ahora son `20261105100000` (planes) y
`20261105100100` (licencias por cuenta); si la tabla ya existe no hacen nada (bases donde corrió con el número viejo).

**Menú secundario: Resumen · Cuentas · Planes.** Antes eran pestañas dentro de la página; ahora son opciones del menú
secundario, una ruta cada una (`licenses_summary`, `licenses_accounts`, `licenses_plans`) sobre la misma pantalla
(`meta.tab`), sin pestañas. `licenses` (la del menú principal) lleva al Resumen; no es la del Resumen para que el
menú no la marque activa en Cuentas y Planes. La tarjeta del resumen abre Cuentas con su filtro en la dirección
(`?estado=&dias=`), así que también se puede compartir. El encabezado dice la sección.

Pruebas: 30 de navegador en verde (menú + `Index` nuevo). Sin probar en navegador.

**Cuentas y Planes con el molde de la lista de plantillas de WhatsApp.** Filtros en un recuadro (búsqueda con lupa,
listas y «Limpiar filtros»), tabla con encabezado fijo y solo ella con scroll, acciones con íconos junto al nombre y
paginado con «Por página». Cuentas: buscar, estado (y días si es «por vencer»); asignar licencia e historial como
íconos; por página 10/25/50/100 (el servidor llega hasta 100); el orden lo pone el servidor. Planes: buscar, tipo y
activos/desactivados; columnas Plan, Días, Agentes y Cuentas activas se ordenan con clic; editar junto al nombre;
«Nuevo plan» pasa al encabezado de la página (como «Nueva plantilla»). Los planes no se borran: se desactivan al
editarlos. Pruebas: 33 de navegador en verde.

**Crear y editar un plan es una página, no un modal.** «Nuevo plan» y el lápiz llevan a `licenses/plans/new` y
`licenses/plans/:id/edit` (misma pantalla, `meta.tab = plan_form`, `PlanForm.vue`): «‹ Planes» y «Guardar» en el
encabezado como el editor de plantillas, datos en recuadros (Datos del plan · Canales · Funciones). Al guardar
regresa a la tabla; salir con cambios sin guardar lo pregunta (guardas `beforeRouteUpdate`/`beforeRouteLeave` de
`Index.vue`). En el menú sigue marcada «Planes». Sin «Gestionar licencias» o con un plan que no existe, lo dice.
`PlanModal.vue` se borró. Pruebas: 36 de navegador en verde.

**Cuentas se ordena por columna y muestra sus fechas.** Por omisión, la cuenta creada más reciente primero. Clic en
Cuenta, Vence, Creada o Última modificación para ordenar (las fechas empiezan de la más reciente; el nombre, de la A);
mismos íconos que plantillas. Lo ordena el servidor (`sort` = name · expires_at · created_at · updated_at, `dir`,
lista cerrada: otro valor cae en created_at), porque la tabla se pagina allá; por vencimiento, las cuentas sin licencia
vigente van al final en los dos sentidos. «Última modificación» dice «—» si la cuenta no cambió después de crearse.
Estado, Plan y Agentes no se ordenan (se calculan). Pruebas: 16 de servidor y 38 de navegador en verde.

### F5.1 — La licencia en Configuración › General y la fila completa (02/11/2026)

**Qué se hizo.** El cliente ve el estado de su licencia también en **Configuración › General**: una sección «Licencia»
con el mismo diseño de dos columnas, entre «Configuración general» y el número de cuenta, solo si la cuenta tiene
licencia (las de fuera de licencia no ven nada, como en F5). Muestra plan, estado (verde / amarillo a 10 días o menos /
rojo vencida), agentes usados contra el tope con su barra, inicio y vencimiento, y la **fila completa** de licencias por
activarse, numerada («1.º en fila», «2.º en fila»…) con periodo y agentes; «Ver licencia» lleva a Configuración ›
Licencia, que ahora también muestra la fila completa (antes solo el siguiente periodo).

```
 Licencia                     ┌──────────────────────────────────────────────────┐
 El plan de la cuenta, sus    │ Profesional [Vigente]                Ver licencia │
 agentes y las licencias      │ Agentes 4 / 5 ▓▓▓▓▓▓▓▓░░  Inicio 01/11  Vence 01/12 │
 que siguen. Solo lectura.    ├──────────────────────────────────────────────────┤
                              │ Licencias en fila                                 │
                              │ Se activan solas, en este orden…                  │
                              │ [1.º en fila] Semestral  del 01/12 al 30/05 · 5   │
                              │ [2.º en fila] Anual      del 30/05 al 30/05 · 9   │
                              └──────────────────────────────────────────────────┘
```

**Piezas.** `Account#license_summary` manda `queue` (todas las programadas, en el orden en que se activan; `next` sigue
siendo la primera). `settings/license/LicenseStatusCard.vue` es la tarjeta de las dos pantallas (`compact` en General).
Pruebas: servidor 23 en verde (`account_license_view_spec` + fila en orden); navegador `LicenseStatusCard.spec.js` 4.

### F6 — Ficha de la cuenta (PLAN, 02/11/2026)

**Qué es.** Una página completa por cuenta (`licenses/accounts/:id`), como la captura de planes: todo lo de la cuenta en
un lugar y un registro de cada cambio con fecha, hora y quién. Se abre con clic en el nombre (o el ícono «Ver») en la
tabla de Cuentas; «‹ Cuentas» regresa.

```
 ‹ Cuentas                                    [Asignar licencia] [Agregar agentes]
 Grúas del Norte  #568   ● Vigente · Plan Profesional · vence 15/12/2026 (en 43 días)

 ┌ Agentes ─────┐ ┌ Licencia ───────┐ ┌ Funciones ──┐ ┌ Bandejas ──┐
 │  8 de 10     │ │ Profesional     │ │ 24 activas  │ │ 5          │
 │  2 libres    │ │ +1 en cola      │ │ 2 fuera del │ │            │
 │              │ │                 │ │ plan        │ │            │
 └──────────────┘ └─────────────────┘ └─────────────┘ └────────────┘

  Resumen │ Agentes │ Funciones │ Licencias │ Registro de cambios
 ──────────────────────────────────────────────────────────────────
  02/11/2026 14:32  Ana Ruiz    Subió el tope de agentes de 5 a 7 · «pidió 2 más»
  01/11/2026 09:10  Ana Ruiz    Asignó la licencia «Profesional» (180 días, 5 agentes)
  30/10/2026 18:05  Juan Pérez  Agregó al agente Luis Gómez (agente)
  29/10/2026 11:47  Ana Ruiz    Encendió Campañas · apagó Llamadas WhatsApp
```

**Pestañas.**
- **Resumen:** tarjetas (agentes usados/tope, licencia y cola, funciones activas y fuera del plan, bandejas) y datos
  generales (creada, última modificación, suspendida, cuenta de Wintook).
- **Agentes:** quién está, rol, desde cuándo y cuántos lugares quedan.
- **Funciones:** canales y funciones de la cuenta con su interruptor, como el super admin; cada una dice si viene en
  su plan.
- **Licencias:** la vigente, las de la cola y las anteriores (lo que hoy muestra el modal de historial, incluida
  «cancelar» una programada).
- **Registro de cambios:** todo junto y en orden, con filtro por tipo y por fecha.

**Decisiones (02/11/2026).**
- **D6a Agregar agentes:** se muestra el tope con que se asignó la licencia. «Agregar agentes» **solo sube** el tope de
  la licencia vigente (p. ej. 5 → 7) sin emitir otra, con motivo opcional, y queda registrado. Bajarlo es asignar una
  licencia nueva: así nunca deja a alguien fuera de golpe. Solo con «Gestionar licencias».
- **D6b Funciones:** se encienden y apagan desde la ficha como en el super admin, solo con «Gestionar licencias», y queda
  registrado. **El plan no las aplica solo** (sigue abierta la 14.1): la pestaña marca qué funciones vienen o no en el
  plan; más adelante, un botón «Aplicar las del plan».
- **D6c Registro:** empieza desde que el sistema guarda cambios; lo anterior no aparece.

**Cómo se arma el registro (sin tablas nuevas).** El sistema ya guarda cambios con la gema `audited` (tabla `audits`,
del módulo enterprise): cuenta (nombre, estado, funciones en `feature_flags`, límites), agentes (`AccountUser`), bandejas,
equipos, automatizaciones. En dev ya hay cientos. Falta: auditar `AccountLicense` (asignar, subir tope, cancelar,
vencer) con `associated_with: :account`, y un servicio que lea los cambios de la cuenta y los traduzca a frases en
español (las funciones salen de comparar los bits de `feature_flags` antes y después). Los que hace el sistema (vencer,
promover la cola) dicen «Sistema».

**Fases.**
- **F6.1** Ficha con Resumen, Agentes y Licencias (servidor: `GET licenses/accounts/:id` ampliado).
- **F6.2** Agregar agentes (D6a) y auditoría de licencias.
- **F6.3** Funciones con interruptores (D6b).
- **F6.4** Registro de cambios con filtros.

**A cuidar.** Encender una función desde aquí cambia la cuenta del cliente al momento, igual que el super admin. Los
cambios hechos en el super admin también salen en el registro, porque es la misma auditoría. El modal de historial se
sustituye por la pestaña Licencias.

#### F6.1 — Ficha con Resumen, Agentes y Licencias ✅ (02/11/2026)

**Cómo se llega.** En Cuentas, el nombre abre `licenses/accounts/:id` (la ficha); el ícono de historial abre la misma
ficha en su pestaña Licencias (`?tab=licenses`). En el menú sigue marcada «Cuentas». «‹ Cuentas» regresa.

**Qué tiene.** Encabezado con nombre, número, estado (mismo color que la tabla), plan y vencimiento; acciones
«‹ Cuentas» y «Asignar licencia» (el formulario de siempre). Cuatro tarjetas: Agentes («8 de 10», «2 libres» o «Sin
tope»), Licencia (plan y «+N en cola»), Funciones (cuántas encendidas) y Bandejas. Pestañas (en la dirección):
- **Resumen:** estado de la cuenta, cuenta de Wintook, creada, última modificación, periodo y vencimiento.
- **Agentes:** nombre, correo, rol y desde cuándo está en la cuenta (fecha de `account_users`, no del usuario).
- **Licencias:** todas, la más reciente primero, con estado, tipo, agentes, periodo, quién la asignó y notas;
  cancelar una programada con el ícono. **Sustituye al modal de historial** (`HistoryModal.vue` se borró).

**Servidor.** `GET licenses/accounts/:id` suma `agents`, `inboxes_count` y `enabled_features` (los nombres; los
interruptores son F6.3). Pruebas: servidor 18 en verde (licencias API, +1 de la ficha); navegador 46 (+4 de la ficha).
Sin probar en navegador.

**Asignar licencia también es una página** (`licenses/accounts/:id/issue`, `IssueForm.vue`; `IssueModal.vue` se
borró): «‹ <cuenta>» y «Asignar» en el encabezado, recuadros «Plan y arranque» y «Valores para esta cuenta», al asignar
regresa a la ficha en Licencias y salir con algo capturado lo pregunta. Se abre desde la tabla y desde la ficha.

#### F6.2 — Agregar agentes y registro de licencias ✅ (02/11/2026)

**En pantalla.** «Agregar agentes» (encabezado de la ficha, con «Gestionar» y licencia vigente) abre un recuadro ahí
mismo, sin modal: cuántos agregar, motivo opcional y el resultado antes de guardar («Tope: 5 → 7»). Solo sube; para
bajar, se asigna una licencia nueva (D6a). El tope nuevo vale al momento (Enforcement lee la licencia vigente).

**Servidor.** `POST licenses/account_licenses/:id/add_agents { add, reason }` → `Licenses::AgentIncrease` (solo la
ACTIVA, de 1 a 1000; el motivo va como comentario del registro). `AccountLicense` ahora es `audited
associated_with: :account` (sin `updated_at`, `reminded_at`, `metadata`): asignar, subir el tope, cancelar y vencer
quedan en `audits` con quién y cuándo, listos para F6.4.

**Funciones marcadas en un plan nuevo.** Un plan nuevo arranca con lo que el sistema enciende a toda cuenta nueva:
`LicensePlan.default_feature_names` = lo encendido en el super admin (`ACCOUNT_LEVEL_FEATURE_DEFAULTS`, la misma fuente
que `Featurable#enable_default_features`) o, sin esa configuración, lo de `config/features.yml`; llega como
`default_features` en `GET licenses/plans`. Editar un plan guardado respeta lo suyo.

Pruebas: servidor 61 + 2 (servicio, API, modelo); navegador 51. Sin probar en navegador.

#### F6.3 — Funciones con interruptores ✅ (02/11/2026)

**En pantalla.** Pestaña **Funciones** en la ficha (entre Agentes y Licencias): canales y funciones en dos grupos, cada
una con el interruptor nativo (`woot-switch`). Buscar y filtrar (Todas · Encendidas · Apagadas · Diferentes al plan).
Los cambios **se juntan** («3 cambios sin guardar», marcados «Sin guardar») y se aplican con «Guardar cambios» o se
descartan: un clic por error no apaga un canal al momento; regresar un interruptor a como estaba deja de contar. Salir
de la ficha con cambios lo pregunta (cambiar de pestaña no). Sin «Gestionar» se ven atenuados y no responden.

**Contra el plan (D6b).** Si la licencia vigente tiene plan, cada función dice «Fuera del plan» (encendida y el plan no
la trae) o «Viene en el plan» (apagada y el plan sí la trae); la tarjeta Funciones dice cuántas están fuera. El plan no
las aplica solo (14.1 sigue abierta). Sin plan, no hay con qué comparar y lo dice.

**Servidor.** `PATCH licenses/accounts/:id/features { features: { nombre: true|false } }` (Gestionar): solo nombres de
`config/features.yml` (los demás se ignoran; sin cambios válidos, 422), enciende y apaga como el super admin y guarda;
`Account` ya es `audited`, así que el cambio de `feature_flags` queda en el registro con quién y cuándo. La ficha manda
`plan_features` (las del plan de la licencia vigente, o null).

Pruebas: servidor 21 de la API de licencias (+2); navegador 54 (+4). Sin probar en navegador.

#### F6.4 — Registro de cambios ✅ (02/11/2026) — F6 completa

**En pantalla.** Pestaña **Registro de cambios** (la última de la ficha): fecha y hora, quién (o «Sistema»), un ícono por
tipo y la frase; el motivo, si lo hay, debajo («Motivo: «pidió dos más»»). Filtros por tipo (Licencias · Agentes ·
Funciones · Cuenta · Bandejas · Otros · Accesos) y por fechas desde/hasta; 50 por vez con «Cargar más».

```
 02/11/2026 14:32  Ana Ruiz   🔒 Cambió el tope de agentes de «Profesional» de 5 a 7
                                  Motivo: «pidió dos más»
 01/11/2026 09:10  Ana Ruiz   🔒 Asignó la licencia «Profesional» (180 días, 5 agentes)
 30/10/2026 18:05  Juan Pérez 👥 Agregó a Luis Gómez como Agente
 29/10/2026 11:47  Ana Ruiz   ⚙ Encendió: campaigns · Apagó: whatsapp calls
 15/12/2026 00:05  Sistema    🔒 La licencia «Demo» pasó de Activa a Vencida
```

**De dónde sale.** `Licenses::AccountChangeLog` lee `audits` asociados a la cuenta y devuelve eventos estructurados
(`kind`, `event`, `params`, `comment`); la frase la arma `views/licenses/changeLog.js` con las traducciones
(`LICENSES.CHANGES`). Eventos: licencias (asignar, tope, estado, otros campos), agentes (entra, rol, sale), agentes en
bandejas, funciones (se descifra `feature_flags`: la función n es el bit 2^(n−1)), cuenta (suspender / reactivar,
renombrar, otros campos), bandejas (crear, cambiar con qué campos, borrar), equipos, automatizaciones, macros, webhooks y
accesos. `GET licenses/accounts/:id/changes?kind=&from=&to=&before=` (Ver licencias).

**Lo que se deja fuera.** La sincronización automática de plantillas de una bandeja (casi todo el ruido: 891 de 1 570 en
dev), los cambios de disponibilidad de un agente y, salvo que se elijan, los accesos (entrar y salir).

**Cambio en enterprise.** `Enterprise::Audit::AccountUser` ahora también registra `destroy` (quitar a un agente de la
cuenta), que antes no quedaba; el registro de eso empieza desde ahora. El nombre del agente en un cambio de rol sale del
registro de cuando entró, aunque ya no esté.

Pruebas: servidor 77 de licencias en verde (`account_change_log_spec` 8 con casos reales: tope con motivo, vencer por el
sistema, entra-rol-sale, funciones, suspender/renombrar, plantillas fuera, bandeja de un agente, paginar y fechas);
navegador 61 (`changeLog.spec.js` 6 + pestaña). Probado en dev contra la cuenta 2 (solo lectura): sale sin errores.
Sin probar en navegador. Falla de antes, no de licencias: `spec/enterprise/models/account_user_spec.rb:23`
(Roles-Permisos da `report_manage`).

### Bitácora de versiones

| Versión | Fecha | Cambios |
|---|---|---|
| **1.1** | 2026-10-23 | Permisos configurables en el super admin (Ver / Gestionar por agente, «Cuenta de Wintook» por cuenta), interruptor general fuera del `.env`, silencio del motor al vencer (§5.1), fases reordenadas (F0–F5), revisión contra el código actual (§2) y riesgos nuevos: banderas casi llenas, lista de funciones viva, plan que apaga funciones. Preguntas nuevas: gracia, licenciar la IA, extender demo. |
| **1.0** | 2026-08-07 | Primera versión ilustrada: alcance del módulo y sus puntos fuertes, el mecanismo de bloqueo que ya existe, modelo de datos, ciclo de vida con cola de periodos, tope de agentes, planes como paquete de canales y funciones, reparto de permisos, maqueta del Dashboard de Licencias, fases F0–F4, riesgos y decisiones. |
