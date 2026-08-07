# F1 · Catálogo de permisos del sistema — versión definitiva

> **Fase:** F1 — primera entrega del ticket **DES-00011**
> **Tarea:** 38 · Definir el catálogo de permisos · vence lunes 10 de agosto, 16:00
> **Rama:** `feat/system-permissions` · **Fecha:** 2026-08-07
> **Anexo de:** "Módulo de Permisos del Sistema — Plan v1.1" (§3)
>
> Este documento es lo que dirección aprueba. Una vez aprobado, la lista queda congelada
> y se convierte en la base de todo el desarrollo: la pantalla de administración se dibuja
> a partir de ella y cada permiso se conecta con su parte del sistema.

---

## 1. Qué se está aprobando

**52 permisos organizados en 13 grupos.** Cada permiso es una casilla que el administrador
podrá encender o apagar para un agente concreto.

<svg viewBox="0 0 880 400" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Mapa del catálogo: 13 grupos de permisos y cuántos tiene cada uno">
  <text x="20" y="24" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#64748B">ATENCIÓN AL CLIENTE</text>
  <rect x="20" y="34" width="270" height="76" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="38" y="58" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#1E3A8A">Conversaciones · visibilidad</text>
  <text x="38" y="80" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">Todas / Mías + sin asignar / Solo mías</text>
  <circle cx="258" cy="58" r="15" fill="#3B82F6"/><text x="252" y="63" font-family="system-ui" font-size="13" font-weight="700" fill="#FFF">3</text>
  <text x="38" y="99" font-family="system-ui, sans-serif" font-size="10.5" font-style="italic" fill="#2563EB">se elige una, no se acumulan</text>

  <rect x="304" y="34" width="270" height="76" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="322" y="58" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#1E3A8A">Conversaciones · acciones</text>
  <text x="322" y="80" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">asignar, eliminar, estado, filtros…</text>
  <circle cx="542" cy="58" r="15" fill="#3B82F6"/><text x="536" y="63" font-family="system-ui" font-size="13" font-weight="700" fill="#FFF">7</text>

  <rect x="588" y="34" width="272" height="76" rx="8" fill="#DBEAFE" stroke="#3B82F6" stroke-width="1.5"/>
  <text x="606" y="58" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#1E3A8A">Bandejas de entrada</text>
  <text x="606" y="80" font-family="system-ui, sans-serif" font-size="11.5" fill="#1E40AF">ver "Todas", configurar bandejas</text>
  <circle cx="828" cy="58" r="15" fill="#3B82F6"/><text x="822" y="63" font-family="system-ui" font-size="13" font-weight="700" fill="#FFF">2</text>

  <text x="20" y="146" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#64748B">DATOS DEL CLIENTE</text>
  <rect x="20" y="156" width="840" height="76" rx="8" fill="#FEF3C7" stroke="#F59E0B" stroke-width="2"/>
  <text x="38" y="180" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#78350F">Contactos y datos personales</text>
  <text x="38" y="202" font-family="system-ui, sans-serif" font-size="11.5" fill="#92400E">ver módulo · crear · eliminar · fusionar · importar · exportar · notas · historial</text>
  <text x="38" y="221" font-family="system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#B45309">+ teléfono · correo · dirección · atributos personalizados · redes sociales</text>
  <circle cx="828" cy="188" r="17" fill="#F59E0B"/><text x="819" y="194" font-family="system-ui" font-size="13" font-weight="700" fill="#FFF">14</text>

  <text x="20" y="268" font-family="system-ui, sans-serif" font-size="13" font-weight="700" fill="#64748B">MÓDULOS DE TRABAJO</text>
  <g font-family="system-ui, sans-serif">
    <rect x="20" y="278" width="163" height="52" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
    <text x="34" y="300" font-size="12" font-weight="700" fill="#4C1D95">Tickets</text>
    <circle cx="160" cy="304" r="13" fill="#8B5CF6"/><text x="156" y="309" font-size="12" font-weight="700" fill="#FFF">4</text>
    <text x="34" y="318" font-size="10.5" fill="#6D28D9">míos / todos / gestionar / admin</text>

    <rect x="193" y="278" width="163" height="52" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
    <text x="207" y="300" font-size="12" font-weight="700" fill="#4C1D95">Kanban Oportunidades</text>
    <circle cx="333" cy="304" r="13" fill="#8B5CF6"/><text x="329" y="309" font-size="12" font-weight="700" fill="#FFF">2</text>
    <text x="207" y="318" font-size="10.5" fill="#6D28D9">ver / gestionar</text>

    <rect x="366" y="278" width="163" height="52" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
    <text x="380" y="300" font-size="12" font-weight="700" fill="#4C1D95">Base de Conocimiento</text>
    <circle cx="506" cy="304" r="13" fill="#8B5CF6"/><text x="502" y="309" font-size="12" font-weight="700" fill="#FFF">2</text>
    <text x="380" y="318" font-size="10.5" fill="#6D28D9">consultar / editar</text>

    <rect x="539" y="278" width="152" height="52" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
    <text x="553" y="300" font-size="12" font-weight="700" fill="#4C1D95">Campañas</text>
    <circle cx="668" cy="304" r="13" fill="#8B5CF6"/><text x="664" y="309" font-size="12" font-weight="700" fill="#FFF">1</text>
    <text x="553" y="318" font-size="10.5" fill="#6D28D9">crear y ejecutar</text>

    <rect x="701" y="278" width="159" height="52" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
    <text x="715" y="300" font-size="12" font-weight="700" fill="#4C1D95">Seguimientos IA</text>
    <circle cx="837" cy="304" r="13" fill="#8B5CF6"/><text x="833" y="309" font-size="12" font-weight="700" fill="#FFF">2</text>
    <text x="715" y="318" font-size="10.5" fill="#6D28D9">ver / gestionar</text>

    <rect x="20" y="338" width="163" height="52" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
    <text x="34" y="360" font-size="12" font-weight="700" fill="#4C1D95">Consultas a ERP</text>
    <circle cx="160" cy="364" r="13" fill="#8B5CF6"/><text x="156" y="369" font-size="12" font-weight="700" fill="#FFF">2</text>
    <text x="34" y="378" font-size="10.5" fill="#6D28D9">consultar / configurar</text>

    <rect x="193" y="338" width="163" height="52" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
    <text x="207" y="360" font-size="12" font-weight="700" fill="#4C1D95">Reportes</text>
    <circle cx="333" cy="364" r="13" fill="#8B5CF6"/><text x="329" y="369" font-size="12" font-weight="700" fill="#FFF">3</text>
    <text x="207" y="378" font-size="10.5" fill="#6D28D9">ver / configurar / exportar</text>

    <rect x="366" y="338" width="163" height="52" rx="8" fill="#EDE9FE" stroke="#8B5CF6" stroke-width="1.5"/>
    <text x="380" y="360" font-size="12" font-weight="700" fill="#4C1D95">Productividad</text>
    <circle cx="506" cy="364" r="13" fill="#8B5CF6"/><text x="502" y="369" font-size="12" font-weight="700" fill="#FFF">4</text>
    <text x="380" y="378" font-size="10.5" fill="#6D28D9">respuestas, etiquetas, macros…</text>

    <rect x="539" y="338" width="321" height="52" rx="8" fill="#FEE2E2" stroke="#EF4444" stroke-width="1.5"/>
    <text x="553" y="360" font-size="12" font-weight="700" fill="#7F1D1D">Administración</text>
    <circle cx="837" cy="364" r="13" fill="#EF4444"/><text x="833" y="369" font-size="12" font-weight="700" fill="#FFF">6</text>
    <text x="553" y="378" font-size="10.5" fill="#991B1B">agentes · equipos · integraciones · cuenta · auditoría · permisos</text>
  </g>
