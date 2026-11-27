# frozen_string_literal: true

# Campaña con IA — las etiquetas que le quedan al CONTACTO por lo que contestó (TrackingCampaigns::CampaignKit):
# lo logró, «sí, la próxima» o «no me escriban de esto». Gana la última voluntad: al poner una, se quita la contraria
# (no-invitar quita volver-a-invitar y al revés). Si la etiqueta no existe en la cuenta, se crea.
#
#   TrackingCampaigns::ContactLabels.apply(contact, add: 'no-invitar', remove: ['volver-a-invitar'])
module TrackingCampaigns::ContactLabels
  COLORS = { 'achieved' => '#16a34a', 'future_yes' => '#2563eb', 'opt_out' => '#dc2626' }.freeze
  DESCRIPTION = 'La pone la campaña con IA según lo que contestó el contacto'

  module_function

  def apply(contact, add:, remove: [], kind: nil)
    return if contact.nil?

    add = add.to_s.presence
    ensure_label(contact.account, add, kind) if add
    list = (contact.label_list - (Array(remove).compact_blank - [add]) + [add]).compact.uniq
    contact.update!(label_list: list) if list.sort != contact.label_list.sort
  rescue StandardError => e
    Rails.logger.warn("[ContactLabels] contacto #{contact&.id}: #{e.class}: #{e.message}")
  end

  def ensure_label(account, title, kind)
    account.labels.find_or_create_by!(title: title) do |label|
      label.color = COLORS[kind.to_s] || '#64748b'
      label.description = DESCRIPTION
      label.show_on_sidebar = false
    end
  end
end
