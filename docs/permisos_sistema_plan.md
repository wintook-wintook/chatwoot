# Módulo de Permisos del Sistema — Plan v1.1

> **Versión:** 1.1 — documento vivo, se irá mejorando.
> **Rama:** `feat/system-permissions` (derivada de `develop`)
> **Fecha:** 2026-08-07 · **Estado:** PLAN (sin implementar)
> **Ubicación en producto:** **Configuración › Permisos** — pantalla exclusiva de administradores.

---

## 1. Estado actual: tres mecanismos que no se hablan

Hoy la plataforma decide "quién ve qué" en tres lugares distintos, y **solo uno de ellos llega al
backend**. Ese es el problema de fondo.

<svg viewBox="0 0 880 330" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Tres mecanismos de permisos actuales y si los aplica el backend">
  <text x="20" y="24" font-family="system-ui, sans-serif" font-size="13" font-weight="600" fill="#64748B">MECANISMO</text>
  <text x="620" y="24" font-family="system-ui, sans-serif" font-size="13" font-weight="600" fill="#64748B">¿LO APLICA EL BACKEND?</text>

  <!-- 1 -->
  <rect x="20" y="40" width="570" height="72" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="38" y="64" font-family="system-ui, sans-serif" font-size="14" font-weight="700" fill="#1E3A8A">1 · Rol binario</text>
  <text x="38" y="84" font-family="ui-monospace, monospace" font-size="12" fill="#1E40AF">account_users.role = agent | administrator</text>
  <text x="38" y="102" font-family="system-ui, sans-serif" font-size="12" fill="#1E3A8A">Todo o nada. El agente ve TODAS las conversaciones de sus inboxes.</text>
  <rect x="620" y="40" width="240" height="72" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="1.5"/>
  <text x="640" y="76" font-family="system-ui, sans-serif" font-size="22" fill="#15803D">✓</text>
  <text x="666" y="72" font-family="system-ui, sans-serif" font-size="12" font-weight="600" fill="#14532D">Sí, en policies</text>
  <text x="666" y="90" font-family="system-ui, sans-serif" font-size="11" fill="#166534">pero sin granularidad</text>

  <!-- 2 -->
  <rect x="20" y="124" width="570" height="86" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
  <text x="38" y="148" font-family="system-ui, sans-serif" font-size="14" font-weight="700" fill="#4C1D95">2 · Custom roles (enterprise)</text>
  <text x="38" y="168" font-family="ui-monospace, monospace" font-size="12" fill="#5B21B6">custom_roles.permissions = text[]   ·   6 permisos</text>
  <text x="38" y="186" font-family="system-ui, sans-serif" font-size="12" fill="#4C1D95">Feature `custom_roles`: premium + enabled:false. Aplicado solo en</text>
  <text x="38" y="202" font-family="system-ui, sans-serif" font-size="12" fill="#4C1D95">Article/Category/Portal/Report policies. NO filtra conversaciones.</text>
  <rect x="620" y="124" width="240" height="86" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="1.5"/>
  <text x="640" y="168" font-family="system-ui, sans-serif" font-size="22" fill="#B45309">~</text>
  <text x="666" y="160" font-family="system-ui, sans-serif" font-size="12" font-weight="600" fill="#78350F">Parcial</text>
  <text x="666" y="178" font-family="system-ui, sans-serif" font-size="11" fill="#92400E">solo KB y Reportes</text>

  <!-- 3 -->
  <rect x="20" y="222" width="570" height="94" rx="8" fill="#FEE2E2" stroke="#EF4444" stroke-width="1.5"/>
  <text x="38" y="246" font-family="system-ui, sans-serif" font-size="14" font-weight="700" fill="#7F1D1D">3 · Flags `hide_*` por cuenta</text>
  <text x="38" y="266" font-family="ui-monospace, monospace" font-size="11" fill="#991B1B">hide_all_chats · hide_unassigned · hide_contacts · hide_filters · hide_all_inbox</text>
  <text x="38" y="286" font-family="system-ui, sans-serif" font-size="12" fill="#7F1D1D">Se evalúan SOLO en Vue (ChatList.vue, Sidebar.vue).</text>
  <text x="38" y="304" font-family="system-ui, sans-serif" font-size="12" fill="#7F1D1D">Son por CUENTA, no por agente: o todos, o ninguno.</text>
  <rect x="620" y="222" width="240" height="94" rx="8" fill="#FEE2E2" stroke="#EF4444" stroke-width="1.5"/>
  <text x="640" y="272" font-family="system-ui, sans-serif" font-size="22" fill="#B91C1C">✕</text>
  <text x="666" y="262" font-family="system-ui, sans-serif" font-size="12" font-weight="600" fill="#7F1D1D">No. La API sigue</text>
  <text x="666" y="280" font-family="system-ui, sans-serif" font-size="12" font-weight="600" fill="#7F1D1D">devolviendo los datos</text>
</svg>

**Ocultar en la pantalla no es un permiso.** Un agente con `hide_all_chats_for_agent` puede pedir
`GET /api/v1/accounts/1/conversations?assignee_type=all` y recibir todo. Igual con el teléfono:
`_contact.json.jbuilder` serializa `phone_number` y `email` sin condición, así que viajan en el
JSON, en el websocket, en el CSV de exportación y en los webhooks aunque el panel no los pinte.

---

## 2. Arquitectura propuesta

Se reutiliza la tabla `custom_roles` que **ya existe** (con `permissions text[]` y
`account_users.custom_role_id`), se retira el candado premium y se sustituye por una feature de
cuenta propia, `system_permissions` — igual que se hizo con `case_management` o `erp_connection`.

