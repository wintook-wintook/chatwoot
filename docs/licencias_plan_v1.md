# Módulo de Licencias de Plataforma — Plan v1.0

> **Versión:** 1.0 — documento vivo, se irá mejorando.
> **Rama:** `feat/licencias` · **Fecha:** 2026-08-07 · **Estado:** PLAN (sin implementar)
> **Sujeto de la licencia:** la **cuenta** (su uso de la plataforma), no software vendido a terceros.
> **Administra:** personal de Wintook (`SuperAdmin`). El cliente solo consulta.

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
- **Dashboard de Licencias** (SuperAdmin) con KPIs, gráficos, tabla filtrable y acciones.
- **Upgrade y renovación** desde el dashboard normal, con controles visibles solo a SuperAdmin.
- **Periodos encadenados** para pagos por adelantado.
- **Avisos** 10 y 5 días antes por correo y banner.
- **Suspensión al vencer**, con reactivación al renovar.
- **Vista de solo lectura** para el administrador de la cuenta.

### Fuera de la v1

Cobros y facturación · auto-renovación con cargo · portal de autoservicio · límites de otros
recursos (inboxes, contactos, mensajes) · periodo de gracia tras el vencimiento · desactivar
agentes sobrantes automáticamente · cortar en tiempo real un canal ya en uso.

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

## 8. Quién puede hacer qué

<svg viewBox="0 0 880 250" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Diferencia entre SuperAdmin de Wintook y administrador de la cuenta cliente">
  <rect x="20" y="16" width="410" height="200" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="2"/>
  <text x="40" y="44" font-family="system-ui, sans-serif" font-size="13.5" font-weight="700" fill="#14532D">SuperAdmin de Wintook</text>
  <text x="40" y="64" font-family="system-ui, sans-serif" font-size="11" font-style="italic" fill="#166534">personal interno</text>
  <g font-family="system-ui, sans-serif" font-size="11.5" fill="#166534">
    <text x="40" y="92">✓ Ver el Dashboard de Licencias completo</text>
    <text x="40" y="114">✓ Crear y editar los planes del catálogo</text>
    <text x="40" y="136">✓ Activar, renovar o programar licencias</text>
    <text x="40" y="158">✓ Definir el número de agentes</text>
    <text x="40" y="180">✓ Ver qué cuentas están fuera de licencia</text>
    <text x="40" y="202">✓ Cancelar un periodo programado</text>
  </g>

  <rect x="450" y="16" width="410" height="200" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="2"/>
  <text x="470" y="44" font-family="system-ui, sans-serif" font-size="13.5" font-weight="700" fill="#1E3A8A">Administrador de la cuenta</text>
  <text x="470" y="64" font-family="system-ui, sans-serif" font-size="11" font-style="italic" fill="#1E40AF">el cliente</text>
  <g font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">
    <text x="470" y="92">👁 Ver su plan y su fecha de vencimiento</text>
    <text x="470" y="114">👁 Ver agentes usados / disponibles</text>
    <text x="470" y="136">👁 Ver el próximo periodo si lo hay</text>
    <text x="470" y="158">👁 Recibir avisos y ver el banner</text>
  </g>
  <rect x="466" y="170" width="378" height="34" rx="6" fill="#FEE2E2" stroke="#EF4444"/>
  <text x="480" y="191" font-family="system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#7F1D1D">✕ No puede modificar nada de su licencia</text>

  <rect x="20" y="226" width="840" height="20" rx="6" fill="#F1F5F9"/>
  <text x="38" y="240" font-family="system-ui, sans-serif" font-size="11" fill="#334155">Ambos entran por la misma pantalla (Configuración › Licencia); lo que cambia es lo que ve cada uno. La restricción se valida en el servidor, no solo en pantalla.</text>
</svg>

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

## 10. Fases de entrega

