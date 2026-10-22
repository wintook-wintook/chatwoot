# frozen_string_literal: true

# ================================================================================
# diag/llamadas_whatsapp (F8) — LO QUE PASA CUANDO NADIE CONTESTÓ UNA LLAMADA
# ================================================================================
# «Perdida» = entrante que terminó sin agente (Call#missed?). Corre UNA vez por llamada
# (meta.missed_actions_done_at) desde Calls::MissedCallJob.
#
#   siempre       notificación (campana) a quienes les sonó + el asignado
#   note          línea en la conversación: «Llamada perdida de X. Sonó a: …»
#   label         etiqueta (por omisión llamada-perdida; se crea si no existe)
#   ticket   (P2) ticket abierto del contacto con ese tipo → se le agrega una nota;
#                 si no hay, se crea uno ligado a la conversación
#   tracking (P3) inscribe en la campaña elegida (TrackingCampaigns::Enroll, igual que la
#                 automatización); si ya tiene un seguimiento activo, se omite y queda dicho
#   auto_reply    mensaje al cliente si la ventana de 24 h está abierta; si no, queda dicho
#
# Las líneas para el agente son mensajes de actividad (no notas privadas): una nota
# saliente dispararía los ganchos de mensajes salientes (botseller, palabras clave).
# Cada acción va por su lado: si una falla, las demás siguen ([WHATSAPP CALL] en el log).
# Plan: docs/llamadas_whatsapp_plan.md §4.5
# ================================================================================
class Calls::MissedCallService
  ACTIONS = %w[note label ticket tracking auto_reply].freeze
  DEFAULT_LABEL = 'llamada-perdida'

  pattr_initialize [:call!]

  def perform
    return unless call.missed? && claim!

    notify_agents
    (ACTIONS & Array(config['missed_call_actions'])).each do |accion|
      send("#{accion}!")
    rescue StandardError => e
      Rails.logger.error "[WHATSAPP CALL] llamada perdida #{call.id}, acción #{accion}: #{e.class} #{e.message}"
    end
  end

  private

  def claim!
    call.with_lock do
      next false if call.meta['missed_actions_done_at'].present?

      call.merge_meta!('missed_actions_done_at' => Time.zone.now.to_i)
      true
    end
  end

  def config
    @config ||= call.inbox.channel.try(:provider_config).to_h
  end

  def conversation
    call.conversation
  end

  def contact_name
    call.contact&.name.presence || call.contact&.phone_number.to_s
  end

  def ringers
    User.where(id: Array(call.ring_state['ring_recipient_ids']))
  end

  def notify_agents
    ids = Array(call.ring_state['ring_recipient_ids']) | [conversation.assignee_id].compact
    call.account.users.where(id: ids).find_each do |usuario|
      Notification.create!(notification_type: :missed_call, user: usuario, account: call.account,
                           primary_actor: conversation, meta: { 'contact_name' => contact_name, 'call_id' => call.id })
    end
  end

  def note!
    nombres = ringers.map(&:available_name).to_sentence
    texto = if nombres.present?
              t('missed', name: contact_name, agents: nombres)
            else
              t('missed_nobody', name: contact_name)
            end
    activity(texto)
  end

  def label!
    titulo = config['missed_call_label'].to_s.strip.downcase.presence || DEFAULT_LABEL
    call.account.labels.find_or_create_by!(title: titulo)
    conversation.add_labels([titulo])
  end

  # P2: un ticket abierto del mismo tipo absorbe la llamada; si no, uno nuevo.
  def ticket!
    tipo = call.account.case_types.find_by(id: config['missed_call_case_type_id'])
    return activity(t('ticket_no_type')) unless tipo

    abierto = open_ticket(tipo)
    abierto ? add_to_ticket(abierto) : create_ticket(tipo)
  end

  def open_ticket(tipo)
    CaseTicket.where(account: call.account, contact: call.contact, case_type: tipo)
              .where.not(status: CaseTicket::CLOSED_STATUSES).order(created_at: :desc).first
  end

  def create_ticket(tipo)
    ticket = CaseTicket.create!(account: call.account, contact: call.contact, conversation: conversation, case_type: tipo,
                                origin: :whatsapp, assignee_type: :bot, title: t('ticket_title', name: contact_name))
    Cases::RuleEngineService.new(ticket).evaluate!
    activity(t('ticket_created', folio: folio(ticket)))
  end

  def add_to_ticket(ticket)
    ticket.add_internal_note!(content: t('ticket_note', name: contact_name, display_id: conversation.display_id))
    activity(t('ticket_noted', folio: folio(ticket)))
  end

  def folio(ticket)
    ticket.folio.presence || "##{ticket.id}"
  end

  # P3: se inscribe como lo haría la automatización «Agregar a campaña».
  def tracking!
    campana = call.account.tracking_campaigns.find_by(id: config['missed_call_campaign_id'])
    return activity(t('tracking_no_campaign')) unless campana

    entrada = TrackingCampaigns::Enroll.new(campana, call.contact, source: 'missed_call').call
    activity(tracking_text(entrada, campana))
  end

  def tracking_text(entrada, campana)
    return t('tracking_enrolled', campaign: campana.name) if entrada.enrolled?
    return t('tracking_active', campaign: campana.name) if entrada.reason == 'active_tracking'

    t('tracking_skipped', campaign: campana.name, reason: entrada.reason)
  end

  def auto_reply!
    return activity(t('auto_reply_window_closed')) unless window_open?

    texto = config['missed_call_auto_reply'].to_s.strip.presence ||
            I18n.with_locale(locale) { I18n.t('conversations.messages.whatsapp.missed_call_auto_reply') }
    conversation.messages.create!(account_id: call.account_id, inbox_id: call.inbox_id,
                                  message_type: :outgoing, content: texto)
  end

  # Ventana de 24 h: que el cliente haya ESCRITO hace menos de 24 h. La llamada misma no
  # cuenta hasta confirmar con Meta (F0) que una llamada entrante abre la ventana.
  # (Conversation#can_reply? solo la revisa si el canal trae la url de Graph.)
  def window_open?
    conversation.messages.incoming.where.not(content_type: :voice_call).exists?(['created_at > ?', 24.hours.ago])
  end

  def activity(texto)
    conversation.messages.create!(account_id: call.account_id, inbox_id: call.inbox_id,
                                  message_type: :activity, content: texto)
  end

  def locale
    call.account.locale.presence || I18n.default_locale
  end

  def t(llave, **args)
    I18n.with_locale(locale) { I18n.t("conversations.activity.whatsapp_call.missed_actions.#{llave}", **args) }
  end
end