</svg>

---

## 2. Tres reglas para leer el catálogo

### 2.1 El permiso de "ver" es la puerta del módulo

Si un agente no tiene el permiso de ver un módulo, ese módulo **no aparece en su menú** y todos
los permisos de ese grupo quedan desactivados. No hay que apagarlos uno por uno.

<svg viewBox="0 0 880 250" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="El permiso de ver actúa como puerta: sin él, el resto del grupo queda inactivo">
  <rect x="20" y="20" width="250" height="54" rx="8" fill="#DCFCE7" stroke="#22C55E" stroke-width="2"/>
  <rect x="34" y="38" width="14" height="14" rx="3" fill="#22C55E"/>
  <text x="60" y="50" font-family="system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#14532D">Ver el módulo de contactos</text>
  <text x="60" y="66" font-family="system-ui, sans-serif" font-size="10.5" fill="#166534">encendido → el resto se puede elegir</text>

  <path d="M145 74 L145 96" stroke="#22C55E" stroke-width="2" marker-end="url(#g1)"/>
  <defs><marker id="g1" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 z" fill="#22C55E"/></marker></defs>

  <g font-family="system-ui, sans-serif" font-size="11.5">
    <rect x="20" y="96" width="250" height="30" rx="5" fill="#FFFFFF" stroke="#22C55E"/>
    <rect x="34" y="104" width="13" height="13" rx="3" fill="#22C55E"/><text x="58" y="115" fill="#14532D">Crear y editar contactos</text>
    <rect x="20" y="130" width="250" height="30" rx="5" fill="#FFFFFF" stroke="#22C55E"/>
    <rect x="34" y="138" width="13" height="13" rx="3" fill="#FFFFFF" stroke="#94A3B8"/><text x="58" y="149" fill="#334155">Ver teléfono completo</text>
    <rect x="20" y="164" width="250" height="30" rx="5" fill="#FFFFFF" stroke="#22C55E"/>
    <rect x="34" y="172" width="13" height="13" rx="3" fill="#FFFFFF" stroke="#94A3B8"/><text x="58" y="183" fill="#334155">Exportar contactos</text>
    <rect x="20" y="198" width="250" height="30" rx="5" fill="#FFFFFF" stroke="#22C55E"/>
    <rect x="34" y="206" width="13" height="13" rx="3" fill="#22C55E"/><text x="58" y="217" fill="#14532D">Ver historial de conversaciones</text>
  </g>

  <text x="310" y="52" font-family="system-ui, sans-serif" font-size="24" fill="#94A3B8">vs</text>

  <rect x="380" y="20" width="250" height="54" rx="8" fill="#FEE2E2" stroke="#EF4444" stroke-width="2"/>
  <rect x="394" y="38" width="14" height="14" rx="3" fill="#FFFFFF" stroke="#EF4444" stroke-width="1.5"/>
  <text x="420" y="50" font-family="system-ui, sans-serif" font-size="12.5" font-weight="700" fill="#7F1D1D">Ver el módulo de contactos</text>
  <text x="420" y="66" font-family="system-ui, sans-serif" font-size="10.5" fill="#991B1B">apagado → módulo fuera del menú</text>

  <path d="M505 74 L505 96" stroke="#EF4444" stroke-width="2" marker-end="url(#g2)"/>
  <defs><marker id="g2" markerWidth="9" markerHeight="9" refX="5" refY="4.5" orient="auto"><path d="M0 0 L9 4.5 L0 9 z" fill="#EF4444"/></marker></defs>

  <g font-family="system-ui, sans-serif" font-size="11.5">
    <rect x="380" y="96" width="250" height="30" rx="5" fill="#F1F5F9" stroke="#CBD5E1"/>
    <rect x="394" y="104" width="13" height="13" rx="3" fill="#E2E8F0" stroke="#CBD5E1"/><text x="418" y="115" fill="#94A3B8">Crear y editar contactos</text>
    <rect x="380" y="130" width="250" height="30" rx="5" fill="#F1F5F9" stroke="#CBD5E1"/>
    <rect x="394" y="138" width="13" height="13" rx="3" fill="#E2E8F0" stroke="#CBD5E1"/><text x="418" y="149" fill="#94A3B8">Ver teléfono completo</text>
    <rect x="380" y="164" width="250" height="30" rx="5" fill="#F1F5F9" stroke="#CBD5E1"/>
    <rect x="394" y="172" width="13" height="13" rx="3" fill="#E2E8F0" stroke="#CBD5E1"/><text x="418" y="183" fill="#94A3B8">Exportar contactos</text>
    <rect x="380" y="198" width="250" height="30" rx="5" fill="#F1F5F9" stroke="#CBD5E1"/>
    <rect x="394" y="206" width="13" height="13" rx="3" fill="#E2E8F0" stroke="#CBD5E1"/><text x="418" y="217" fill="#94A3B8">Ver historial de conversaciones</text>
  </g>

  <rect x="660" y="96" width="200" height="132" rx="8" fill="#F1F5F9" stroke="#94A3B8"/>
  <text x="676" y="120" font-family="system-ui, sans-serif" font-size="11.5" font-weight="700" fill="#334155">Aplica igual en:</text>
  <g font-family="system-ui, sans-serif" font-size="11" fill="#475569">
    <text x="676" y="142">• Tickets</text>
    <text x="676" y="160">• Kanban</text>
    <text x="676" y="178">• Base de Conocimiento</text>
    <text x="676" y="196">• Reportes</text>
    <text x="676" y="214">• Seguimientos y ERP</text>
  </g>
