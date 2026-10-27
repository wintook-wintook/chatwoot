# == Schema Information
#
# Table name: quotes
#
#  id                 :bigint           not null, primary key
#  accepted_by_name   :string
#  accepted_signature :text
#  currency           :string(3)        default("MXN"), not null
#  decided_at         :datetime
#  discount_total     :decimal(14, 2)   default(0.0), not null
#  notes              :text
#  number             :integer          not null
#  outcome_note       :text
#  postponed_until    :date
#  public_token       :string           not null
#  sent_at            :datetime
#  status             :integer          default("draft"), not null
#  subtotal           :decimal(14, 2)   default(0.0), not null
#  tax_total          :decimal(14, 2)   default(0.0), not null
#  terms              :text
#  total              :decimal(14, 2)   default(0.0), not null
#  valid_until        :date
#  version            :integer          default(1), not null
#  viewed_at          :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  assignee_id        :bigint
#  contact_id         :bigint           not null
#  opportunity_id     :bigint
#  origin_ticket_id   :bigint
#  outcome_reason_id  :bigint
#  parent_quote_id    :bigint
#
# Indexes
#
#  index_quotes_on_account_id                         (account_id)
#  index_quotes_on_account_id_and_number_and_version  (account_id,number,version) UNIQUE
#  index_quotes_on_account_id_and_status              (account_id,status)
#  index_quotes_on_assignee_id                        (assignee_id)
#  index_quotes_on_contact_id                         (contact_id)
#  index_quotes_on_opportunity_id                     (opportunity_id)
#  index_quotes_on_origin_ticket_id                   (origin_ticket_id)
#  index_quotes_on_outcome_reason_id                  (outcome_reason_id)
#  index_quotes_on_parent_quote_id                    (parent_quote_id)
#  index_quotes_on_public_token                       (public_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (assignee_id => users.id) ON DELETE => nullify
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (opportunity_id => case_tickets.id) ON DELETE => nullify
#  fk_rails_...  (origin_ticket_id => case_tickets.id) ON DELETE => nullify
#  fk_rails_...  (outcome_reason_id => case_outcome_reasons.id) ON DELETE => nullify
#  fk_rails_...  (parent_quote_id => quotes.id) ON DELETE => nullify
#

# Plan-Catalogo-Cotizaciones V1 — una cotización. Puede vivir sola (el vendedor
# controla su estado) o ligarse a una oportunidad (`opportunity`, se sincronizan:
# Quotes::OpportunitySync) y/o al caso que la originó (`origin_ticket`: proyecto,
# orden o soporte; al ganarse, sus partidas pasan ahí: Quotes::ApplyToOrigin).
#
# Estados = los de la oportunidad: borrador, enviada, ganada, perdida, pospuesta,
# cancelada. «Vencida» no es estado: una enviada con la vigencia pasada.
class Quote < ApplicationRecord
  OPEN_STATUSES = %w[draft sent].freeze
  LIVE_STATUSES = %w[draft sent postponed].freeze
  CLOSED_STATUSES = %w[won lost cancelled].freeze

  belongs_to :account
  belongs_to :contact
  belongs_to :assignee, class_name: 'User', optional: true
  belongs_to :opportunity, class_name: 'CaseTicket', optional: true
  belongs_to :origin_ticket, class_name: 'CaseTicket', optional: true
  belongs_to :parent_quote, class_name: 'Quote', optional: true
  belongs_to :outcome_reason, class_name: 'CaseOutcomeReason', optional: true
  has_many :items, -> { order(:position, :id) }, class_name: 'QuoteItem', dependent: :destroy, inverse_of: :quote

  has_secure_token :public_token

  enum status: { draft: 0, sent: 1, won: 2, lost: 3, postponed: 4, cancelled: 5 }

  before_validation :assign_number, on: :create
  before_validation -> { self.currency = currency.to_s.upcase.presence || 'MXN' }

  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validate :links_belong_to_account

  scope :live, -> { where(status: LIVE_STATUSES) }
  scope :open_quotes, -> { where(status: OPEN_STATUSES) }
  scope :expired, -> { sent.where(valid_until: ...Date.current) }

  def folio
    base = format('COT-%04d', number)
    version > 1 ? "#{base} v#{version}" : base
  end

  def open?
    OPEN_STATUSES.include?(status)
  end

  def live?
    LIVE_STATUSES.include?(status)
  end

  def expired?
    sent? && valid_until.present? && valid_until < Date.current
  end

  def editable?
    draft? || sent?
  end

  # Suma las partidas: subtotal (sin descuento), descuento, impuestos y total.
  def recalculate!
    rows = items.reload
    gross = rows.sum { |item| item.quantity * item.unit_price }
    net = rows.sum(&:net_amount)
    tax = rows.sum(&:tax_amount)
    update!(subtotal: gross.round(2), discount_total: (gross - net).round(2), tax_total: tax.round(2),
            total: (net + tax).round(2))
    mirror_amount_on_opportunity
  end

  private

  # Con una sola cotización, la oportunidad abierta lleva su monto (espejo).
  def mirror_amount_on_opportunity
    return if opportunity.nil? || opportunity.closed? || opportunity.cancelled?
    return unless opportunity.quotes.count == 1

    opportunity.update!(amount: total, currency: currency)
  end

  def assign_number
    self.number ||= parent_quote&.number || (account.quotes.maximum(:number).to_i + 1)
  end

  def links_belong_to_account
    errors.add(:contact, 'no es de la cuenta') if foreign?(contact)
    errors.add(:origin_ticket, 'no es de la cuenta') if foreign?(origin_ticket)
    errors.add(:opportunity, 'no es una oportunidad de la cuenta') if opportunity && (foreign?(opportunity) || !opportunity.commercial?)
  end

  def foreign?(record)
    record.present? && record.account_id != account_id
  end
end
