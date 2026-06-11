# frozen_string_literal: true

# == Schema Information
#
# Table name: case_rules
#
#  id                :bigint           not null, primary key
#  actions           :jsonb            not null
#  active            :boolean          default(TRUE), not null
#  conditions        :jsonb            not null
#  continue_on_match :boolean          default(FALSE), not null
#  description       :text
#  name              :string           not null
#  position          :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :bigint           not null
#
# Indexes
#
#  index_case_rules_on_account_id_and_active_and_position  (account_id,active,position)
#

class CaseRule < ApplicationRecord
  belongs_to :account

  validates :name, presence: true
  validate  :conditions_must_be_array
  validate  :actions_must_be_array

  scope :enabled, -> { where(active: true).order(:position) }

  private

  def conditions_must_be_array
    errors.add(:conditions, 'must be an array') unless conditions.is_a?(Array)
  end

  def actions_must_be_array
    errors.add(:actions, 'must be an array') unless actions.is_a?(Array)
  end
end