</svg>

### 2.2 Ver al cliente no es ver sus datos personales

Un agente puede tener acceso completo al módulo de contactos y aun así **no ver el teléfono ni
el correo**. Es exactamente el caso del perfil "Agente Junior": atiende con normalidad, pero el
dato sensible le llega enmascarado (`+52 55•• ••88`).

### 2.3 El administrador los tiene todos

No hace falta configurarle nada, y su fila en la pantalla es de solo lectura. Además, **nadie
puede otorgar el permiso de administrar permisos si no lo tiene**: así ningún usuario puede
subirse el nivel a sí mismo.

---

## 3. El catálogo

Los seis marcados con ✓ **ya existen** en la plataforma; los demás son nuevos.

### 3.1 Conversaciones — visibilidad *(se elige una)*

| Etiqueta visible | Permiso |
|---|---|
| Ver todas las conversaciones | `conversation_manage` ✓ |
| Ver las mías y las sin asignar | `conversation_unassigned_manage` ✓ |
| Ver solo las mías | `conversation_participating_manage` ✓ |

### 3.2 Conversaciones — acciones

| Etiqueta visible | Permiso |
|---|---|
| Asignar conversaciones a otros agentes | `conversation_assign_others` |
| **Cambiar el estado de una conversación** (resolver, posponer, reabrir) | `conversation_status_change` |
| Eliminar conversaciones | `conversation_delete` |
| Borrar mensajes enviados | `conversation_message_delete` |
| Descargar o enviar la transcripción | `conversation_transcript_download` |
| Ver notas privadas de otros agentes | `conversation_private_note_view` |
| Usar filtros avanzados y carpetas | `conversation_filters_use` |

