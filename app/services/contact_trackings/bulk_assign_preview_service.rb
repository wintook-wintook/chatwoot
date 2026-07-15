# frozen_string_literal: true

# ================================================================================
# @campanas_vendedor / proyecto@bulk_tracking_assign
# ================================================================================
# Servicio: ContactTrackings::BulkAssignPreviewService
# Descripción: Dry-run del bulk assign. Resuelve la audiencia por filtro y la
#              clasifica en buckets SIN crear nada, para que el modal muestre, en
#              tabs, qué le pasará a cada contacto al lanzar la campaña.
#
# Bucket NATURAL de cada contacto (precedencia: in_tracking → unreachable → ready):
#   :in_tracking  — ya tiene un seguimiento activo en el inbox (se omite si skip_active)
#   :unreachable  — no se le puede enviar por ese canal (sin teléfono/correo/…)
#   :ready        — recibirá el Agente IA
# Aparte, cada contacto trae `excluded: Boolean` (estaba en excluded_contact_ids). El
# front lo usa como tab propio y permite reclasificar al excluir/deshacer SIN re-pegarle
# al backend (por eso se devuelve el bucket natural, no uno "excluded" terminal).
#
# Retorna:
#   { channel: { inbox_id:, inbox_name:, channel_type: },
#     counts:  { ready:, in_tracking:, unreachable:, excluded:, total: },
#     contacts: [{ id:, name:, phone_number:, email:, bucket:, reason:, excluded: }],
#     counts_only: Boolean }
# Donde ready/in_tracking/unreachable cuentan SOLO los no-excluidos.
# Si la audiencia supera PREVIEW_LIMIT, devuelve counts_only: true con contacts: []
# y solo `total` (los demás conteos en 0): el usuario debe reducir el filtro.
# ================================================================================

class ContactTrackings::BulkAssignPreviewService
  include ContactTrackings::Eligibility

  # Tope de seguridad de contactos a clasificar/listar (la audiencia puede ser
  # mayor, pero el bulk real se limita a MAX_BULK_ASSIGN). Ver Preview-buckets-modal §6.
  PREVIEW_LIMIT = 200

  def initialize(account:, current_user:, filter_payload:, template_id:,
                 skip_active: true, excluded_contact_ids: [])
    @account              = account
    @current_user         = current_user
    @filter_payload       = filter_payload
    @template_id          = template_id
    @skip_active          = skip_active
    @excluded_contact_ids = Array(excluded_contact_ids).to_set(&:to_i)
  end

  def call
    template = @account.tracking_templates.find_by(id: @template_id)
    return { error: 'Plantilla no encontrada' } unless template

    inbox = template.inbox
    return { error: no_inbox_error(template) } unless inbox

    total = resolved[:count]
    # Audiencia demasiado grande para clasificar/listar → solo el total (counts_only).
    # El usuario debe reducir el filtro (igual no puede confirmar sobre el límite).
    return counts_only_result(inbox, total) if total > PREVIEW_LIMIT

    classified = classify_audience(inbox)

    {
      channel: channel_info(inbox),
      counts: count_buckets(classified, total),
      contacts: classified,
      counts_only: false
    }
  end

  private

  def no_inbox_error(template)
    "La plantilla '#{template.name}' no tiene un inbox configurado. " \
      'Asígnale un inbox antes de lanzar la campaña.'
  end

  def channel_info(inbox)
    { inbox_id: inbox.id, inbox_name: inbox.name, channel_type: inbox.channel_type }
  end

  def counts_only_result(inbox, total)
    {
      channel: channel_info(inbox),
      counts: { ready: 0, in_tracking: 0, unreachable: 0, excluded: 0, total: total },
      contacts: [],
      counts_only: true
    }
  end

  def classify_audience(inbox)
    contacts = resolved[:contacts].to_a
    ids      = contacts.map(&:id)

    active     = active_tracking_contact_ids(inbox.id, ids)
    with_convo = contacts_with_conversation_ids(inbox.id, ids)

    contacts.map { |c| classify(c, inbox.channel_type, active, with_convo) }
  end

  def resolved
    @resolved ||= ::Contacts::FilterService.new(
      @account, @current_user, { 'payload' => @filter_payload }.with_indifferent_access
    ).perform
  end

  def classify(contact, channel_type, active, with_convo)
    bucket, reason = natural_bucket(contact, channel_type, active, with_convo)
    {
      id: contact.id,
      name: contact.name,
      phone_number: contact.phone_number,
      email: contact.email,
      bucket: bucket,
      reason: reason,
      excluded: @excluded_contact_ids.include?(contact.id)
    }
  end

  # Bucket natural, ignorando la exclusión (que el front maneja aparte).
  def natural_bucket(contact, channel_type, active, with_convo)
    return [:in_tracking, nil] if @skip_active && active.include?(contact.id)

    contactable, reason = channel_contactability(contact, channel_type, reusable: with_convo.include?(contact.id))
    contactable ? [:ready, nil] : [:unreachable, reason]
  end

  # ready/in_tracking/unreachable solo cuentan los NO excluidos; excluded los excluidos.
  def count_buckets(rows, total)
    counts = { ready: 0, in_tracking: 0, unreachable: 0, excluded: 0 }
    rows.each do |row|
      row[:excluded] ? counts[:excluded] += 1 : counts[row[:bucket]] += 1
    end
    counts.merge(total: total)
  end
end
