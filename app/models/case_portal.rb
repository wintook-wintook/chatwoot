# frozen_string_literal: true

# == Schema Information
#
# Table name: case_portals
#
#  id                      :bigint           not null, primary key
#  acuse_template_language :string           default("es"), not null
#  acuse_template_name     :string
#  custom_domain           :string
#  enabled                 :boolean          default(TRUE), not null
#  intro                   :text
#  locale                  :string           default("es"), not null
#  name                    :string           not null
#  slug                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :bigint           not null
#  inbox_id                :bigint
#
# Indexes
#
#  index_case_portals_on_account_id     (account_id)
#  index_case_portals_on_custom_domain  (custom_domain) UNIQUE WHERE (custom_domain IS NOT NULL)
#  index_case_portals_on_inbox_id       (inbox_id)
#  index_case_portals_on_slug           (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#

# @tickets_cases — User Portal (P1)
# Superficie pública del cliente (estilo osTicket). Se resuelve por `slug`
# (/portal/:slug) o, en el futuro, por `custom_domain` (Host), igual que el
# Help Center nativo de Chatwoot.
class CasePortal < ApplicationRecord
  # @tickets_cases — canales que permiten una conversación NUEVA iniciada por el
  # negocio. R1: API y Email. R2: WhatsApp (requiere plantilla de acuse aprobada).
  COMPATIBLE_CHANNELS = %w[Channel::Api Channel::Email Channel::Whatsapp].freeze

  belongs_to :account
  belongs_to :inbox, optional: true

  before_validation :normalize_slug
  before_validation :normalize_empty_custom_domain

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: 'solo minúsculas, números y guiones' }
  validates :custom_domain, uniqueness: true, allow_nil: true
  validate  :inbox_compatible
  validate  :whatsapp_needs_template

  # ¿El inbox destino es WhatsApp? (el acuse va por plantilla aprobada).
  def whatsapp_destination?
    inbox&.channel_type == 'Channel::Whatsapp'
  end

  scope :enabled, -> { where(enabled: true) }

  # Tipos de caso visibles en el formulario público del portal.
  def public_case_types
    account.case_types.where(public: true).ordered
  end

  # Inbox "Portal" (Channel::Api) donde nacen las conversaciones del portal cuando
  # el contacto no tiene una conversación abierta. Se crea perezosamente.
  def ensure_inbox!
    return inbox if inbox_id.present? && inbox

    channel = Channel::Api.create!(account: account)
    created = account.inboxes.create!(name: "#{name} Portal", channel: channel)
    update!(inbox: created)
    created
  end

  private

  # El inbox destino debe ser de la cuenta y de un canal que permita conversación nueva.
  def inbox_compatible
    return if inbox.blank?

    errors.add(:inbox, 'no pertenece a la cuenta') if inbox.account_id != account_id
    unless COMPATIBLE_CHANNELS.include?(inbox.channel_type)
      errors.add(:inbox, 'canal no compatible (usa API o Email)')
    end
  end

  # WhatsApp no admite texto libre iniciado por el negocio → exige plantilla de acuse.
  def whatsapp_needs_template
    return unless whatsapp_destination?

    errors.add(:acuse_template_name, 'es obligatorio para un portal de WhatsApp') if acuse_template_name.blank?
  end

  def normalize_slug
    self.slug = slug.presence || name
    self.slug = slug.to_s.parameterize
  end

  def normalize_empty_custom_domain
    self.custom_domain = nil if custom_domain.blank?
  end
end
