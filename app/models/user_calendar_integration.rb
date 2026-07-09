# == Schema Information
#
# Table name: user_calendar_integrations
#
#  id                   :bigint           not null, primary key
#  alert_enabled        :boolean          default(TRUE)
#  alert_minutes_before :integer          default(15)
#  enabled_calendar_ids :jsonb
#  google_email         :string
#  tokens               :jsonb
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  user_id              :bigint           not null
#
# Indexes
#
#  index_user_calendar_integrations_on_account_id              (account_id)
#  index_user_calendar_integrations_on_user_id                 (user_id)
#  index_user_calendar_integrations_on_user_id_and_account_id  (user_id,account_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id)
#
class UserCalendarIntegration < ApplicationRecord
  belongs_to :user
  belongs_to :account

  validates :user_id, uniqueness: { scope: :account_id }
  validates :google_email, presence: true

  def access_token
    tokens['access_token']
  end

  def refresh_token
    tokens['refresh_token']
  end

  def token_expires_at
    tokens['expires_at'] ? Time.parse(tokens['expires_at']) : nil
  end

  def token_expired?
    token_expires_at.nil? || token_expires_at < Time.current + 5.minutes
  end

  def push_event_data
    { id: id, google_email: google_email }
  end

  def update_tokens(access_token:, refresh_token: nil, expires_at: nil)
    new_tokens = tokens.merge(
      'access_token' => access_token,
      'expires_at' => (expires_at || Time.current + 1.hour).utc.iso8601
    )
    new_tokens['refresh_token'] = refresh_token if refresh_token.present?
    update!(tokens: new_tokens)
  end
end
