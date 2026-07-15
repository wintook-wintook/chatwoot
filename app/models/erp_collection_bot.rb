# frozen_string_literal: true

# @query_databases — Bot cobrador.
#   Modo A (proactivo): un job programado corre `external_db_query` (facturas por
#   vencer / vencidas), y por cada fila compone un recordatorio desde
#   `message_template` (placeholders {{columna}}) y lo envía por `inbox`.
#   Modo B (reactivo, flag `mode_b_enabled`): habilita que el cliente consulte por
#   chat vía IA (function calling) — ver F5.
#
# == Schema Information
#
# Table name: erp_collection_bots
#
#  id                        :bigint           not null, primary key
#  active                    :boolean          default(TRUE), not null
#  last_run_at               :datetime
#  message_template          :text
#  mode_b_enabled            :boolean          default(FALSE), not null
#  name                      :string           not null
#  phone_column              :string           default("TELEFONO"), not null
#  run_hour                  :integer          default(8), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  external_db_connection_id :bigint           not null
#  external_db_query_id      :bigint
#  inbox_id                  :bigint
#
# Indexes
#
#  index_erp_collection_bots_on_account_id  (account_id)
#
class ErpCollectionBot < ApplicationRecord
  belongs_to :account
  belongs_to :external_db_connection
  belongs_to :external_db_query, optional: true
  belongs_to :inbox, optional: true

  validates :name, presence: true
  validates :run_hour, inclusion: { in: 0..23 }

  scope :active, -> { where(active: true) }
  scope :due_now, -> { active.where(run_hour: Time.current.hour) }

  # Aún no corrió hoy (anti-duplicado del recordatorio diario).
  def ran_today?
    last_run_at.present? && last_run_at >= Time.current.beginning_of_day
  end

  # Compone el recordatorio para una fila del resultado: {{COLUMNA}} → valor formateado.
  def render_message(row)
    (message_template || '').gsub(/\{\{\s*([A-Za-z0-9_]+)\s*\}\}/) do
      key = Regexp.last_match(1)
      format_value(row[key] || row[key.upcase] || row[key.downcase])
    end
  end

  private

  # Montos a 2 decimales, fechas sin la hora; el resto tal cual.
  def format_value(value)
    case value
    when Float, BigDecimal then format('%.2f', value)
    when Time, DateTime, ActiveSupport::TimeWithZone, Date then value.strftime('%d/%m/%Y')
    when nil then ''
    else value.to_s
    end
  end
end