### 3.3 Contactos y datos personales

| Etiqueta visible | Permiso |
|---|---|
| Ver el módulo de contactos | `contact_view` |
| Crear y editar contactos | `contact_manage` ✓ |
| Eliminar contactos | `contact_delete` |
| Fusionar contactos duplicados | `contact_merge` |
| Importar contactos | `contact_import` |
| Exportar contactos | `contact_export` |
| **Ver teléfono / WhatsApp completo** | `contact_view_phone` |
| **Ver correo electrónico completo** | `contact_view_email` |
| Ver dirección, ciudad y país | `contact_view_address` |
| Ver atributos personalizados (RFC, folio, saldo…) | `contact_view_custom_attributes` |
| Ver redes sociales del contacto | `contact_view_social` |
| **Ver el historial de conversaciones anteriores del contacto** | `contact_conversation_history_view` |
| Ver notas del contacto | `contact_notes_view` |
| Crear y editar notas del contacto | `contact_notes_manage` |

### 3.4 Bandejas de entrada

| Etiqueta visible | Permiso |
|---|---|
| Ver la bandeja "Todas las conversaciones" | `inbox_view_all` |
| Configurar bandejas y sus miembros | `inbox_manage` |

### 3.5 Tickets

| Etiqueta visible | Permiso |
|---|---|
| Ver solo mis tickets | `ticket_view_own` |
| Ver todos los tickets | `ticket_view_all` |
| Crear y gestionar tickets | `ticket_manage` |
| Administrar tipos, columnas y SLA | `ticket_admin` |

### 3.6 Kanban de Oportunidades

| Etiqueta visible | Permiso |
|---|---|
| Ver el Kanban | `kanban_view` |
| Mover tarjetas y configurar procesos | `kanban_manage` |

### 3.7 Base de Conocimiento

| Etiqueta visible | Permiso |
|---|---|
| Consultar la base de conocimiento | `knowledge_base_view` |
| Crear y editar artículos y portales | `knowledge_base_manage` ✓ |

### 3.8 Campañas y Agente Vendedor

| Etiqueta visible | Permiso |
|---|---|
| Crear y ejecutar campañas | `campaign_manage` |

### 3.9 Seguimientos IA

| Etiqueta visible | Permiso |
|---|---|
| Ver seguimientos | `contact_tracking_view` |
| Crear y editar seguimientos | `contact_tracking_manage` |

