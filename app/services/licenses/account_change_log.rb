# frozen_string_literal: true

# ================================================================================
# feat/licencias F6.4 — EL REGISTRO DE CAMBIOS DE UNA CUENTA
# ================================================================================
# Plan: docs/licencias_plan_v1.md, F6 (D6c). Lee lo que el sistema ya guarda con `audited`
# (tabla audits, asociado a la cuenta) y lo convierte en eventos que la ficha pinta como frases:
#
#   { id, at, user, kind, event, params, comment }
#
#   kind    licenses · agents · features · account · inboxes · other · access (para filtrar)
#   event   license_created · license_agents · license_status · license_changed · agent_added ·
#           agent_role · agent_removed · features_changed · account_status · account_changed · inbox_created ·
#           inbox_changed · inbox_deleted · inbox_member_added · inbox_member_removed · record_created · record_changed · record_deleted ·
#           sign_in · sign_out
#
# Se dejan fuera el ruido: la sincronización de plantillas de WhatsApp de una bandeja y los cambios
# de disponibilidad de un agente (en línea / ausente). Los accesos solo salen si se piden.
# Sin usuario = lo hizo el sistema (vencer, promover la cola, sincronizar).
# Pagina hacia atrás: `before` (id) y `next_before` en la respuesta.
# ================================================================================
class Licenses::AccountChangeLog
  KINDS = %w[licenses agents features account inboxes other access].freeze
  TYPES = {
    'AccountLicense' => 'licenses', 'AccountUser' => 'agents', 'Account' => 'account', 'Inbox' => 'inboxes', 'InboxMember' => 'inboxes',
    'Team' => 'other', 'AutomationRule' => 'other', 'Macro' => 'other', 'Webhook' => 'other', 'User' => 'access'
  }.freeze
  # Una bandeja que solo cambió esto se sincronizó sola: no es un cambio de nadie.
  INBOX_NOISE = %w[message_templates message_templates_last_updated updated_at].freeze
  ROLES = %w[agent administrator].freeze
  PER_PAGE = 50
  SCAN = 500

  pattr_initialize [:account!, :kind, :from, :to, :before]

  def perform
    eventos = []
    ultimo = nil
    scope.limit(SCAN).each do |registro|
      ultimo = registro.id
      evento = event_for(registro)
      next if evento.nil? || (kind.present? && evento[:kind] != kind)

      eventos << evento
      break if eventos.size >= PER_PAGE
    end
    { events: eventos, next_before: siguiente(eventos, ultimo) }
  end

  private

  def scope
    registros = Enterprise::AuditLog.where(associated_type: 'Account', associated_id: account.id)
    registros = kind.present? ? registros.where(auditable_type: tipos) : registros.where.not(auditable_type: 'User')
    registros = registros.where(created_at: dates) if dates
    registros = registros.where(id: ...before.to_i) if before.to_i.positive?
    registros.includes(:user).order(id: :desc)
  end

  # Desde y hasta, por día completo; cualquiera de los dos puede faltar.
  def dates
    desde = fecha(from)&.beginning_of_day
    hasta = fecha(to)&.end_of_day
    return if desde.nil? && hasta.nil?

    desde..hasta
  end

  def tipos
    tipos = TYPES.select { |_tipo, grupo| grupo == kind }.keys
    kind == 'features' ? ['Account'] : tipos
  end

  # Hay más si se llenó la página o si se revisó todo el bloque sin llenarla.
  def siguiente(eventos, ultimo)
    return eventos.last[:id] if eventos.size >= PER_PAGE
    return ultimo if ultimo && scope.exists?(id: ...ultimo)

    nil
  end

  def fecha(valor)
    Date.iso8601(valor.to_s)
  rescue Date::Error
    nil
  end

  HANDLERS = {
    'AccountLicense' => :license_event, 'AccountUser' => :agent_event, 'Account' => :account_event,
    'Inbox' => :inbox_event, 'InboxMember' => :inbox_member_event, 'User' => :access_event
  }.freeze

  def event_for(registro)
    datos = send(HANDLERS.fetch(registro.auditable_type, :record_event), registro, registro.audited_changes || {})
    return if datos.nil?

    { id: registro.id, at: registro.created_at, user: registro.user&.available_name, comment: registro.comment.presence,
      **datos }
  end

  def access_event(registro, _cambios)
    { kind: 'access', event: registro.action, params: { name: registro.user&.available_name } }
  end

  # ---- Licencias ---------------------------------------------------------------
  def license_event(registro, cambios)
    nombre = valor(cambios['name']) || AccountLicense.find_by(id: registro.auditable_id)&.name
    return license_created(nombre, cambios) if registro.action == 'create'
    return licenses(:license_agents, name: nombre, from: cambios['max_agents'][0], to: cambios['max_agents'][1]) if par?(cambios['max_agents'])
    return license_status(nombre, cambios['status']) if par?(cambios['status'])
    return if cambios.except('updated_at').empty?

    licenses(:license_changed, name: nombre, fields: cambios.keys - ['updated_at'])
  end

  def license_created(nombre, cambios)
    licenses(:license_created, name: nombre, max_agents: valor(cambios['max_agents']), duration_days: valor(cambios['duration_days']),
                               status: estado(valor(cambios['status'])))
  end

  def license_status(nombre, par)
    licenses(:license_status, name: nombre, from: estado(par[0]), to: estado(par[1]))
  end

  def licenses(evento, params)
    { kind: 'licenses', event: evento.to_s, params: params }
  end

  def estado(valor)
    valor.is_a?(Integer) ? AccountLicense.statuses.key(valor) : valor
  end

  # ---- Agentes -----------------------------------------------------------------
  def agent_event(registro, cambios)
    usuario = User.find_by(id: valor(cambios['user_id']) || member_user_id(registro.auditable_id))
    nombre = usuario&.available_name
    case registro.action
    when 'create' then agents(:agent_added, name: nombre, role: rol(valor(cambios['role'])))
    when 'destroy' then agents(:agent_removed, name: nombre)
    else
      return unless par?(cambios['role'])

      agents(:agent_role, name: nombre, from: rol(cambios['role'][0]), to: rol(cambios['role'][1]))
    end
  end

  # Un cambio de rol no trae a quién: sale del miembro o, si ya no está, de su registro al entrar.
  def member_user_id(miembro_id)
    AccountUser.find_by(id: miembro_id)&.user_id ||
      Enterprise::AuditLog.where(auditable_type: 'AccountUser', auditable_id: miembro_id)
                          .where("audited_changes ? 'user_id'").order(:id).first&.audited_changes&.dig('user_id')
  end

  def agents(evento, params)
    { kind: 'agents', event: evento.to_s, params: params }
  end

  def rol(valor)
    valor.is_a?(Integer) ? ROLES[valor] : valor
  end

  # ---- La cuenta y sus funciones -------------------------------------------------
  def account_event(_registro, cambios)
    if par?(cambios['feature_flags'])
      encendidas, apagadas = features_diff(*cambios['feature_flags'])
      return { kind: 'features', event: 'features_changed', params: { on: encendidas, off: apagadas } } if (encendidas + apagadas).any?
    end
    return account_status(cambios['status']) if par?(cambios['status'])

    campos = cambios.keys - %w[updated_at feature_flags]
    return if campos.empty?

    params = { fields: campos }
    if par?(cambios['name'])
      params[:from] = cambios['name'][0]
      params[:to] = cambios['name'][1]
    end
    { kind: 'account', event: 'account_changed', params: params }
  end

  # Suspender y reactivar tienen su propia frase.
  def account_status(par)
    nuevo = par[1].is_a?(Integer) ? Account.statuses.key(par[1]) : par[1]
    { kind: 'account', event: 'account_status', params: { to: nuevo } }
  end

  # feature_flags es un número: la función n es el bit 2^(n-1) (FlagShihTzu).
  def features_diff(antes, despues)
    antes = antes.to_i
    despues = despues.to_i
    Featurable::FEATURES.each_with_object([[], []]) do |(posicion, simbolo), (encendidas, apagadas)|
      bit = 2**(posicion - 1)
      nombre = simbolo.to_s.delete_prefix('feature_')
      encendidas << nombre if (antes & bit).zero? && (despues & bit).positive?
      apagadas << nombre if (antes & bit).positive? && (despues & bit).zero?
    end
  end

  # ---- Bandejas y lo demás -----------------------------------------------------
  def inbox_event(registro, cambios)
    campos = cambios.keys - INBOX_NOISE
    return if registro.action == 'update' && campos.empty?

    nombre = valor(cambios['name']) || Inbox.find_by(id: registro.auditable_id)&.name
    evento = { 'create' => 'inbox_created', 'destroy' => 'inbox_deleted' }.fetch(registro.action, 'inbox_changed')
    { kind: 'inboxes', event: evento, params: { name: nombre, fields: campos } }
  end

  # Un agente que entra o sale de una bandeja.
  def inbox_member_event(registro, cambios)
    evento = { 'create' => 'inbox_member_added', 'destroy' => 'inbox_member_removed' }[registro.action]
    return if evento.nil?

    { kind: 'inboxes', event: evento,
      params: { name: User.find_by(id: valor(cambios['user_id']))&.available_name, inbox: Inbox.find_by(id: valor(cambios['inbox_id']))&.name } }
  end

  def record_event(registro, cambios)
    nombre = valor(cambios['name']) || registro.auditable_type.safe_constantize&.find_by(id: registro.auditable_id).try(:name)
    evento = { 'create' => 'record_created', 'destroy' => 'record_deleted' }.fetch(registro.action, 'record_changed')
    { kind: 'other', event: evento, params: { type: registro.auditable_type, name: nombre } }
  end

  # ---- Ayudas -----------------------------------------------------------------
  # En un create/destroy el valor viene suelto; en un update, como [antes, después].
  def valor(cambio)
    cambio.is_a?(Array) ? cambio.last : cambio
  end

  def par?(cambio)
    cambio.is_a?(Array) && cambio.size == 2
  end
end
