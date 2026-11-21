# frozen_string_literal: true

# == Schema Information
#
# Table name: email_suppressions
#
#  id         :bigint           not null, primary key
#  email      :string           not null
#  reason     :string           not null
#  created_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_email_suppressions_on_account_id            (account_id)
#  index_email_suppressions_on_account_id_and_email  (account_id,email) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
# Correos que no se vuelven a cargar de una lista fría (ProspectLists::Import): se dieron de baja o rebotaron.
# Se guardan al borrar los contactos en cuarentena (ProspectLists::CleanupJob), para que no regresen.
class EmailSuppression < ApplicationRecord
  REASONS = %w[opted_out bounced].freeze

  belongs_to :account

  validates :email, presence: true
  validates :reason, inclusion: { in: REASONS }

  before_validation { self.email = email.to_s.strip.downcase }

  def self.add!(account, email, reason)
    return if email.blank?

    create_or_find_by!(account_id: account.id, email: email.to_s.strip.downcase) { |s| s.reason = reason }
  end
end