### 3.10 Consultas a ERP

| Etiqueta visible | Permiso |
|---|---|
| Consultar datos del ERP | `erp_query_use` |
| Configurar conexiones a bases de datos | `erp_connection_manage` |

### 3.11 Reportes

| Etiqueta visible | Permiso |
|---|---|
| Ver reportes | `report_view` |
| Configurar reportes | `report_manage` ✓ |
| Exportar reportes | `report_export` |

### 3.12 Productividad

| Etiqueta visible | Permiso |
|---|---|
| Administrar respuestas rápidas | `canned_response_manage` |
| Administrar etiquetas | `label_manage` |
| Administrar macros | `macro_manage` |
| Administrar automatizaciones | `automation_manage` |

### 3.13 Administración

| Etiqueta visible | Permiso |
|---|---|
| Administrar agentes | `agent_manage` |
| Administrar equipos | `team_manage` |
| Administrar integraciones | `integration_manage` |
| Ajustes generales de la cuenta | `account_settings_manage` |
| Ver bitácora de auditoría | `audit_log_view` |
| Administrar permisos del sistema | `system_permissions_manage` |

---

## 4. Plantillas predefinidas

Para no marcar 52 casillas a mano, el sistema traerá cinco plantillas listas. Se aplican a un
agente o a un equipo completo, y después se puede ajustar lo que sea necesario.

<svg viewBox="0 0 880 300" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Matriz de las cinco plantillas predefinidas frente a los permisos clave">
  <g font-family="system-ui, sans-serif" font-size="10.5" font-weight="700" fill="#64748B">
    <text x="250" y="40">Conversaciones</text>
    <text x="392" y="40">Teléfono</text>
    <text x="480" y="40">Correo</text>
    <text x="560" y="40">Exportar</text>
    <text x="650" y="40">Reportes</text>
    <text x="740" y="40">Tickets</text>
    <text x="820" y="40">Admin.</text>
  </g>

  <g font-family="system-ui, sans-serif">
    <!-- Supervisor -->
    <rect x="20" y="52" width="210" height="42" rx="6" fill="#DBEAFE" stroke="#3B82F6"/>
    <text x="36" y="70" font-size="12.5" font-weight="700" fill="#1E3A8A">Supervisor</text>
    <text x="36" y="86" font-size="10" fill="#2563EB">mira todo, no administra</text>
    <text x="252" y="78" font-size="10.5" fill="#334155">Todas</text>
    <circle cx="404" cy="73" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="400" y="78" font-size="11" fill="#15803D">✓</text>
    <circle cx="492" cy="73" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="488" y="78" font-size="11" fill="#15803D">✓</text>
    <circle cx="578" cy="73" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="574" y="78" font-size="11" fill="#15803D">✓</text>
    <circle cx="668" cy="73" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="664" y="78" font-size="11" fill="#15803D">✓</text>
    <circle cx="756" cy="73" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="752" y="78" font-size="11" fill="#15803D">✓</text>
    <circle cx="834" cy="73" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="830" y="78" font-size="11" fill="#B91C1C">✕</text>

    <!-- Agente -->
    <rect x="20" y="100" width="210" height="42" rx="6" fill="#DBEAFE" stroke="#3B82F6"/>
    <text x="36" y="118" font-size="12.5" font-weight="700" fill="#1E3A8A">Agente</text>
    <text x="36" y="134" font-size="10" fill="#2563EB">atención estándar</text>
    <text x="252" y="126" font-size="10.5" fill="#334155">Mías + sin asignar</text>
    <circle cx="404" cy="121" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="400" y="126" font-size="11" fill="#15803D">✓</text>
    <circle cx="492" cy="121" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="488" y="126" font-size="11" fill="#15803D">✓</text>
    <circle cx="578" cy="121" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="574" y="126" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="668" cy="121" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="664" y="126" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="756" cy="121" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="752" y="126" font-size="11" fill="#15803D">✓</text>
    <circle cx="834" cy="121" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="830" y="126" font-size="11" fill="#B91C1C">✕</text>

    <!-- Agente Junior -->
    <rect x="20" y="148" width="210" height="42" rx="6" fill="#FEF3C7" stroke="#F59E0B" stroke-width="2"/>
    <text x="36" y="166" font-size="12.5" font-weight="700" fill="#78350F">Agente Junior</text>
    <text x="36" y="182" font-size="10" fill="#B45309">sin datos sensibles</text>
    <text x="252" y="174" font-size="10.5" font-weight="700" fill="#78350F">Solo mías</text>
    <circle cx="404" cy="169" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="400" y="174" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="492" cy="169" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="488" y="174" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="578" cy="169" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="574" y="174" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="668" cy="169" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="664" y="174" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="756" cy="169" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="752" y="174" font-size="11" fill="#15803D">✓</text>
    <circle cx="834" cy="169" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="830" y="174" font-size="11" fill="#B91C1C">✕</text>

    <!-- Solo lectura -->
    <rect x="20" y="196" width="210" height="42" rx="6" fill="#F1F5F9" stroke="#94A3B8"/>
    <text x="36" y="214" font-size="12.5" font-weight="700" fill="#334155">Solo lectura</text>
    <text x="36" y="230" font-size="10" fill="#64748B">consulta, no responde</text>
    <text x="252" y="222" font-size="10.5" fill="#334155">Todas (sin responder)</text>
    <circle cx="404" cy="217" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="400" y="222" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="492" cy="217" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="488" y="222" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="578" cy="217" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="574" y="222" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="668" cy="217" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="664" y="222" font-size="11" fill="#15803D">✓</text>
    <circle cx="756" cy="217" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="752" y="222" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="834" cy="217" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="830" y="222" font-size="11" fill="#B91C1C">✕</text>

    <!-- Backoffice -->
    <rect x="20" y="244" width="210" height="42" rx="6" fill="#EDE9FE" stroke="#8B5CF6"/>
    <text x="36" y="262" font-size="12.5" font-weight="700" fill="#4C1D95">Backoffice / Tickets</text>
    <text x="36" y="278" font-size="10" fill="#6D28D9">sin bandeja de chats</text>
    <text x="252" y="270" font-size="10.5" fill="#94A3B8">— sin acceso —</text>
    <circle cx="404" cy="265" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="400" y="270" font-size="11" fill="#15803D">✓</text>
    <circle cx="492" cy="265" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="488" y="270" font-size="11" fill="#15803D">✓</text>
    <circle cx="578" cy="265" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="574" y="270" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="668" cy="265" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="664" y="270" font-size="11" fill="#B91C1C">✕</text>
    <circle cx="756" cy="265" r="11" fill="#DCFCE7" stroke="#22C55E"/><text x="752" y="270" font-size="11" fill="#15803D">✓</text>
    <circle cx="834" cy="265" r="11" fill="#FEE2E2" stroke="#EF4444"/><text x="830" y="270" font-size="11" fill="#B91C1C">✕</text>
  </g>
