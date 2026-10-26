# == Schema Information
#
# Table name: channel_internal
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#
# Indexes
#
#  index_channel_internal_on_account_id  (account_id) UNIQUE
#
class Channel::Internal < ApplicationRecord
  include Channelable

  self.table_name = 'channel_internal'
  EDITABLE_ATTRS = [].freeze

  validates :account_id, uniqueness: true

  def name
    'Interno'
  end
end
