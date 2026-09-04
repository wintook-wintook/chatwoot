# == Schema Information
#
# Table name: custom_filters
#
#  id          :bigint           not null, primary key
#  filter_type :integer          default("conversation"), not null
#  name        :string           not null
#  query       :jsonb            not null
#  shared      :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_custom_filters_on_account_id           (account_id)
#  index_custom_filters_on_account_type_shared  (account_id,filter_type,shared)
#  index_custom_filters_on_user_id              (user_id)
#
class CustomFilter < ApplicationRecord
  MAX_FILTER_PER_USER = 50
  belongs_to :user
  belongs_to :account

  # @tickets_cases — ⚠ ESTE ENUM VA POR POSICION: el entero es lo que se guarda.
  # Un tipo nuevo se agrega SIEMPRE AL FINAL. Insertarlo en medio le cambia el
  # tipo a todos los filtros guardados que ya existen, en todas las cuentas, sin
  # error ni aviso: los que valian 1 pasarian a leerse como el tipo insertado.
  enum filter_type: { conversation: 0, contact: 1, report: 2, case_ticket: 3 }
  validate :validate_number_of_filters

  def validate_number_of_filters
    return true if account.custom_filters.where(user_id: user_id).size < MAX_FILTER_PER_USER

    errors.add :account_id, I18n.t('errors.custom_filters.number_of_records')
  end
end
