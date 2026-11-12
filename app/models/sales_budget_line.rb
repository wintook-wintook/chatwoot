# == Schema Information
#
# Table name: sales_budget_lines
#
#  id              :bigint           not null, primary key
#  amount          :decimal(14, 2)   default(0.0), not null
#  currency        :string(3)        default("MXN"), not null
#  note            :string
#  period          :date             not null
#  quantity        :decimal(12, 2)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  catalog_item_id :bigint
#  contact_id      :bigint
#  created_by_id   :bigint
#  organization_id :bigint
#  product_line_id :bigint
#  user_id         :bigint
#
# Indexes
#
#  index_sales_budget_lines_on_account_id_and_period              (account_id,period)
#  index_sales_budget_lines_on_account_id_and_user_id_and_period  (account_id,user_id,period)
#  index_sales_budget_lines_on_catalog_item_id                    (catalog_item_id)
#  index_sales_budget_lines_on_contact_id                         (contact_id)
#  index_sales_budget_lines_on_organization_id                    (organization_id)
#  index_sales_budget_lines_on_product_line_id                    (product_line_id)
#  index_sales_budget_lines_unique_dimensions                     (account_id, period, currency, COALESCE(user_id, (0)::bigint), COALESCE(organization_id, (0)::bigint), COALESCE(contact_id, (0)::bigint), COALESCE(product_line_id, (0)::bigint), COALESCE(catalog_item_id, (0)::bigint)) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id) ON DELETE => cascade
#  fk_rails_...  (catalog_item_id => catalog_items.id) ON DELETE => cascade
#  fk_rails_...  (contact_id => contacts.id) ON DELETE => cascade
#  fk_rails_...  (created_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (organization_id => organizations.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => cascade
#
# Presupuesto de ventas — una meta mensual, sin IVA. Las dimensiones son opcionales y
# se combinan: ninguna = global; vendedor; cliente (organización o contacto); línea;
# producto. Un solo renglón por combinación, mes y moneda (índice único).
# Etapa 1: vendedor (`seller`) y vendedor + cliente (`seller_client`).
class SalesBudgetLine < ApplicationRecord
  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :organization, optional: true
  belongs_to :contact, optional: true
  belongs_to :catalog_item, optional: true
  belongs_to :created_by, class_name: 'User', optional: true

  validates :period, :currency, presence: true
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validate :period_is_month_start
  validate :client_is_one

  before_validation -> { self.currency = currency.to_s.upcase.presence || 'MXN' }

  scope :in_year, ->(year) { where(period: Date.new(year, 1, 1)..Date.new(year, 12, 31)) }
  # Etapa 1: solo vendedor, o vendedor + cliente (sin línea ni producto).
  scope :without_products, -> { where(product_line_id: nil, catalog_item_id: nil) }
  scope :seller_only, -> { without_products.where.not(user_id: nil).where(organization_id: nil, contact_id: nil) }
  scope :seller_client, lambda {
    without_products.where.not(user_id: nil).where('organization_id IS NOT NULL OR contact_id IS NOT NULL')
  }

  def self.month(value)
    date = value.is_a?(Date) ? value : Date.parse("#{value.to_s[0, 7]}-01")
    date.beginning_of_month
  end

  private

  def period_is_month_start
    errors.add(:period, :invalid) if period && period.day != 1
  end

  def client_is_one
    errors.add(:contact_id, :invalid) if organization_id && contact_id
  end
end
