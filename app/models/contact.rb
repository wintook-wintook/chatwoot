# rubocop:disable Layout/LineLength
# /home/chatwoot/chatwoot/app/models/contact.rb
# == Schema Information
#
# Table name: contacts
#
#  id                    :integer          not null, primary key
#  additional_attributes :jsonb
#  blocked               :boolean          default(FALSE), not null
#  contact_type          :integer          default("visitor")
#  country_code          :string           default("")
#  custom_attributes     :jsonb
#  email                 :string
#  email_bounce_reason   :string
#  email_bounced_at      :datetime
#  identifier            :string
#  last_activity_at      :datetime
#  last_name             :string           default("")
#  location              :string           default("")
#  middle_name           :string           default("")
#  name                  :string           default("")
#  opted_out_at          :datetime
#  opted_out_source      :string
#  phone_number          :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :integer          not null
#  organization_id       :bigint
#  owner_id              :bigint
#
# Indexes
#
#  index_contacts_on_account_id                          (account_id)
#  index_contacts_on_account_id_and_last_activity_at     (account_id,last_activity_at DESC NULLS LAST)
#  index_contacts_on_blocked                             (blocked)
#  index_contacts_on_lower_email_account_id              (lower((email)::text), account_id)
#  index_contacts_on_name_email_phone_number_identifier  (name,email,phone_number,identifier) USING gin
#  index_contacts_on_nonempty_fields                     (account_id,email,phone_number,identifier) WHERE (((email)::text <> ''::text) OR ((phone_number)::text <> ''::text) OR ((identifier)::text <> ''::text))
#  index_contacts_on_organization_id                     (organization_id)
#  index_contacts_on_owner_id                            (owner_id)
#  index_contacts_on_phone_number_and_account_id         (phone_number,account_id)
#  index_resolved_contact_account_id                     (account_id) WHERE (((email)::text <> ''::text) OR ((phone_number)::text <> ''::text) OR ((identifier)::text <> ''::text))
#  uniq_email_per_account_contact                        (email,account_id) UNIQUE
#  uniq_identifier_per_account_contact                   (identifier,account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id) ON DELETE => nullify
#  fk_rails_...  (owner_id => users.id) ON DELETE => nullify
#

# rubocop:enable Layout/LineLength

