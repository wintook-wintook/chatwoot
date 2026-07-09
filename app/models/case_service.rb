# frozen_string_literal: true

# == Schema Information
#
# Table name: case_services
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  color      :string           default("#64748b"), not null
#  name       :string           not null
#  position   :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_case_services_on_account_id_and_position  (account_id,position)
#

# @tickets_cases 2B — Servicio afectado (CRM, Microsip, Servidor, etc.) configurable por cuenta.
class CaseService < ApplicationRecord
  belongs_to :account
  has_many   :case_tickets, foreign_key: :affected_service_id, dependent: :nullify, inverse_of: :affected_service

  validates :name,  presence: true, length: { maximum: 100 }
  validates :color, presence: true

  scope :ordered, -> { order(:position, :id) }
  scope :enabled, -> { where(active: true) }

  # Servicios por defecto que se crean cuando la cuenta abre el módulo sin servicios.
  DEFAULTS = [
    'CRM Administrativo', 'CRM Conversacional / Wintook', 'Integración Microsip',
    'Integración Aspel', 'Integración CONTPAQ', 'WhatsApp / Meta', 'Servidor',
    'Base de datos', 'Reportes', 'Facturación', 'Otro'
  ].freeze

  def self.ensure_defaults_for(account)
    return account.case_services.ordered if account.case_services.exists?

    DEFAULTS.each_with_index do |name, position|
      account.case_services.create!(name: name, position: position)
    end
    account.case_services.ordered
  end
end
