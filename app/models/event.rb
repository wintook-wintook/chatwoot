# == Schema Information
#
# Table name: events
#
#  id          :bigint           not null, primary key
#  capacity    :integer
#  closed_at   :datetime
#  description :text
#  ends_at     :datetime
#  kind        :integer          default("fair"), not null
#  location    :string
#  meeting_url :string
#  name        :string           not null
#  starts_at   :datetime         not null
#  status      :integer          default("draft"), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  owner_id    :bigint
#
# Indexes
#
#  index_events_on_account_id                (account_id)
#  index_events_on_account_id_and_starts_at  (account_id,starts_at)
#  index_events_on_owner_id                  (owner_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (owner_id => users.id) ON DELETE => nullify
#
# Plan-Eventos E1 — un evento (feria, curso, demostración, webinar…) con su lista de
# contactos (EventAttendee). Al cerrarlo, los que confirmaron y no llegaron quedan como
# «no asistió».
class Event < ApplicationRecord
  belongs_to :account
  belongs_to :owner, class_name: 'User', optional: true
  has_many :attendees, class_name: 'EventAttendee', dependent: :destroy
  has_many :contacts, through: :attendees

  enum kind: { fair: 0, course: 1, demo: 2, webinar: 3, other: 4 }
  enum status: { draft: 0, open: 1, closed: 2 }

  before_validation { self.name = name.to_s.strip }

  validates :name, presence: true, length: { maximum: 200 }
  validates :starts_at, presence: true
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :ends_after_start

  scope :ordered, -> { order(starts_at: :desc) }

  def self.search(term)
    return all if term.blank?

    where('events.name ILIKE :q OR events.location ILIKE :q', q: "%#{sanitize_sql_like(term.to_s.strip)}%")
  end

  # Cuántos hay en cada estado.
  def counts
    by_status = attendees.group(:status).count
    EventAttendee.statuses.keys.index_with { |key| by_status[key] || 0 }
  end

  # Cerrar: los que confirmaron y no hicieron check-in pasan a «no asistió».
  def close!(user)
    transaction do
      attendees.confirmed.find_each { |attendee| attendee.change_status!(:no_show, user) }
      update!(status: :closed, closed_at: Time.current)
    end
  end

  def reopen!
    update!(status: :open, closed_at: nil)
  end

  private

  def ends_after_start
    errors.add(:ends_at, 'debe ser después del inicio') if ends_at && starts_at && ends_at < starts_at
  end
end