class Contact < ApplicationRecord
  include Avatarable
  include AvailabilityStatusable
  include Labelable

  validates :account_id, presence: true
  validates :email, allow_blank: true, uniqueness: { scope: [:account_id], case_sensitive: false },
                    format: { with: Devise.email_regexp, message: I18n.t('errors.contacts.email.invalid') }
  validates :identifier, allow_blank: true, uniqueness: { scope: [:account_id] }
  validates :phone_number,
            allow_blank: true, uniqueness: { scope: [:account_id] },
            format: { with: /\+[1-9]\d{1,14}\z/, message: I18n.t('errors.contacts.phone_number.invalid') }

  belongs_to :account
  # Responsable fijo: sus conversaciones y sus casos nuevos van con esta persona
  # (ver ContactOwnerAssignment). Se limpia si sale de la cuenta.
  belongs_to :owner, class_name: 'User', optional: true
  validate :owner_belongs_to_account, if: :will_save_change_to_owner_id?
  # Plan-Organizaciones O1 — la empresa o el público en general que es prospecto o cliente.
  belongs_to :organization, optional: true
  validate :organization_in_account, if: :will_save_change_to_organization_id?
  # Al ligarlo por primera vez, lo suyo que no tenía organización pasa a ella. Cambiar de
  # una a otra solo con Organizations::ChangeContactOrganization.
  after_update_commit :adopt_unlinked_records, if: -> { saved_change_to_organization_id?(from: nil) }
  has_many :quotes, dependent: :destroy_async # Plan-Catalogo-Cotizaciones
  has_many :customer_assets, dependent: :destroy_async # Plan-Trabajo-Campo R4
  has_many :maintenance_plans, dependent: :destroy_async # Plan-Trabajo-Campo R4
  has_many :contracts, dependent: :destroy_async # Plan-Contratos R1
  # ================================================================================
  # proyecto@contact_tracking
  # ================================================================================
  has_many :contact_trackings, dependent: :destroy
  # @tickets_cases — al borrar el contacto, conserva el ticket como histórico (contact_id → NULL).
  has_many :case_tickets, dependent: :nullify
  # ================================================================================
  # ================================================================================
  # proyecto@commands_agents
  # ================================================================================
  has_many :command_sessions, dependent: :destroy
  # ================================================================================
  # ================================================================================
  # proyecto@user_contact
  # ================================================================================
  has_many :agent_account_users, class_name: 'AccountUser',
                                 foreign_key: 'agent_contact_id',
                                 dependent: :nullify,
                                 inverse_of: :agent_contact
  # ================================================================================
  has_many :conversations, dependent: :destroy_async
  has_many :calls, dependent: :destroy_async # diag/llamadas_whatsapp
  has_many :contact_inboxes, dependent: :destroy_async
  has_many :csat_survey_responses, dependent: :destroy_async
  has_many :inboxes, through: :contact_inboxes
  has_many :messages, as: :sender, dependent: :destroy_async
  has_many :notes, dependent: :destroy_async
  before_validation :prepare_contact_attributes
  after_create_commit :dispatch_create_event, :ip_lookup
  after_create_commit :create_label_also
  after_update_commit :dispatch_update_event
  after_destroy_commit :dispatch_destroy_event
  before_save :sync_contact_attributes

  enum contact_type: { visitor: 0, lead: 1, customer: 2 }
  

  scope :order_on_last_activity_at, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order("\"contacts\".\"last_activity_at\" #{direction}
          NULLS LAST")
      )
    )
  }
  scope :order_on_created_at, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order("\"contacts\".\"created_at\" #{direction}
          NULLS LAST")
      )
    )
  }
  scope :order_on_company_name, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order(
          "\"contacts\".\"additional_attributes\"->>'company_name' #{direction}
          NULLS LAST"
        )
      )
    )
  }
  scope :order_on_city, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order(
          "\"contacts\".\"additional_attributes\"->>'city' #{direction}
          NULLS LAST"
        )
      )
    )
  }
  scope :order_on_country_name, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order(
          "\"contacts\".\"additional_attributes\"->>'country' #{direction}
          NULLS LAST"
        )
      )
    )
  }

  scope :order_on_name, lambda { |direction|
    order(
      Arel::Nodes::SqlLiteral.new(
        sanitize_sql_for_order(
          "CASE
           WHEN \"contacts\".\"name\" ~~* '^+\d*' THEN 'z'
           WHEN \"contacts\".\"name\"  ~~*  '^\b*' THEN 'z'
           ELSE LOWER(\"contacts\".\"name\")
           END #{direction}"
        )
      )
    )
  }

  def get_source_id(inbox_id)
    contact_inboxes.find_by!(inbox_id: inbox_id).source_id
  end

  # prospeccion V4: pidió no ser contactado (ContactTrackings::OptOut)
  def opted_out?
    opted_out_at.present?
  end

  # prospeccion V7b: su correo rebotó (ContactTrackings::EmailBounce)
  def email_bounced?
    email_bounced_at.present?
  end

  def push_event_data
    {
      additional_attributes: additional_attributes,
      custom_attributes: custom_attributes,
      email: email,
      id: id,
      identifier: identifier,
      name: name,
      phone_number: phone_number,
      thumbnail: avatar_url,
      type: 'contact'
    }
  end

  def webhook_data
    {
      account: account.webhook_data,
      additional_attributes: additional_attributes,
      avatar: avatar_url,
      custom_attributes: custom_attributes,
      email: email,
      id: id,
      identifier: identifier,
      name: name,
      phone_number: phone_number,
      thumbnail: avatar_url
    }
  end

  def self.resolved_contacts
    where("contacts.email <> '' OR contacts.phone_number <> '' OR contacts.identifier <> ''")
  end

  def discard_invalid_attrs
    phone_number_format
    email_format
  end

  def self.from_email(email)
    find_by(email: email&.downcase)
  end

  # Plan-Organizaciones O3 — su responsable fijo o, si no tiene, el de su organización.
  def effective_owner_id
    owner_id || organization&.owner_id
  end

  private

  def ip_lookup
    return unless account.feature_enabled?('ip_lookup')

    ContactIpLookupJob.perform_later(self)
  end

  def phone_number_format
    return if phone_number.blank?

    self.phone_number = phone_number_was unless phone_number.match?(/\+[1-9]\d{1,14}\z/)
  end

  def email_format
    return if email.blank?

    self.email = email_was unless email.match(Devise.email_regexp)
  end

  def prepare_contact_attributes
    prepare_email_attribute
    prepare_jsonb_attributes
  end

  def prepare_email_attribute
    # So that the db unique constraint won't throw error when email is ''
    self.email = email.present? ? email.downcase : nil
  end

  def prepare_jsonb_attributes
    self.additional_attributes = {} if additional_attributes.blank?
    self.custom_attributes = {} if custom_attributes.blank?
  end

  def sync_contact_attributes
    ::Contacts::SyncAttributes.new(self).perform
    clear_email_bounce
  end

  # prospeccion V7b: el rebote era del correo anterior; con otro correo se vuelve a intentar.
  def clear_email_bounce
    return unless email_changed? && email_bounced_at.present?

    self.email_bounced_at = nil
    self.email_bounce_reason = nil
  end

  def dispatch_create_event
    Rails.configuration.dispatcher.dispatch(CONTACT_CREATED, Time.zone.now, contact: self)
  end

  def dispatch_update_event
    Rails.configuration.dispatcher.dispatch(CONTACT_UPDATED, Time.zone.now, contact: self, changed_attributes: previous_changes)
  end

  def dispatch_destroy_event
    Rails.configuration.dispatcher.dispatch(CONTACT_DELETED, Time.zone.now, contact: self)
  end

  def create_label_also
    prev_labels = Label.where(name: label_list)

    new_labels = label_list - prev_labels

    new_labels.each do |label|
      Label.create!(name: label)
    end
  end

  def adopt_unlinked_records
    Organizations::ContactRecords.new(self).adopt_unlinked!(organization_id) if organization_id
  end

  def organization_in_account
    return if organization.nil? || organization.account_id == account_id

    errors.add(:organization_id, 'no es de la cuenta')
  end

  def owner_belongs_to_account
    return if owner_id.nil? || account.account_users.exists?(user_id: owner_id)

    errors.add(:owner_id, 'no es un usuario de la cuenta')
  end
end
