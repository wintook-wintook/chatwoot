# == Schema Information
#
# Table name: crm_quote_items
#
#  id                 :bigint           not null, primary key
#  description        :string(200)      not null
#  discount_amount    :decimal(15, 2)   default(0.0), not null
#  discount_percent   :decimal(9, 6)    default(0.0), not null
#  extra_notes        :text
#  gross_amount       :decimal(15, 2)   default(0.0), not null
#  key                :string(20)
#  net_amount         :decimal(15, 2)   default(0.0), not null
#  notes              :text
#  position           :integer          default(0), not null
#  quantity           :decimal(18, 5)   default(1.0), not null
#  role               :string(1)        default("normal"), not null
#  tax_amount         :decimal(18, 6)   default(0.0), not null
#  unit               :string(20)
#  unit_price         :decimal(18, 6)   default(0.0), not null
#  withholding_amount :decimal(18, 6)   default(0.0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  account_id         :bigint           not null
#  article_id         :bigint
#  parent_item_id     :bigint
#  price_list_id      :bigint
#  quote_id           :bigint           not null
#
# Indexes
#
#  index_crm_quote_items_on_account_id      (account_id)
#  index_crm_quote_items_on_article_id      (article_id)
#  index_crm_quote_items_on_parent_item_id  (parent_item_id)
#  index_crm_quote_items_on_price_list_id   (price_list_id)
#  index_crm_quote_items_on_quote_id        (quote_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (article_id => crm_articles.id) ON DELETE => nullify
#  fk_rails_...  (parent_item_id => crm_quote_items.id) ON DELETE => cascade
#  fk_rails_...  (price_list_id => crm_lookups.id) ON DELETE => nullify
#  fk_rails_...  (quote_id => crm_quotes.id) ON DELETE => cascade
#

# CrmZeus Q0 — partida de una cotización (DCDOCTOS_PDV_DET). Copia clave, descripción y unidad
# del artículo al cotizar. Un kit (rol J) lleva sus componentes (rol C) como renglones hijos, sin
# importe propio (en CRMZeus iban ligados en SUB_MOVTOS_PDV). Los importes los pone Crm::QuoteTotals.
class CrmQuoteItem < ApplicationRecord
  PARENT_MESSAGE = 'es obligatorio para un componente de kit'.freeze

  belongs_to :account
  belongs_to :quote, class_name: 'CrmQuote', inverse_of: :items
  belongs_to :parent_item, class_name: 'CrmQuoteItem', optional: true, inverse_of: :components
  belongs_to :article, class_name: 'CrmArticle', optional: true
  belongs_to :price_list, class_name: 'CrmLookup', optional: true

  has_many :components, -> { order(:position, :id) }, class_name: 'CrmQuoteItem', foreign_key: :parent_item_id,
                                                      inverse_of: :parent_item, dependent: :destroy, autosave: false
  has_many :item_taxes, -> { order(:id) }, class_name: 'CrmQuoteItemTax', foreign_key: :item_id, inverse_of: :item,
                                           dependent: :destroy, autosave: true

  # Mismas letras que ROL de CRMZeus (sin K: las características no se traen).
  enum role: { normal: 'N', kit: 'J', component: 'C' }, _prefix: :role

  before_validation :prepare

  validates :description, presence: true, length: { maximum: 200 }
  validates :key, length: { maximum: 20 }
  validates :unit, length: { maximum: 20 }
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :parent_item, presence: { message: PARENT_MESSAGE }, if: :role_component?
  validate :references_belong_to_account
  validate :taxes_belong_to_account

  # Impuestos de la partida por id de `crm_taxes`; se resuelven contra los de la cuenta al validar.
  def tax_ids=(ids)
    @pending_tax_ids = Array(ids).compact_blank.map(&:to_i).uniq
  end

  def tax_ids
    @pending_tax_ids || item_taxes.reject(&:marked_for_destruction?).map(&:tax_id)
  end

  # Conserva los renglones que siguen, quita los que ya no y agrega los nuevos con nombre, tipo y %
  # del momento (la cotización no cambia si después se edita el impuesto).
  def assign_taxes(taxes)
    wanted = taxes.index_by(&:id)
    item_taxes.each { |row| row.mark_for_destruction unless wanted.key?(row.tax_id) }
    kept = item_taxes.reject(&:marked_for_destruction?).map(&:tax_id)
    wanted.except(*kept).each_value do |tax|
      item_taxes.build(account_id: account_id, tax: tax, name: tax.name, tax_type: tax.tax_type, percent: tax.percent)
    end
  end

  def live_taxes
    item_taxes.reject(&:marked_for_destruction?)
  end

  # Lo llama Crm::QuoteTotals antes de calcular (la cotización calcula antes de validar sus partidas).
  def prepare
    self.account_id ||= quote&.account_id
    copy_from_article
    resolve_tax_ids
  end

  private

  # La descripción se puede cambiar; si viene vacía es el nombre del artículo.
  def copy_from_article
    return unless article && (new_record? || article_id_changed?)

    self.key = article.key
    self.description = article.name if description.blank?
    self.unit = article.unit&.name if unit.blank?
  end

  def resolve_tax_ids
    return if @pending_tax_ids.nil?

    taxes = CrmTax.where(account_id: account_id, id: @pending_tax_ids).to_a
    @foreign_taxes = taxes.size != @pending_tax_ids.size
    assign_taxes(taxes)
    @pending_tax_ids = nil
  end

  def taxes_belong_to_account
    errors.add(:tax_ids, 'no pertenecen a la cuenta') if @foreign_taxes
  end

  def references_belong_to_account
    { article: article, price_list: price_list }.each do |name, record|
      errors.add(name, 'no pertenece a la cuenta') if record && record.account_id != account_id
    end
  end
end