<svg viewBox="0 0 880 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Roadmap de fases del módulo de licencias">
  <g font-family="system-ui, sans-serif">
    <rect x="20" y="20" width="840" height="40" rx="6" fill="#DCFCE7" stroke="#22C55E"/>
    <text x="38" y="38" font-size="12.5" font-weight="700" fill="#14532D">F0 · Cimientos y bloqueo</text>
    <text x="200" y="38" font-size="11.5" fill="#166534">tablas, modelos y conexión del tope de agentes con la licencia</text>
    <text x="200" y="53" font-size="10.5" font-style="italic" fill="#15803D">entregable: fijar un tope realmente impide dar de alta más agentes</text>

    <rect x="20" y="68" width="840" height="40" rx="6" fill="#DCFCE7" stroke="#22C55E"/>
    <text x="38" y="86" font-size="12.5" font-weight="700" fill="#14532D">F1 · Demo automática</text>
    <text x="200" y="86" font-size="11.5" fill="#166534">toda cuenta nueva nace con prueba; las existentes no se tocan</text>
    <text x="200" y="101" font-size="10.5" font-style="italic" fill="#15803D">entregable: cuenta nueva con demo activa desde el registro</text>

    <rect x="20" y="116" width="840" height="40" rx="6" fill="#DBEAFE" stroke="#3B82F6"/>
    <text x="38" y="134" font-size="12.5" font-weight="700" fill="#1E3A8A">F2 · Catálogo y gestión</text>
    <text x="200" y="134" font-size="11.5" fill="#1E40AF">planes personalizables, vista cruzada de cuentas y alta de licencias</text>
    <text x="200" y="149" font-size="10.5" font-style="italic" fill="#2563EB">entregable: Wintook ve quién está fuera del sistema y le asigna un plan</text>

    <rect x="20" y="164" width="840" height="40" rx="6" fill="#EDE9FE" stroke="#8B5CF6"/>
    <text x="38" y="182" font-size="12.5" font-weight="700" fill="#4C1D95">F3.5 · Dashboard</text>
    <text x="200" y="182" font-size="11.5" fill="#5B21B6">indicadores, gráficos, filtros por vencimiento y acciones directas</text>
    <text x="200" y="197" font-size="10.5" font-style="italic" fill="#6D28D9">entregable: tablero de control del negocio de licencias</text>

    <rect x="20" y="212" width="840" height="40" rx="6" fill="#FEF3C7" stroke="#F59E0B"/>
    <text x="38" y="230" font-size="12.5" font-weight="700" fill="#78350F">F3 · Vencimientos y avisos</text>
    <text x="200" y="230" font-size="11.5" fill="#92400E">revisión diaria, correos 10 y 5 días antes, cola de periodos y suspensión</text>
    <text x="200" y="245" font-size="10.5" font-style="italic" fill="#B45309">entregable: los periodos se encadenan solos; suspende solo si no hay cola</text>

    <rect x="20" y="260" width="840" height="34" rx="6" fill="#F1F5F9" stroke="#94A3B8"/>
    <text x="38" y="281" font-size="12.5" font-weight="700" fill="#334155">F4 · Vista del cliente</text>
    <text x="200" y="281" font-size="11.5" fill="#475569">pantalla de solo lectura, banner de aviso y pantalla de cuenta vencida</text>
  </g>
</svg>

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
- **Despliegue seguro:** el enforcement se controla con una llave global apagada por defecto.

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
| Administración | Exclusiva de SuperAdmin de Wintook; el cliente solo consulta |
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
3. **¿Qué cuentas internas** deben quedar excluidas del enforcement?
4. **Estructura de los catálogos viejos** para completar la referencia (§12).

---

### Bitácora de versiones

| Versión | Fecha | Cambios |
|---|---|---|
| **1.0** | 2026-08-07 | Primera versión ilustrada: alcance del módulo y sus puntos fuertes, el mecanismo de bloqueo que ya existe, modelo de datos, ciclo de vida con cola de periodos, tope de agentes, planes como paquete de canales y funciones, reparto de permisos, maqueta del Dashboard de Licencias, fases F0–F4, riesgos y decisiones. |