</svg>

---

## 5. Resumen por grupo

| # | Grupo | Permisos |
|---|---|---|
| 1 | Conversaciones — visibilidad | 3 |
| 2 | Conversaciones — acciones | 7 |
| 3 | Contactos y datos personales | 14 |
| 4 | Bandejas de entrada | 2 |
| 5 | Tickets | 4 |
| 6 | Kanban de Oportunidades | 2 |
| 7 | Base de Conocimiento | 2 |
| 8 | Campañas y Agente Vendedor | 1 |
| 9 | Seguimientos IA | 2 |
| 10 | Consultas a ERP | 2 |
| 11 | Reportes | 3 |
| 12 | Productividad | 4 |
| 13 | Administración | 6 |
| | **Total** | **52** |

---

## 6. Qué se necesita para cerrar esta tarea

1. Que dirección **apruebe las etiquetas en español** — son las que verá el administrador.
2. Que confirme si **falta o sobra** algún permiso.

Con esa aprobación, la tarea 38 queda completada y arranca la tarea 39 (preparar el sistema para
guardar los permisos por agente, con estas cinco plantillas ya cargadas), que vence el **martes 11
de agosto**.

---

### Cambios respecto a la propuesta inicial

| Cambio | Detalle |
|---|---|
| **+ Cambiar el estado de una conversación** | Permite decidir quién puede resolver, posponer o reabrir. Muy pedido en centros de atención, donde el cierre lo autoriza un supervisor. |
| **+ Ver el historial de conversaciones anteriores del contacto** | Permite que un agente atienda el caso presente sin acceder a todo lo que el cliente ha hablado antes con la empresa. |
| **Total** | 50 → **52 permisos** |
