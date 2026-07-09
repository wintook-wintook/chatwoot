# frozen_string_literal: true

# @query_databases
# Consulta predefinida (allowlist) sobre una conexión ERP. El SQL usa placeholders
# nombrados (`:rfc`, `:dias`) que el QueryRunner convierte en bind params del driver
# — nunca interpolación de strings. Solo se permiten SELECT (validado en el runner).
#
# == Schema Information
#
# Table name: external_db_queries
#
#  id                        :bigint           not null, primary key
#  active                    :boolean          default(TRUE), not null
#  ai_enabled                :boolean          default(FALSE), not null
#  description               :string
#  name                      :string           not null
#  params_schema             :jsonb            not null
#  result_format             :integer          default("table"), not null
#  row_limit                 :integer          default(200), not null
#  sql_template              :text             not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  account_id                :bigint           not null
#  external_db_connection_id :bigint           not null
#
# Indexes
#
#  index_external_db_queries_on_account_id           (account_id)
#  index_external_db_queries_on_connection_and_name  (external_db_connection_id,name) UNIQUE
#
class ExternalDbQuery < ApplicationRecord
  belongs_to :account
  belongs_to :external_db_connection

  # `table` colisiona con ActiveRecord::Relation#table → prefijo obligatorio.
  enum result_format: { table: 0, summary: 1, template: 2 }, _prefix: :format

  validates :name, presence: true,
                   format: { with: /\A[a-z0-9_]+\z/, message: I18n.t('errors.messages.invalid') },
                   uniqueness: { scope: :external_db_connection_id }
  validates :sql_template, presence: true
  validates :row_limit, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 5000 }
  validate :sql_is_select_only
  validate :params_schema_is_array

  before_validation :inherit_account

  scope :active, -> { where(active: true) }
  scope :ai_enabled, -> { where(ai_enabled: true) }

  # Claves de los parámetros declarados (para validar lo que llega del front/IA).
  def param_keys
    Array(params_schema).filter_map { |p| p['key'] || p[:key] }
  end

  private

  def inherit_account
    self.account_id ||= external_db_connection&.account_id
  end

  # Defensa en profundidad: además del read-only del runner, el template debe ser SELECT.
  def sql_is_select_only
    return if sql_template.blank?

    normalized = sql_template.strip.gsub(%r{/\*.*?\*/}m, '').sub(/\A\s*;*/, '')
    return if normalized.match?(/\A(SELECT|WITH)\b/i) &&
              !normalized.match?(/\b(INSERT|UPDATE|DELETE|DROP|ALTER|CREATE|TRUNCATE|MERGE|GRANT|EXEC|EXECUTE)\b/i)

    errors.add(:sql_template, 'solo se permiten consultas SELECT de solo lectura')
  end

  def params_schema_is_array
    errors.add(:params_schema, 'debe ser una lista') unless params_schema.is_a?(Array)
  end
end
