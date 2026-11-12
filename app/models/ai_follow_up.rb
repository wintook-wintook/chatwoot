# frozen_string_literal: true

# rubocop:disable Layout/LineLength -- la anotación del índice parcial (generada) pasa de 150
# == Schema Information
#
# Table name: ai_follow_ups
#
#  id                :bigint           not null, primary key
#  attempts          :integer          default(0), not null
#  finished_at       :datetime
#  instructions      :text
#  interval_unit     :string           default("days"), not null
#  interval_value    :integer          default(1), not null
#  last_error        :text
#  log               :jsonb            not null
#  max_attempts      :integer          default(3), not null
#  next_run_at       :datetime
#  objective         :text             not null
#  on_finish         :string           default("notify"), not null
#  outcome           :text
#  status            :string           default("active"), not null
#  template_language :string
#  template_name     :string
#  time_zone         :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#  case_ticket_id    :bigint
#  contact_id        :bigint
#  conversation_id   :bigint           not null
#  created_by_id     :bigint
#
# Indexes
#
#  index_ai_follow_ups_live_per_conversation      (conversation_id) UNIQUE WHERE ((status)::text = ANY ((ARRAY['active'::character varying, 'paused'::character varying])::text[]))
#  index_ai_follow_ups_on_account_id              (account_id)
#  index_ai_follow_ups_on_case_ticket_id          (case_ticket_id)
#  index_ai_follow_ups_on_contact_id              (contact_id)
#  index_ai_follow_ups_on_conversation_id         (conversation_id)
#  index_ai_follow_ups_on_created_by_id           (created_by_id)
#  index_ai_follow_ups_on_status_and_next_run_at  (status,next_run_at)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (case_ticket_id => case_tickets.id)
#  fk_rails_...  (contact_id => contacts.id)
#  fk_rails_...  (conversation_id => conversations.id)
#  fk_rails_...  (created_by_id => users.id)
#
# rubocop:enable Layout/LineLength
class AiFollowUp < ApplicationRecord
  DISPLAY_NAME = 'Seguimiento IA'
  LIVE = %w[active paused].freeze
  FINISHED = %w[done failed handed_off no_response blocked cancelled].freeze
  STATUSES = (LIVE + FINISHED).freeze
  UNITS = %w[minutes hours days].freeze
  ON_FINISH = %w[notify assign].freeze
  MAX_LOG = 60

  belongs_to :account
  belongs_to :conversation
  belongs_to :contact, optional: true
  belongs_to :case_ticket, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :objective, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :interval_unit, inclusion: { in: UNITS }
  validates :on_finish, inclusion: { in: ON_FINISH }
  validates :max_attempts, numericality: { in: 1..10 }
  validates :interval_value, numericality: { greater_than: 0 }

  scope :live, -> { where(status: LIVE) }
  scope :active, -> { where(status: 'active') }
  scope :due, -> { active.where(next_run_at: ..Time.current) }

  # messages.content_attributes se guarda como TEXTO JSON dentro de la columna json (store con
  # coder: JSON), así que `->>` directo da NULL. `#>> '{}'` saca el texto y ::jsonb lo vuelve objeto.
  def self.message_attr_sql(key)
    "((messages.content_attributes #>> '{}')::jsonb ->> '#{key}')"
  end

  # Los mensajes que este agente le mandó al cliente (y sus notas).
  def messages
    conversation.messages.where("#{self.class.message_attr_sql('ai_follow_up_id')} = ?", id.to_s)
  end

  def self.live_for?(conversation_id)
    conversation_id.present? && live.exists?(conversation_id: conversation_id)
  end

  def live?
    LIVE.include?(status)
  end

  def zone
    ActiveSupport::TimeZone[time_zone.to_s] || ActiveSupport::TimeZone[conversation&.inbox&.timezone.to_s] || Time.zone
  end

  def interval
    interval_value.to_i.public_send(interval_unit)
  end

  def add_log(kind, text = nil)
    entry = { 'at' => Time.current.iso8601, 'kind' => kind.to_s, 'text' => text.to_s.first(500).presence }.compact
    self.log = (Array(log) + [entry]).last(MAX_LOG)
  end

  def pause!(by: nil)
    return false unless status == 'active'

    add_log(:paused, by&.name)
    update!(status: 'paused')
  end

  def resume!(by: nil)
    return false unless status == 'paused'

    add_log(:resumed, by&.name)
    update!(status: 'active', next_run_at: [next_run_at, Time.current].compact.max)
  end

  def cancel!(by: nil)
    return false unless live?

    add_log(:cancelled, by&.name)
    update!(status: 'cancelled', finished_at: Time.current)
  end
end
