# == Schema Information
#
# Table name: event_attendees
#
#  id            :bigint           not null, primary key
#  attended_at   :datetime
#  cancelled_at  :datetime
#  confirmed_at  :datetime
#  invited_at    :datetime
#  source        :string           default("manual"), not null
#  status        :integer          default("invited"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  contact_id    :bigint           not null
#  event_id      :bigint           not null
#  updated_by_id :bigint
#
# Indexes
#
#  index_event_attendees_on_account_id               (account_id)
#  index_event_attendees_on_account_id_and_status    (account_id,status)
#  index_event_attendees_on_contact_id               (contact_id)
#  index_event_attendees_on_event_id                 (event_id)
#  index_event_attendees_on_event_id_and_contact_id  (event_id,contact_id) UNIQUE
#  index_event_attendees_on_updated_by_id            (updated_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (event_id => events.id) ON DELETE => cascade
#  fk_rails_...  (updated_by_id => users.id) ON DELETE => nullify
#
# Plan-Eventos E1 — un contacto en un evento y en qué va: invitado, confirmó, asistió,
# no asistió o canceló, con la fecha de cada paso y de dónde vino (a mano, CSV, agente…).
class EventAttendee < ApplicationRecord
  SOURCES = %w[manual csv agent campaign segment].freeze
  STAMPS = { 'invited' => :invited_at, 'confirmed' => :confirmed_at, 'attended' => :attended_at,
             'cancelled' => :cancelled_at }.freeze

  belongs_to :account
  belongs_to :event
  belongs_to :contact
  belongs_to :updated_by, class_name: 'User', optional: true

  enum status: { invited: 0, confirmed: 1, attended: 2, no_show: 3, cancelled: 4 }

  before_validation :stamp_status, if: :will_save_change_to_status?
  # Plan-Eventos E3 — al llegar a un estado, entra a las campañas continuas de ese estado.
  after_commit -> { Events::CampaignEnrollJob.perform_later(id) }, on: %i[create update],
                                                                   if: :saved_change_to_status?

  validates :contact_id, uniqueness: { scope: :event_id }
  validates :source, inclusion: { in: SOURCES }
  validate :same_account

  def change_status!(new_status, user)
    update!(status: new_status, updated_by: user)
  end

  private

  def stamp_status
    column = STAMPS[status]
    self[column] ||= Time.current if column
    self.invited_at ||= Time.current
  end

  def same_account
    return if event.nil? || contact.nil?

    errors.add(:contact_id, 'no es de la cuenta') if contact.account_id != account_id || event.account_id != account_id
  end
end