<svg viewBox="0 0 880 470" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Arquitectura: del perfil de permisos a las cuatro capas de enforcement">
  <!-- admin -->
  <rect x="40" y="20" width="230" height="52" rx="8" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5"/>
  <text x="60" y="42" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#334155">ADMINISTRADOR</text>
  <text x="60" y="60" font-family="system-ui, sans-serif" font-size="12" fill="#475569">Configuración › Permisos</text>
  <path d="M155 72 L155 100" stroke="#94A3B8" stroke-width="2" marker-end="url(#a1)"/>
  <defs>
    <marker id="a1" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto">
      <path d="M0 0 L9 4.5 L0 9 z" fill="#94A3B8"/>
    </marker>
  </defs>

  <!-- custom_roles -->
  <rect x="40" y="100" width="230" height="86" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
  <text x="60" y="122" font-family="ui-monospace, monospace" font-size="13" font-weight="700" fill="#4C1D95">custom_roles</text>
  <text x="60" y="142" font-family="system-ui, sans-serif" font-size="12" fill="#5B21B6">Perfil "Agente Junior"</text>
  <text x="60" y="160" font-family="ui-monospace, monospace" font-size="11" fill="#5B21B6">permissions: [ ... ]</text>
  <text x="60" y="176" font-family="system-ui, sans-serif" font-size="11" fill="#6D28D9">≈45 permisos por dominio</text>

  <!-- account_user -->
  <rect x="330" y="100" width="270" height="86" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="350" y="122" font-family="ui-monospace, monospace" font-size="13" font-weight="700" fill="#1E3A8A">AccountUser#permissions</text>
  <text x="350" y="140" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">admin           → ['administrator', …]</text>
  <text x="350" y="156" font-family="system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#1E40AF">permisos propios → los de la tabla</text>
  <text x="350" y="172" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">plantilla        → custom_role.permissions</text>
  <text x="350" y="181" font-family="system-ui, sans-serif" font-size="11" fill="#2563EB">sin nada → ['agent'] (sin cambios)</text>
  <path d="M270 143 L326 143" stroke="#94A3B8" stroke-width="2" marker-end="url(#a1)"/>
  <text x="272" y="136" font-family="system-ui, sans-serif" font-size="10" fill="#64748B">custom_role_id</text>

  <!-- agente -->
  <rect x="650" y="100" width="190" height="86" rx="8" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5"/>
  <text x="670" y="128" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#334155">AGENTE</text>
  <text x="670" y="150" font-family="system-ui, sans-serif" font-size="12" fill="#475569">cada petición pasa</text>
  <text x="670" y="167" font-family="system-ui, sans-serif" font-size="12" fill="#475569">por las 4 capas ↓</text>
  <path d="M600 143 L646 143" stroke="#94A3B8" stroke-width="2" marker-end="url(#a1)"/>

  <!-- fan out -->
  <path d="M465 186 L465 210" stroke="#94A3B8" stroke-width="2"/>
  <path d="M120 210 L810 210" stroke="#94A3B8" stroke-width="2"/>
  <path d="M120 210 L120 240" stroke="#94A3B8" stroke-width="2" marker-end="url(#a1)"/>
  <path d="M350 210 L350 240" stroke="#94A3B8" stroke-width="2" marker-end="url(#a1)"/>
  <path d="M580 210 L580 240" stroke="#94A3B8" stroke-width="2" marker-end="url(#a1)"/>
  <path d="M810 210 L810 240" stroke="#94A3B8" stroke-width="2" marker-end="url(#a1)"/>

  <!-- 4 capas -->
  <rect x="30" y="240" width="180" height="150" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="1.5"/>
  <text x="48" y="264" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#14532D">POLICY</text>
  <text x="48" y="286" font-family="system-ui, sans-serif" font-size="12" fill="#166534">¿Puede ejecutar</text>
  <text x="48" y="303" font-family="system-ui, sans-serif" font-size="12" fill="#166534">esta acción?</text>
  <text x="48" y="330" font-family="ui-monospace, monospace" font-size="10.5" fill="#15803D">app/policies/*.rb</text>
  <text x="48" y="364" font-family="system-ui, sans-serif" font-size="11" font-style="italic" fill="#166534">"no puede exportar</text>
  <text x="48" y="379" font-family="system-ui, sans-serif" font-size="11" font-style="italic" fill="#166534">contactos"</text>

  <rect x="260" y="240" width="180" height="150" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="1.5"/>
  <text x="278" y="264" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#14532D">SCOPE</text>
  <text x="278" y="286" font-family="system-ui, sans-serif" font-size="12" fill="#166534">¿Qué registros</text>
  <text x="278" y="303" font-family="system-ui, sans-serif" font-size="12" fill="#166534">existen para él?</text>
  <text x="278" y="330" font-family="ui-monospace, monospace" font-size="10.5" fill="#15803D">ConversationFinder</text>
  <text x="278" y="364" font-family="system-ui, sans-serif" font-size="11" font-style="italic" fill="#166534">"solo ve las</text>
  <text x="278" y="379" font-family="system-ui, sans-serif" font-size="11" font-style="italic" fill="#166534">conversaciones mías"</text>

  <rect x="490" y="240" width="180" height="150" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="1.5"/>
  <text x="508" y="264" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#78350F">SERIALIZER</text>
  <text x="508" y="286" font-family="system-ui, sans-serif" font-size="12" fill="#92400E">¿Qué campos del</text>
  <text x="508" y="303" font-family="system-ui, sans-serif" font-size="12" fill="#92400E">registro ve?</text>
  <text x="508" y="330" font-family="ui-monospace, monospace" font-size="10.5" fill="#B45309">_contact.jbuilder</text>
  <text x="508" y="364" font-family="system-ui, sans-serif" font-size="11" font-style="italic" fill="#92400E">"ve el contacto, con</text>
  <text x="508" y="379" font-family="system-ui, sans-serif" font-size="11" font-style="italic" fill="#92400E">el teléfono tapado"</text>

  <rect x="720" y="240" width="180" height="150" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="738" y="264" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#1E3A8A">UI</text>
  <text x="738" y="286" font-family="system-ui, sans-serif" font-size="12" fill="#1E40AF">¿Qué pinta el</text>
  <text x="738" y="303" font-family="system-ui, sans-serif" font-size="12" fill="#1E40AF">dashboard?</text>
  <text x="738" y="330" font-family="ui-monospace, monospace" font-size="10.5" fill="#2563EB">permissionsHelper</text>
  <text x="738" y="364" font-family="system-ui, sans-serif" font-size="11" font-style="italic" fill="#1E40AF">"no aparece la pestaña</text>
  <text x="738" y="379" font-family="system-ui, sans-serif" font-size="11" font-style="italic" fill="#1E40AF">Sin asignar"</text>

  <rect x="30" y="410" width="870" height="40" rx="8" fill="#FEE2E2" stroke="#EF4444" stroke-width="1.5"/>
  <text x="50" y="435" font-family="system-ui, sans-serif" font-size="12.5" font-weight="600" fill="#7F1D1D">Regla de oro: ninguna capa de UI sin su capa de backend. Los cinco flags `hide_*` actuales incumplen esto — por eso se migran (§6).</text>
</svg>

---

## 3. Catálogo de permisos sugerido

Nomenclatura `<dominio>_<acción>` en inglés (consistente con los 6 permisos existentes); las
etiquetas visibles van en español por i18n.

### 3.1 Conversaciones — visibilidad

Es un **radio**, no casillas: son excluyentes y gana el más amplio marcado.

<svg viewBox="0 0 880 250" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Matriz de pestañas de bandeja visibles según permiso de conversación">
  <text x="330" y="30" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#64748B">Mías</text>
  <text x="450" y="30" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#64748B">Sin asignar</text>
  <text x="600" y="30" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#64748B">Todas</text>

  <!-- fila 1 -->
  <rect x="20" y="45" width="290" height="52" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="36" y="68" font-family="ui-monospace, monospace" font-size="11.5" font-weight="700" fill="#1E3A8A">conversation_manage</text>
  <text x="36" y="86" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">Ve y gestiona todas (de sus inboxes)</text>
  <circle cx="345" cy="71" r="15" fill="#DCFCE7" stroke="#22C55E"/><text x="339" y="77" font-family="system-ui" font-size="15" fill="#15803D">✓</text>
  <circle cx="478" cy="71" r="15" fill="#DCFCE7" stroke="#22C55E"/><text x="472" y="77" font-family="system-ui" font-size="15" fill="#15803D">✓</text>
  <circle cx="613" cy="71" r="15" fill="#DCFCE7" stroke="#22C55E"/><text x="607" y="77" font-family="system-ui" font-size="15" fill="#15803D">✓</text>
  <text x="650" y="76" font-family="system-ui, sans-serif" font-size="11" fill="#64748B">ya existe</text>

  <!-- fila 2 -->
  <rect x="20" y="107" width="290" height="52" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="36" y="130" font-family="ui-monospace, monospace" font-size="11.5" font-weight="700" fill="#1E3A8A">conversation_unassigned_manage</text>
  <text x="36" y="148" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">Mías + sin asignar, puede auto-asignarse</text>
  <circle cx="345" cy="133" r="15" fill="#DCFCE7" stroke="#22C55E"/><text x="339" y="139" font-family="system-ui" font-size="15" fill="#15803D">✓</text>
  <circle cx="478" cy="133" r="15" fill="#DCFCE7" stroke="#22C55E"/><text x="472" y="139" font-family="system-ui" font-size="15" fill="#15803D">✓</text>
  <circle cx="613" cy="133" r="15" fill="#FEE2E2" stroke="#EF4444"/><text x="607" y="139" font-family="system-ui" font-size="15" fill="#B91C1C">✕</text>
  <text x="650" y="138" font-family="system-ui, sans-serif" font-size="11" fill="#64748B">ya existe</text>

  <!-- fila 3 destacada -->
  <rect x="20" y="169" width="290" height="52" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="2.5"/>
  <text x="36" y="192" font-family="ui-monospace, monospace" font-size="11.5" font-weight="700" fill="#78350F">conversation_participating_manage</text>
  <text x="36" y="210" font-family="system-ui, sans-serif" font-size="11.5" fill="#92400E">SOLO las mías (asignadas o participo)</text>
  <circle cx="345" cy="195" r="15" fill="#DCFCE7" stroke="#22C55E"/><text x="339" y="201" font-family="system-ui" font-size="15" fill="#15803D">✓</text>
  <circle cx="478" cy="195" r="15" fill="#FEE2E2" stroke="#EF4444"/><text x="472" y="201" font-family="system-ui" font-size="15" fill="#B91C1C">✕</text>
  <circle cx="613" cy="195" r="15" fill="#FEE2E2" stroke="#EF4444"/><text x="607" y="201" font-family="system-ui" font-size="15" fill="#B91C1C">✕</text>
  <text x="650" y="190" font-family="system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#B45309">← tu caso</text>
  <text x="650" y="206" font-family="system-ui, sans-serif" font-size="11" fill="#92400E">"solo ver las mías"</text>
</svg>

> El permiso ya existe en el modelo; lo que falta es que **`ConversationFinder` lo respete**. Hoy
> el filtro vive únicamente en `ChatList.vue`.

### 3.2 Conversaciones — acciones

| Permiso | Qué habilita |
|---|---|
| `conversation_assign_others` | Asignar a **otro** agente (sin él: solo auto-asignarse) |
| `conversation_delete` | Eliminar conversaciones |
| `conversation_message_delete` | Borrar mensajes ya enviados |
| `conversation_transcript_download` | Descargar o enviar la transcripción |
| `conversation_private_note_view` | Leer notas privadas de otros agentes |
| `conversation_filters_use` | Filtros avanzados y carpetas *(reemplaza `hide_filters_for_agent`)* |

### 3.3 Contactos y datos personales (PII)

| Permiso | Qué habilita |
|---|---|
| `contact_view` | Acceder al módulo Contactos *(reemplaza `hide_contacts_for_agent`)* |
| `contact_manage` | Crear / editar *(ya existe)* |
| `contact_delete` · `contact_merge` | Eliminar · fusionar duplicados |
| `contact_import` · `contact_export` | CSV *(hoy fijo a `administrator?` en `ContactPolicy`)* |
| **`contact_view_phone`** | **Ver el teléfono/WhatsApp completo.** Sin él → `+52 55•• ••88` |
| **`contact_view_email`** | **Ver el correo completo.** Sin él → `ju••••@••••.com` |
| `contact_view_address` | Dirección / ciudad / país |
| `contact_view_custom_attributes` | Atributos personalizados (RFC, folio, saldo…) |
| `contact_view_social` | Handles de redes (Instagram, Telegram, X…) |
| `contact_notes_view` · `contact_notes_manage` | Notas del contacto |

**El permiso de PII solo es real si se tapa en todas las superficies.** Si falta una, el dato se
fuga. Por eso el enmascarado se hace **en el serializer**, que es el cuello de botella común:

<svg viewBox="0 0 880 420" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="El serializer como punto único donde se enmascara el teléfono, y las superficies que lo consumen">
  <rect x="290" y="20" width="300" height="66" rx="8" fill="#FEE2E2" stroke="#EF4444" stroke-width="2"/>
  <text x="310" y="44" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#7F1D1D">contact_view_phone = false</text>
  <text x="310" y="66" font-family="system-ui, sans-serif" font-size="12" fill="#991B1B">hay que tapar el número en TODO lo de abajo</text>

  <path d="M440 86 L440 112" stroke="#94A3B8" stroke-width="2" marker-end="url(#a2)"/>
  <defs>
    <marker id="a2" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto">
      <path d="M0 0 L9 4.5 L0 9 z" fill="#94A3B8"/>
    </marker>
  </defs>

  <rect x="270" y="112" width="340" height="60" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="2.5"/>
  <text x="290" y="136" font-family="ui-monospace, monospace" font-size="12.5" font-weight="700" fill="#78350F">_contact.json.jbuilder</text>
  <text x="290" y="158" font-family="system-ui, sans-serif" font-size="11.5" fill="#92400E">punto ÚNICO de enmascarado → "+52 55•• ••88"</text>

  <path d="M440 172 L440 196" stroke="#94A3B8" stroke-width="2"/>
  <path d="M110 196 L780 196" stroke="#94A3B8" stroke-width="2"/>

  <!-- columna 1 -->
  <path d="M110 196 L110 218" stroke="#94A3B8" stroke-width="2" marker-end="url(#a2)"/>
  <path d="M330 196 L330 218" stroke="#94A3B8" stroke-width="2" marker-end="url(#a2)"/>
  <path d="M555 196 L555 218" stroke="#94A3B8" stroke-width="2" marker-end="url(#a2)"/>
  <path d="M780 196 L780 218" stroke="#94A3B8" stroke-width="2" marker-end="url(#a2)"/>

  <rect x="20" y="218" width="185" height="180" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="36" y="240" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#1E3A8A">PANEL Y FICHA</text>
  <text x="36" y="264" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">• ContactInfo.vue</text>
  <text x="36" y="284" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">• EditContact.vue</text>
  <text x="36" y="304" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">• ContactInfoPanel.vue</text>
  <text x="36" y="324" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">• tabla de Contactos</text>
  <text x="36" y="356" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#3B82F6">campo bloqueado,</text>
  <text x="36" y="371" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#3B82F6">no solo oculto</text>

  <rect x="240" y="218" width="185" height="180" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="256" y="240" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#1E3A8A">BANDEJA</text>
  <text x="256" y="264" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">• ConversationCard</text>
  <text x="256" y="284" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">• ConversationHeader</text>
  <text x="256" y="304" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">• buscador</text>
  <text x="256" y="336" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#3B82F6">algunos canales usan</text>
  <text x="256" y="351" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#3B82F6">el tel. como nombre;</text>
  <text x="256" y="366" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#3B82F6">tampoco buscar POR tel.</text>

  <rect x="463" y="218" width="185" height="180" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="479" y="240" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#1E3A8A">SALIDAS DE DATOS</text>
  <text x="479" y="264" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">• export CSV</text>
  <text x="479" y="284" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">• API JSON</text>
  <text x="479" y="304" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">• ActionCable</text>
  <text x="479" y="336" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#3B82F6">export se bloquea con</text>
  <text x="479" y="351" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#3B82F6">contact_export</text>

  <rect x="690" y="218" width="185" height="180" rx="8" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5"/>
  <text x="706" y="240" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#334155">FUERA DE ALCANCE</text>
  <text x="706" y="264" font-family="system-ui, sans-serif" font-size="11.5" fill="#475569">• webhooks</text>
  <text x="706" y="284" font-family="system-ui, sans-serif" font-size="11.5" fill="#475569">• integraciones / ERP</text>
  <text x="706" y="304" font-family="system-ui, sans-serif" font-size="11.5" fill="#475569">• texto libre de mensajes</text>
  <text x="706" y="336" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#64748B">el permiso es para</text>
  <text x="706" y="351" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#64748B">personas, no máquinas</text>
</svg>

**Decisión de diseño: enmascarar, no borrar el campo.** Si el JSON deja de traer `phone_number`,
medio dashboard cree que el contacto no tiene teléfono y se rompen flujos (responder por WhatsApp,
plantillas, Wavoip). El partial devuelve el valor enmascarado más un indicador:

```jsonc
{ "phone_number": "+52 55•• ••88", "phone_number_masked": true }
```

Las acciones que **exponen el número en claro** (copiarlo, llamar, abrir `wa.me` o Wavoip) se
deshabilitan en la UI y se rechazan en la policy. **Responder por WhatsApp dentro de la
conversación sí está permitido** — el agente atiende con normalidad, solo no ve el número
(detalle completo en §10.1).

### 3.4 Bandejas, módulos y administración

| Grupo | Permisos |
|---|---|
| **Bandejas** | `inbox_view_all` *(reemplaza `hide_all_inbox_for_agent`)* · `inbox_manage` |
| **Reportes** | `report_view` · `report_manage` · `report_export` |
| **Base de Conocimiento** | `knowledge_base_view` · `knowledge_base_manage` |
| **Tickets** (`case_management`) | `ticket_view_own` · `ticket_view_all` · `ticket_manage` · `ticket_admin` (tipos, columnas por tipo, SLA, plantillas) |
| **Kanban Oportunidades** | `kanban_view` · `kanban_manage` |
| **Campañas / Vendedor IA** | `campaign_manage` |
| **Seguimientos IA** | `contact_tracking_view` · `contact_tracking_manage` |
| **ERP / Query DB** | `erp_query_use` · `erp_connection_manage` |
| **Productividad** | `canned_response_manage` · `label_manage` · `macro_manage` · `automation_manage` |
| **Administración** | `agent_manage` · `team_manage` · `integration_manage` · `account_settings_manage` · `audit_log_view` · **`system_permissions_manage`** |

> `system_permissions_manage` es lo que hace que **este módulo sea solo de administradores**: va
> implícito en `administrator` y no se puede marcar desde un perfil que no lo tenga (§8.1).

### 3.5 Plantillas predefinidas (semillas)

Los permisos se editan por agente en la tabla (§5), pero estas plantillas se aplican en lote para
no marcar 45 casillas a mano:

| Plantilla | Qué incluye |
|---|---|
| **Administrador** | rol nativo, no editable |
| **Supervisor** | todas las conversaciones + reportes + PII completa |
| **Agente** | mías + sin asignar, PII completa |
| **Agente Junior** | **solo mías**, teléfono y correo **enmascarados**, sin exportar |
| **Solo lectura** | ver conversaciones y reportes, sin responder |
| **Backoffice / Tickets** | tickets + contactos, sin bandeja de conversaciones |

---

## 4. Modelo de datos — sin tabla nueva

<svg viewBox="0 0 880 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Modelo de datos: custom_roles y account_users con dos columnas nuevas">
  <rect x="40" y="30" width="300" height="200" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
  <rect x="40" y="30" width="300" height="34" rx="8" fill="#8B5CF6"/>
  <text x="58" y="53" font-family="ui-monospace, monospace" font-size="13" font-weight="700" fill="#FFFFFF">custom_roles</text>
  <text x="58" y="88" font-family="ui-monospace, monospace" font-size="12" fill="#4C1D95">id · account_id</text>
  <text x="58" y="112" font-family="ui-monospace, monospace" font-size="12" fill="#4C1D95">name · description</text>
  <text x="58" y="136" font-family="ui-monospace, monospace" font-size="12" fill="#4C1D95">permissions  text[]</text>
  <rect x="52" y="150" width="276" height="30" rx="6" fill="#DCFCE7" stroke="#22C55E"/>
  <text x="62" y="170" font-family="ui-monospace, monospace" font-size="12" fill="#14532D">+ system  boolean   ← semillas</text>
  <rect x="52" y="186" width="276" height="30" rx="6" fill="#DCFCE7" stroke="#22C55E"/>
  <text x="62" y="206" font-family="ui-monospace, monospace" font-size="12" fill="#14532D">+ locked  boolean   ← no editable</text>

  <path d="M340 130 L470 130" stroke="#8B5CF6" stroke-width="2" marker-end="url(#a3)"/>
  <defs>
    <marker id="a3" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto">
      <path d="M0 0 L9 4.5 L0 9 z" fill="#8B5CF6"/>
    </marker>
  </defs>
  <text x="356" y="122" font-family="system-ui, sans-serif" font-size="11" fill="#6D28D9">1 : N</text>

  <rect x="470" y="30" width="300" height="140" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <rect x="470" y="30" width="300" height="34" rx="8" fill="#3B82F6"/>
  <text x="488" y="53" font-family="ui-monospace, monospace" font-size="13" font-weight="700" fill="#FFFFFF">account_users</text>
  <text x="488" y="88" font-family="ui-monospace, monospace" font-size="12" fill="#1E3A8A">id · account_id · user_id</text>
  <text x="488" y="112" font-family="ui-monospace, monospace" font-size="12" fill="#1E3A8A">role  (agent | administrator)</text>
  <text x="488" y="136" font-family="ui-monospace, monospace" font-size="12" font-weight="700" fill="#1E3A8A">custom_role_id  ← ya existe (plantilla)</text>
  <rect x="482" y="146" width="276" height="26" rx="6" fill="#DCFCE7" stroke="#22C55E"/>
  <text x="492" y="164" font-family="ui-monospace, monospace" font-size="11.5" fill="#14532D">+ permissions text[]  ← por agente</text>

  <rect x="40" y="248" width="730" height="36" rx="8" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5"/>
  <text x="58" y="271" font-family="system-ui, sans-serif" font-size="12.5" fill="#334155">Migración = 3 columnas + seed de plantillas. <tspan font-weight="700">Nada cambia mientras `permissions` y `custom_role_id` estén vacíos.</tspan></text>
</svg>

`CustomRole::PERMISSIONS` pasa de 6 a ~45 entradas, agrupadas en una constante `PERMISSION_GROUPS`
para que la pantalla se pinte sola a partir del catálogo.

**Los permisos se guardan por agente** (`account_users.permissions`), porque la pantalla es una
tabla de agentes editable celda a celda (§5). Los perfiles de `custom_roles` quedan como
**plantillas** que se aplican en lote a los agentes seleccionados, no como el único camino.

Orden de resolución en `AccountUser#permissions`:

```
   ¿administrator?           → ['administrator']              (todo)
   ¿permissions presente?    → permissions                    (lo editado en la tabla)
   ¿custom_role presente?    → custom_role.permissions         (plantilla aplicada)
   si no                     → ['agent']                      (comportamiento actual)
```

---

## 5. La opción en Configuración

**Buena noticia:** la entrada de menú y la ruta **ya existen en el código, comentadas**:

- Ruta registrada: `custom_roles_list` → `/accounts/:accountId/settings/custom-roles/list`
  (`customRoles/customRole.routes.js`, con `meta.permissions: ['administrator']`).
- Ítem de menú **comentado** en `components/layout/config/sidebarItems/settings.js` (~línea 249),
  marcado `isEnterpriseOnly: true` + `beta: true`.

El plan es reactivarlo, renombrarlo a **Permisos** (icono `scan-person`), quitar el
`isEnterpriseOnly` y condicionarlo a la feature `system_permissions` de la cuenta.

### 5.1 La pantalla es una tabla filtrable con paginado

Mismo patrón que **Contactos** (`/app/accounts/:id/contacts?page=1`): filtros arriba, tabla en el
centro, paginación abajo. Se reutilizan los componentes que ya existen —
`VeTable` (vue-easytable, como `ContactsTable.vue`) y `TableFooter.vue`
(props `currentPage` / `pageSize` / `totalCount`, evento `@pageChange`).

**Los filtros mandan sobre la tabla:**

| Filtro | Qué hace |
|---|---|
| **Agente** | Acota las filas (usuarios de la cuenta). Vacío = todos, paginados. |
| **Equipo** | Acota las filas a los miembros de un equipo (`teams` / `team_members`). Se combina con el de agente. |
| **Módulo** | Define **las columnas**: Contactos, Conversaciones, Bandejas, Tickets, Reportes, KB, Campañas, Administración… |
| **Modificados** | Muestra solo los agentes con permisos propios (los que se apartan de la plantilla o del comportamiento por defecto). |

El filtro de equipo es además el atajo operativo real: **filtrar por equipo → seleccionar todo →
aplicar plantilla** deja configurado a Soporte, Ventas o Cobranza de una sola vez. El equipo no
guarda permisos propios: es un filtro de selección, no un tercer nivel de herencia (así se evita
el clásico "¿de dónde le viene este permiso?" cuando alguien está en dos equipos).

<svg viewBox="0 0 880 130" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="El filtro de módulo define qué columnas de permisos muestra la tabla">
  <rect x="20" y="18" width="150" height="30" rx="6" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
  <text x="36" y="38" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#4C1D95">Módulo: Contactos</text>
  <path d="M176 33 L214 33" stroke="#94A3B8" stroke-width="1.5" marker-end="url(#a5)"/>
  <defs><marker id="a5" markerWidth="8" markerHeight="8" refX="4.5" refY="4" orient="auto"><path d="M0 0 L8 4 L0 8 z" fill="#94A3B8"/></marker></defs>
  <g font-family="system-ui, sans-serif" font-size="10.5" fill="#1E3A8A">
    <rect x="220" y="18" width="52" height="30" rx="5" fill="#DBEAFE" stroke="#3B82F6"/><text x="234" y="38">Ver</text>
    <rect x="278" y="18" width="78" height="30" rx="5" fill="#DBEAFE" stroke="#3B82F6"/><text x="288" y="38">Crear/edit.</text>
    <rect x="362" y="18" width="66" height="30" rx="5" fill="#DBEAFE" stroke="#3B82F6"/><text x="374" y="38">Eliminar</text>
    <rect x="434" y="18" width="92" height="30" rx="5" fill="#FEF3C7" stroke="#F59E0B"/><text x="444" y="38">Ver teléfono</text>
    <rect x="532" y="18" width="84" height="30" rx="5" fill="#FEF3C7" stroke="#F59E0B"/><text x="542" y="38">Ver correo</text>
    <rect x="622" y="18" width="70" height="30" rx="5" fill="#DBEAFE" stroke="#3B82F6"/><text x="634" y="38">Exportar</text>
  </g>
  <rect x="20" y="66" width="150" height="30" rx="6" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
  <text x="36" y="86" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#4C1D95">Módulo: Conversac.</text>
  <path d="M176 81 L214 81" stroke="#94A3B8" stroke-width="1.5" marker-end="url(#a5)"/>
  <g font-family="system-ui, sans-serif" font-size="10.5" fill="#1E3A8A">
    <rect x="220" y="66" width="136" height="30" rx="5" fill="#FEF3C7" stroke="#F59E0B"/><text x="230" y="86">Visibilidad (3 opc.)</text>
    <rect x="362" y="66" width="66" height="30" rx="5" fill="#DBEAFE" stroke="#3B82F6"/><text x="374" y="86">Filtros</text>
    <rect x="434" y="66" width="92" height="30" rx="5" fill="#DBEAFE" stroke="#3B82F6"/><text x="444" y="86">Asignar otros</text>
    <rect x="532" y="66" width="84" height="30" rx="5" fill="#DBEAFE" stroke="#3B82F6"/><text x="542" y="86">Eliminar</text>
    <rect x="622" y="66" width="98" height="30" rx="5" fill="#DBEAFE" stroke="#3B82F6"/><text x="632" y="86">Notas privadas</text>
  </g>
  <text x="740" y="38" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#64748B">las columnas salen</text>
  <text x="740" y="53" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#64748B">de PERMISSION_GROUPS</text>
  <text x="740" y="86" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#64748B">→ agregar un permiso</text>
  <text x="740" y="101" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#64748B">no toca la pantalla</text>
</svg>

<svg viewBox="0 0 880 500" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Maqueta de la pantalla Configuracion Permisos: tabla filtrable con paginado">
  <rect x="10" y="10" width="860" height="480" rx="10" fill="#F8FAFC" stroke="#CBD5E1" stroke-width="1.5"/>

  <!-- barra superior -->
  <rect x="10" y="10" width="860" height="46" rx="10" fill="#1E293B"/>
  <text x="34" y="39" font-family="system-ui, sans-serif" font-size="14" font-weight="700" fill="#FFFFFF">Configuración › Permisos</text>
  <rect x="676" y="21" width="170" height="26" rx="6" fill="#3B82F6"/>
  <text x="692" y="39" font-family="system-ui, sans-serif" font-size="12" font-weight="600" fill="#FFFFFF">Aplicar plantilla ▾</text>

  <!-- filtros -->
  <rect x="24" y="70" width="176" height="32" rx="6" fill="#FFFFFF" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="36" y="91" font-family="system-ui, sans-serif" font-size="11" fill="#64748B">Agente:</text>
  <text x="82" y="91" font-family="system-ui, sans-serif" font-size="12" font-weight="600" fill="#1E3A8A">Todos</text>
  <text x="184" y="91" font-family="system-ui, sans-serif" font-size="11" fill="#64748B">▾</text>

  <rect x="210" y="70" width="176" height="32" rx="6" fill="#FFFFFF" stroke="#22C55E" stroke-width="1.5"/>
  <text x="222" y="91" font-family="system-ui, sans-serif" font-size="11" fill="#64748B">Equipo:</text>
  <text x="266" y="91" font-family="system-ui, sans-serif" font-size="12" font-weight="600" fill="#14532D">Soporte</text>
  <text x="370" y="91" font-family="system-ui, sans-serif" font-size="11" fill="#64748B">▾</text>

  <rect x="396" y="70" width="176" height="32" rx="6" fill="#FFFFFF" stroke="#8B5CF6" stroke-width="1.5"/>
  <text x="408" y="91" font-family="system-ui, sans-serif" font-size="11" fill="#64748B">Módulo:</text>
  <text x="456" y="91" font-family="system-ui, sans-serif" font-size="12" font-weight="600" fill="#4C1D95">Contactos</text>
  <text x="556" y="91" font-family="system-ui, sans-serif" font-size="11" fill="#64748B">▾</text>

  <rect x="582" y="70" width="150" height="32" rx="6" fill="#FFFFFF" stroke="#CBD5E1" stroke-width="1.5"/>
  <text x="594" y="91" font-family="system-ui, sans-serif" font-size="12" fill="#94A3B8">Buscar agente…</text>

  <rect x="742" y="70" width="104" height="32" rx="6" fill="#F1F5F9" stroke="#94A3B8" stroke-width="1.5"/>
  <text x="754" y="91" font-family="system-ui, sans-serif" font-size="11.5" fill="#334155">Modificados</text>

  <!-- encabezado tabla -->
  <rect x="24" y="116" width="822" height="34" fill="#F1F5F9" stroke="#CBD5E1"/>
  <text x="40" y="138" font-family="system-ui, sans-serif" font-size="11" font-weight="700" fill="#475569">AGENTE</text>
  <text x="300" y="138" font-family="system-ui, sans-serif" font-size="11" font-weight="700" fill="#475569">VER</text>
  <text x="356" y="138" font-family="system-ui, sans-serif" font-size="11" font-weight="700" fill="#475569">CREAR/EDIT.</text>
  <text x="452" y="138" font-family="system-ui, sans-serif" font-size="11" font-weight="700" fill="#475569">ELIMINAR</text>
  <text x="540" y="138" font-family="system-ui, sans-serif" font-size="11" font-weight="700" fill="#B45309">VER TELÉFONO</text>
  <text x="656" y="138" font-family="system-ui, sans-serif" font-size="11" font-weight="700" fill="#B45309">VER CORREO</text>
  <text x="760" y="138" font-family="system-ui, sans-serif" font-size="11" font-weight="700" fill="#475569">EXPORTAR</text>

  <!-- filas -->
  <g font-family="system-ui, sans-serif">
    <!-- fila 1 -->
    <rect x="24" y="150" width="822" height="42" fill="#FFFFFF" stroke="#E2E8F0"/>
    <circle cx="48" cy="171" r="12" fill="#DBEAFE"/><text x="42" y="176" font-size="11" fill="#1E40AF">LP</text>
    <text x="70" y="168" font-size="12.5" font-weight="600" fill="#1E293B">Luis Pérez</text>
    <text x="70" y="183" font-size="10.5" fill="#94A3B8">agente · Ventas</text>
    <rect x="296" y="163" width="30" height="17" rx="8.5" fill="#22C55E"/><circle cx="318" cy="171.5" r="6.5" fill="#FFFFFF"/>
    <rect x="384" y="163" width="30" height="17" rx="8.5" fill="#22C55E"/><circle cx="406" cy="171.5" r="6.5" fill="#FFFFFF"/>
    <rect x="472" y="163" width="30" height="17" rx="8.5" fill="#CBD5E1"/><circle cx="480" cy="171.5" r="6.5" fill="#FFFFFF"/>
    <rect x="576" y="163" width="30" height="17" rx="8.5" fill="#22C55E"/><circle cx="598" cy="171.5" r="6.5" fill="#FFFFFF"/>
    <rect x="676" y="163" width="30" height="17" rx="8.5" fill="#22C55E"/><circle cx="698" cy="171.5" r="6.5" fill="#FFFFFF"/>
    <rect x="776" y="163" width="30" height="17" rx="8.5" fill="#CBD5E1"/><circle cx="784" cy="171.5" r="6.5" fill="#FFFFFF"/>

    <!-- fila 2 destacada -->
    <rect x="24" y="192" width="822" height="42" fill="#FFFBEB" stroke="#E2E8F0"/>
    <circle cx="48" cy="213" r="12" fill="#FEF3C7"/><text x="42" y="218" font-size="11" fill="#92400E">AR</text>
    <text x="70" y="210" font-size="12.5" font-weight="600" fill="#1E293B">Ana Ruiz</text>
    <text x="70" y="225" font-size="10.5" fill="#B45309">agente · plantilla: Agente Junior</text>
    <rect x="296" y="205" width="30" height="17" rx="8.5" fill="#22C55E"/><circle cx="318" cy="213.5" r="6.5" fill="#FFFFFF"/>
    <rect x="384" y="205" width="30" height="17" rx="8.5" fill="#CBD5E1"/><circle cx="392" cy="213.5" r="6.5" fill="#FFFFFF"/>
    <rect x="472" y="205" width="30" height="17" rx="8.5" fill="#CBD5E1"/><circle cx="480" cy="213.5" r="6.5" fill="#FFFFFF"/>
    <rect x="576" y="205" width="30" height="17" rx="8.5" fill="#EF4444"/><circle cx="584" cy="213.5" r="6.5" fill="#FFFFFF"/>
    <rect x="612" y="204" width="86" height="19" rx="4" fill="#FEE2E2"/>
    <text x="618" y="217" font-family="ui-monospace, monospace" font-size="9.5" fill="#991B1B">+52 55•• ••88</text>
    <rect x="676" y="205" width="30" height="17" rx="8.5" fill="#EF4444"/><circle cx="684" cy="213.5" r="6.5" fill="#FFFFFF"/>
    <rect x="776" y="205" width="30" height="17" rx="8.5" fill="#CBD5E1"/><circle cx="784" cy="213.5" r="6.5" fill="#FFFFFF"/>

    <!-- fila 3 -->
    <rect x="24" y="234" width="822" height="42" fill="#FFFFFF" stroke="#E2E8F0"/>
    <circle cx="48" cy="255" r="12" fill="#DCFCE7"/><text x="42" y="260" font-size="11" fill="#166534">CM</text>
    <text x="70" y="252" font-size="12.5" font-weight="600" fill="#1E293B">Carlos M.</text>
    <text x="70" y="267" font-size="10.5" fill="#94A3B8">administrador</text>
    <rect x="290" y="246" width="530" height="19" rx="4" fill="#F1F5F9"/>
    <text x="300" y="259" font-size="11" font-style="italic" fill="#64748B">Los administradores tienen todos los permisos — fila de solo lectura</text>

    <!-- fila 4 -->
    <rect x="24" y="276" width="822" height="42" fill="#FFFFFF" stroke="#E2E8F0"/>
    <circle cx="48" cy="297" r="12" fill="#EDE9FE"/><text x="42" y="302" font-size="11" fill="#5B21B6">MG</text>
    <text x="70" y="294" font-size="12.5" font-weight="600" fill="#1E293B">María G.</text>
    <text x="70" y="309" font-size="10.5" fill="#94A3B8">agente · Soporte</text>
    <rect x="296" y="289" width="30" height="17" rx="8.5" fill="#22C55E"/><circle cx="318" cy="297.5" r="6.5" fill="#FFFFFF"/>
    <rect x="384" y="289" width="30" height="17" rx="8.5" fill="#22C55E"/><circle cx="406" cy="297.5" r="6.5" fill="#FFFFFF"/>
    <rect x="472" y="289" width="30" height="17" rx="8.5" fill="#CBD5E1"/><circle cx="480" cy="297.5" r="6.5" fill="#FFFFFF"/>
    <rect x="576" y="289" width="30" height="17" rx="8.5" fill="#22C55E"/><circle cx="598" cy="297.5" r="6.5" fill="#FFFFFF"/>
    <rect x="676" y="289" width="30" height="17" rx="8.5" fill="#CBD5E1"/><circle cx="684" cy="297.5" r="6.5" fill="#FFFFFF"/>
    <rect x="776" y="289" width="30" height="17" rx="8.5" fill="#CBD5E1"/><circle cx="784" cy="297.5" r="6.5" fill="#FFFFFF"/>

    <!-- fila 5 -->
    <rect x="24" y="318" width="822" height="42" fill="#FFFFFF" stroke="#E2E8F0"/>
    <circle cx="48" cy="339" r="12" fill="#FEE2E2"/><text x="42" y="344" font-size="11" fill="#991B1B">JT</text>
    <text x="70" y="336" font-size="12.5" font-weight="600" fill="#1E293B">Jorge T.</text>
    <text x="70" y="351" font-size="10.5" fill="#94A3B8">agente · Cobranza</text>
    <rect x="296" y="331" width="30" height="17" rx="8.5" fill="#22C55E"/><circle cx="318" cy="339.5" r="6.5" fill="#FFFFFF"/>
    <rect x="384" y="331" width="30" height="17" rx="8.5" fill="#CBD5E1"/><circle cx="392" cy="339.5" r="6.5" fill="#FFFFFF"/>
    <rect x="472" y="331" width="30" height="17" rx="8.5" fill="#CBD5E1"/><circle cx="480" cy="339.5" r="6.5" fill="#FFFFFF"/>
    <rect x="576" y="331" width="30" height="17" rx="8.5" fill="#22C55E"/><circle cx="598" cy="339.5" r="6.5" fill="#FFFFFF"/>
    <rect x="676" y="331" width="30" height="17" rx="8.5" fill="#22C55E"/><circle cx="698" cy="339.5" r="6.5" fill="#FFFFFF"/>
    <rect x="776" y="331" width="30" height="17" rx="8.5" fill="#CBD5E1"/><circle cx="784" cy="339.5" r="6.5" fill="#FFFFFF"/>
  </g>

  <!-- barra de cambios sin guardar -->
  <rect x="24" y="372" width="822" height="34" rx="6" fill="#FEF3C7" stroke="#F59E0B"/>
  <text x="42" y="394" font-family="system-ui, sans-serif" font-size="11.5" fill="#78350F">2 cambios sin guardar (Ana Ruiz, Jorge T.)</text>
  <rect x="640" y="378" width="90" height="22" rx="5" fill="#FFFFFF" stroke="#94A3B8"/>
  <text x="660" y="393" font-family="system-ui, sans-serif" font-size="11.5" fill="#334155">Descartar</text>
  <rect x="740" y="378" width="90" height="22" rx="5" fill="#22C55E"/>
  <text x="762" y="393" font-family="system-ui, sans-serif" font-size="11.5" font-weight="600" fill="#FFFFFF">Guardar</text>

  <!-- footer paginado -->
  <rect x="24" y="418" width="822" height="52" rx="6" fill="#FFFFFF" stroke="#CBD5E1"/>
  <text x="44" y="449" font-family="system-ui, sans-serif" font-size="11.5" fill="#64748B">Mostrando 1 – 5 de 23 agentes</text>
  <rect x="560" y="432" width="28" height="26" rx="5" fill="#F1F5F9" stroke="#CBD5E1"/><text x="571" y="450" font-family="system-ui" font-size="12" fill="#64748B">‹</text>
  <rect x="594" y="432" width="28" height="26" rx="5" fill="#3B82F6"/><text x="605" y="450" font-family="system-ui" font-size="12" font-weight="700" fill="#FFFFFF">1</text>
  <rect x="628" y="432" width="28" height="26" rx="5" fill="#F1F5F9" stroke="#CBD5E1"/><text x="639" y="450" font-family="system-ui" font-size="12" fill="#334155">2</text>
  <rect x="662" y="432" width="28" height="26" rx="5" fill="#F1F5F9" stroke="#CBD5E1"/><text x="673" y="450" font-family="system-ui" font-size="12" fill="#334155">3</text>
  <rect x="696" y="432" width="28" height="26" rx="5" fill="#F1F5F9" stroke="#CBD5E1"/><text x="707" y="450" font-family="system-ui" font-size="12" fill="#334155">4</text>
  <rect x="730" y="432" width="28" height="26" rx="5" fill="#F1F5F9" stroke="#CBD5E1"/><text x="741" y="450" font-family="system-ui" font-size="12" fill="#64748B">›</text>
  <text x="776" y="450" font-family="ui-monospace, monospace" font-size="10.5" fill="#94A3B8">?page=1</text>
</svg>

### 5.2 Comportamiento de la tabla

- **Celda = un permiso de un agente.** Interruptor por celda; el cambio se acumula y se guarda con
  el botón (barra ámbar), no petición por clic — así se pueden ajustar varias filas de un tirón.
- **Vista previa del enmascarado** en la propia celda de PII (`+52 55•• ••88`): el admin ve
  exactamente lo que verá el agente.
- **Administradores**: fila de solo lectura, con leyenda. No se pueden recortar desde aquí.
- **Conversaciones** es el único módulo cuya visibilidad es **excluyente**: en esa columna va un
  selector de 3 opciones (Todas / Mías + sin asignar / Solo mías), no un interruptor.
- **Aplicar plantilla**: selecciona filas —o filtra por equipo y selecciona todo— → aplica un
  perfil de `custom_roles` en lote. La fila muestra de qué plantilla viene mientras no se edite a
  mano.
- **Paginado**: `TableFooter.vue` con `?page=N` en la URL, igual que Contactos, para que el enlace
  sea compartible.
- Al guardar, **broadcast por ActionCable** para que las sesiones abiertas refresquen permisos sin
  volver a iniciar sesión.
- Enlace cruzado desde Configuración › Agentes (columna "Permisos" → esta tabla ya filtrada por
  ese agente).

---

## 6. Migración de los flags `hide_*`

<svg viewBox="0 0 880 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Equivalencia entre los flags hide y los nuevos permisos">
  <rect x="20" y="20" width="360" height="34" rx="6" fill="#FEE2E2" stroke="#EF4444"/>
  <text x="40" y="43" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#7F1D1D">HOY · flag de cuenta (solo UI)</text>
  <rect x="500" y="20" width="360" height="34" rx="6" fill="#DCFCE7" stroke="#22C55E"/>
  <text x="520" y="43" font-family="system-ui, sans-serif" font-size="12" font-weight="700" fill="#14532D">NUEVO · permiso de perfil (BE + UI)</text>

  <g font-family="ui-monospace, monospace" font-size="11.5">
    <text x="40" y="88" fill="#991B1B">hide_all_chats_for_agent</text>
    <text x="520" y="88" fill="#166534">ausencia de conversation_manage</text>
    <path d="M390 84 L494 84" stroke="#94A3B8" stroke-width="1.5" marker-end="url(#a4)"/>

    <text x="40" y="128" fill="#991B1B">hide_unassigned_for_agent</text>
    <text x="520" y="128" fill="#166534">ausencia de conversation_unassigned_manage</text>
    <path d="M390 124 L494 124" stroke="#94A3B8" stroke-width="1.5" marker-end="url(#a4)"/>

    <text x="40" y="168" fill="#991B1B">hide_contacts_for_agent</text>
    <text x="520" y="168" fill="#166534">ausencia de contact_view</text>
    <path d="M390 164 L494 164" stroke="#94A3B8" stroke-width="1.5" marker-end="url(#a4)"/>

    <text x="40" y="208" fill="#991B1B">hide_filters_for_agent</text>
    <text x="520" y="208" fill="#166534">ausencia de conversation_filters_use</text>
    <path d="M390 204 L494 204" stroke="#94A3B8" stroke-width="1.5" marker-end="url(#a4)"/>

    <text x="40" y="248" fill="#991B1B">hide_all_inbox_for_agent</text>
    <text x="520" y="248" fill="#166534">ausencia de inbox_view_all</text>
    <path d="M390 244 L494 244" stroke="#94A3B8" stroke-width="1.5" marker-end="url(#a4)"/>
  </g>
  <defs>
    <marker id="a4" markerWidth="8" markerHeight="8" refX="4.5" refY="4" orient="auto">
      <path d="M0 0 L8 4 L0 8 z" fill="#94A3B8"/>
    </marker>
  </defs>

  <rect x="20" y="266" width="840" height="26" rx="6" fill="#F1F5F9" stroke="#94A3B8"/>
  <text x="40" y="284" font-family="system-ui, sans-serif" font-size="11.5" fill="#334155">Rake de migración: por cada cuenta con algún flag activo → crea perfil "Agente (migrado)" y lo asigna. Los flags quedan deprecados, no se borran en esta rama.</text>
</svg>

---

## 7. Fases

<svg viewBox="0 0 880 340" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Roadmap de fases F1 a F6">
  <rect x="20" y="20" width="840" height="46" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="1.5"/>
  <text x="40" y="41" font-family="system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#78350F">F1 → F3 es el mínimo que resuelve tus dos casos:</text>
  <text x="40" y="58" font-family="system-ui, sans-serif" font-size="12" fill="#92400E">"solo mis conversaciones" + "ocultar teléfono y correo". F4 los hace administrables sin consola.</text>

  <g font-family="system-ui, sans-serif">
    <rect x="20" y="80" width="840" height="38" rx="6" fill="#DCFCE7" stroke="#22C55E"/>
    <text x="38" y="104" font-size="12.5" font-weight="700" fill="#14532D">F1 · Cimientos</text>
    <text x="180" y="104" font-size="12" fill="#166534">feature `system_permissions` · catálogo PERMISSION_GROUPS (~45) · account_users.permissions · seed · API</text>

    <rect x="20" y="126" width="840" height="38" rx="6" fill="#DCFCE7" stroke="#22C55E"/>
    <text x="38" y="150" font-size="12.5" font-weight="700" fill="#14532D">F2 · Conversaciones</text>
    <text x="180" y="150" font-size="12" fill="#166534">ConversationFinder + policy_scope filtran de verdad · ConversationPolicy real · contadores coherentes</text>

    <rect x="20" y="172" width="840" height="38" rx="6" fill="#DCFCE7" stroke="#22C55E"/>
    <text x="38" y="196" font-size="12.5" font-weight="700" fill="#14532D">F3 · PII de contactos</text>
    <text x="180" y="196" font-size="12" fill="#166534">enmascarado en jbuilder + flag *_masked · sin búsqueda por teléfono · export por permiso · UI</text>

    <rect x="20" y="218" width="840" height="38" rx="6" fill="#DBEAFE" stroke="#3B82F6"/>
    <text x="38" y="242" font-size="12.5" font-weight="700" fill="#1E3A8A">F4 · Pantalla</text>
    <text x="180" y="242" font-size="12" fill="#1E40AF">tabla filtrable (agente + módulo) con paginado · plantillas en lote · enlace desde Agentes · i18n es/en</text>

    <rect x="20" y="264" width="840" height="38" rx="6" fill="#EDE9FE" stroke="#8B5CF6"/>
    <text x="38" y="288" font-size="12.5" font-weight="700" fill="#4C1D95">F5 · Módulos propios</text>
    <text x="180" y="288" font-size="12" fill="#5B21B6">Tickets · Kanban · KB · Campañas · Seguimientos · ERP conectados a sus policies y rutas</text>

    <rect x="20" y="310" width="840" height="26" rx="6" fill="#F1F5F9" stroke="#94A3B8"/>
    <text x="38" y="328" font-size="12.5" font-weight="700" fill="#334155">F6 · Migración</text>
    <text x="180" y="328" font-size="12" fill="#475569">rake de flags `hide_*` · retiro de ChatList.vue y Sidebar.vue · refresco de permisos en vivo</text>
  </g>
</svg>

| Fase | Archivos principales |
|---|---|
| F1 | `config/features.yml`, `enterprise/app/models/custom_role.rb`, `app/models/account_user.rb`, migración (`account_users.permissions`, `custom_roles.system/locked`), `custom_roles_controller` + endpoint de permisos por agente |
| F2 | `app/finders/conversation_finder.rb`, `app/policies/conversation_policy.rb` |
| F3 | `_contact.json.jbuilder`, `ContactPolicy`, `ContactInfo.vue`, `EditContact.vue`, `ContactInfoPanel.vue`, `ConversationCard.vue` |
| F4 | `settings/customRoles/**` (tabla con `VeTable` + `components/widgets/TableFooter.vue`), `sidebarItems/settings.js` |
| F5 | policies de cada módulo, `*.routes.js` |
| F6 | `ChatList.vue`, `Sidebar.vue`, rake task |

---

## 8. Riesgos y decisiones

1. **Escalada de privilegios.** Un perfil no puede otorgar permisos que quien lo edita no tiene, ni
   `system_permissions_manage`. Validación en el modelo, no solo en la UI.
2. **Webhooks, integraciones y bots.** Hoy reciben el contacto completo. Recomendación: el
   enmascarado **no** aplica ahí (rompería integraciones y los ERPs necesitan el teléfono) — el
   permiso es para personas, no para máquinas. Conviene dejarlo escrito.
3. **Agente IA y transcripciones.** Si el número aparece en el **cuerpo** de un mensaje, el
   enmascarado del contacto no lo tapa. Enmascarar texto libre queda fuera de alcance.
4. **Rendimiento.** El filtro por participación añade joins; revisar índices sobre
   `conversation_participants` antes de F2.
5. **Caché de permisos en el front.** `getUserPermissions` lee del objeto `accounts` del usuario; un
   cambio de perfil sin broadcast deja al agente con permisos viejos hasta recargar.
6. **API pública / access tokens.** Heredan los permisos del agente: el enforcement debe vivir en
   policy/finder, nunca en el controlador del dashboard.
7. **Superadmin y cuentas de plataforma** quedan fuera de este módulo.

---

## 9. Pruebas mínimas

- **Backend (rspec):** para los 3 niveles de visibilidad, que `GET /conversations?assignee_type=all`
  **no** devuelva conversaciones ajenas; que `_contact` enmascare según permiso; que
  export/import respondan 403 sin permiso; que un no-admin no pueda editar perfiles.
- **Frontend:** pestañas según permiso; panel de contacto enmascarado con acciones de llamada y
  WhatsApp deshabilitadas; menú lateral sin los módulos sin permiso.
- **Regresión:** cuenta **sin** `system_permissions` se comporta idéntico a hoy, flags `hide_*`
  incluidos.
- Documento de Testeo Funcional al cerrar F4.

---

## 10. Decisiones tomadas

Todas las preguntas abiertas de la v1.0 quedaron resueltas:

| # | Decisión | Consecuencia en el plan |
|---|---|---|
| 1 | **Permisos por agente**, en tabla filtrable con paginado estilo `/contacts?page=1` | `account_users.permissions`; `custom_roles` = plantillas (§4, §5) |
| 2 | La opción vive en **Configuración › Permisos** | reactivar ruta y menú ya existentes (§5) |
| 3 | **Enmascarado parcial**: `+52 55•• ••88`, `ju••••@••••.com` | el partial devuelve valor enmascarado + `*_masked: true` (§3.3) |
| 4 | **Sí puede responder por WhatsApp** sin ver el número | responder no requiere `contact_view_phone`; solo se bloquean las acciones que exponen el número en claro (§10.1) |
| 5 | **Activación por cuenta** vía feature `system_permissions` | igual que `case_management` y `erp_connection` (§2) |
| 6 | **Filtro por equipo** además del de agente | filtro sobre `team_members`; habilita "aplicar plantilla a todo el equipo" (§5.1) |

### 10.1 Qué significa "puede responder sin ver el número"

Es la parte con más filo del módulo, porque el número puede reaparecer por la puerta de atrás:

<svg viewBox="0 0 880 210" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Acciones permitidas y bloqueadas para un agente sin permiso de ver el telefono">
  <rect x="20" y="16" width="410" height="180" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="1.5"/>
  <text x="40" y="42" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#14532D">✓ SÍ PUEDE</text>
  <g font-family="system-ui, sans-serif" font-size="12" fill="#166534">
    <text x="40" y="70">• Abrir y responder la conversación de WhatsApp</text>
    <text x="40" y="94">• Enviar plantillas al contacto</text>
    <text x="40" y="118">• Crear una conversación nueva desde el contacto</text>
    <text x="40" y="142">• Ver nombre, avatar y etiquetas</text>
    <text x="40" y="166">• Buscar al contacto por nombre</text>
  </g>

  <rect x="450" y="16" width="410" height="180" rx="8" fill="#FEE2E2" stroke="#EF4444" stroke-width="1.5"/>
  <text x="470" y="42" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#7F1D1D">✕ NO PUEDE</text>
  <g font-family="system-ui, sans-serif" font-size="12" fill="#991B1B">
    <text x="470" y="70">• Ver el número completo en ningún panel</text>
    <text x="470" y="94">• Copiar el número (botón de copiar deshabilitado)</text>
    <text x="470" y="118">• Llamar / abrir wa.me o Wavoip con ese número</text>
    <text x="470" y="142">• Editar el campo teléfono (bloqueado, no oculto)</text>
    <text x="470" y="166">• Buscar POR número ni exportarlo a CSV</text>
  </g>
</svg>

La búsqueda por número es la fuga menos evidente: si el buscador acepta `5544` y devuelve
coincidencias, el agente reconstruye el teléfono por tanteo. Por eso, sin `contact_view_phone`,
el finder de búsqueda **no debe consultar la columna `phone_number`**.

### 10.2 Nuevas preguntas para la v1.2

1. ¿El enmascarado debe conservar la **lada del país** visible (`+52 55•• ••88`) o taparla también?
2. Cuando un agente pertenece a **dos equipos** y se aplica una plantilla distinta a cada uno,
   gana la última aplicada. ¿Te sirve así o quieres aviso antes de sobrescribir?

---

### Bitácora de versiones

| Versión | Fecha | Cambios |
|---|---|---|
| **1.1** | 2026-08-07 | Cerradas las 4 preguntas abiertas: enmascarado **parcial**, **sí** se puede responder por WhatsApp sin ver el número, activación **por cuenta**, y **filtro por equipo** en la tabla (con "aplicar plantilla a todo el equipo"). Nueva §10.1 con el detalle de qué puede y qué no puede hacer un agente sin `contact_view_phone`. |
| **1.0** | 2026-08-07 | Primera versión con ilustraciones SVG: estado actual, arquitectura de 4 capas, catálogo (~45 permisos), superficies de PII, modelo de datos, migración de flags y roadmap F1–F6. La pantalla se define como **tabla filtrable (agente + módulo) con paginado**, estilo Contactos, y los permisos pasan a guardarse **por agente** en `account_users.permissions`. |
