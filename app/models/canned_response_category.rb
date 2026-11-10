# frozen_string_literal: true

# == Schema Information
#
# Table name: canned_response_categories
#
#  id          :bigint           not null, primary key
#  description :string
#  name        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#
# Indexes
#
#  index_canned_categories_on_account_and_lower_name  (account_id, lower((name)::text)) UNIQUE
#  index_canned_response_categories_on_account_id     (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#

# proyecto@respuestas_predefinidas R3 (docs/respuestas_predefinidas_plan.md §2): la
# categoría de una respuesta predefinida. Su nombre es el que se escribe en
# @buscar_predefinidas(NOMBRE) (R4), por eso no puede llevar paréntesis ni empezar con
# «!» (que en la directiva significa «todas menos esta»).
#
# El nombre viaja también en el vector de cada predefinida (knowledge_items.metadata
# 'category'), sin pedir embedding nuevo (D2): al renombrarla se actualiza ahí.
class CannedResponseCategory < ApplicationRecord
  NAME_MAX = 60
  INVALID_NAME = /[()]|\A!/

  belongs_to :account
  has_many :canned_responses, foreign_key: :category_id, inverse_of: :category, dependent: :nullify

  before_validation { self.name = name.to_s.squish }
  validates :name, presence: true, length: { maximum: NAME_MAX }
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }
  validate :name_usable_in_directive

  after_update_commit :sync_vector_metadata, if: :saved_change_to_name?
  # El borrado deja las predefinidas sin categoría (dependent: :nullify, en la base
  # ON DELETE NULLIFY): su vector tampoco la debe tener.
  before_destroy :remember_canned_ids, prepend: true
  after_destroy_commit :clear_vector_metadata

  private

  def name_usable_in_directive
    errors.add(:name, :invalid) if name.to_s.match?(INVALID_NAME)
  end

  def sync_vector_metadata
    CannedResponse.sync_category_metadata(canned_responses.pluck(:id), name)
  end

  def remember_canned_ids
    @canned_ids = canned_responses.pluck(:id)
  end

  def clear_vector_metadata
    CannedResponse.sync_category_metadata(@canned_ids, nil)
  end
end
