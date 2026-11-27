# == Schema Information
#
# Table name: crm_quote_series
#
#  id          :bigint           not null, primary key
#  last_number :integer          default(0), not null
#  series      :string(8)        not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_crm_quote_series_on_account_id              (account_id)
#  index_crm_quote_series_on_account_id_and_user_id  (account_id,user_id) UNIQUE
#  index_crm_quote_series_on_user_id                 (user_id)
#  index_crm_quote_series_unique_series              (account_id, upper((series)::text)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#

# CrmZeus Q0 — serie de folios de cotización de un agente (CTFOLIOS_USUARIOS, TIPO_DOCTO 'cot').
# `last_number` es el último consecutivo usado; Crm::QuoteFolio lo toma con bloqueo de renglón.
class CrmQuoteSeries < ApplicationRecord
  self.table_name = 'crm_quote_series'

  FORMAT_MESSAGE = 'solo letras y números'.freeze
  TAKEN_MESSAGE = 'ya la usa otro agente'.freeze
  USER_TAKEN_MESSAGE = 'ya tiene serie'.freeze
  FOLIO_LENGTH = 9 # F_Folio de CRMZeus: serie + consecutivo con ceros a la izquierda hasta 9 caracteres

  belongs_to :account
  belongs_to :user

  before_validation { self.series = series.to_s.strip.upcase }

  validates :series, presence: true, length: { maximum: 8 }, format: { with: /\A[A-Z0-9]+\z/, message: FORMAT_MESSAGE }
  validates :series, uniqueness: { scope: :account_id, case_sensitive: false, message: TAKEN_MESSAGE }
  validates :user_id, uniqueness: { scope: :account_id, message: USER_TAKEN_MESSAGE }
  validates :last_number, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :user_belongs_to_account

  scope :ordered, -> { order(:series) }

  def self.folio(series, number)
    series + number.to_s.rjust([FOLIO_LENGTH - series.length, 1].max, '0')
  end

  def next_folio
    self.class.folio(series, last_number + 1)
  end

  private

  def user_belongs_to_account
    return unless user && account

    errors.add(:user, 'no pertenece a la cuenta') unless account.account_users.exists?(user_id: user_id)
  end
end
