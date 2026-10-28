# == Schema Information
#
# Table name: crm_articles
#
#  id                    :bigint           not null, primary key
#  catalog_status        :integer          default("uncatalogued"), not null
#  cataloged_at          :datetime
#  is_stockable          :boolean          default(TRUE), not null
#  key                   :string(20)
#  name                  :string(200)      not null
#  normalized_name       :string(200)      not null
#  notes                 :text
#  purchase_unit         :string(20)
#  purchase_unit_content :decimal(18, 5)   default(1.0), not null
#  status                :string(1)        default("active"), not null
#  unit_weight           :decimal(18, 5)   default(0.0), not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  account_id            :bigint           not null
#  created_by_id         :bigint
#  line_id               :bigint
#  unit_id               :bigint
#  updated_by_id         :bigint
#
# Indexes
#
#  index_crm_articles_on_account_id                     (account_id)
#  index_crm_articles_on_account_id_and_catalog_status  (account_id,catalog_status)
#  index_crm_articles_on_created_by_id                  (created_by_id)
#  index_crm_articles_on_line_id                        (line_id)
#  index_crm_articles_on_unit_id                        (unit_id)
#  index_crm_articles_on_updated_by_id                  (updated_by_id)
#  index_crm_articles_unique_key                        (account_id, lower((key)::text)) UNIQUE WHERE (key IS NOT NULL)
#  index_crm_articles_unique_name                       (account_id,normalized_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (created_by_id => users.id) ON DELETE => nullify
#  fk_rails_...  (line_id => crm_article_lines.id) ON DELETE => nullify
#  fk_rails_...  (unit_id => crm_units.id) ON DELETE => nullify
#  fk_rails_...  (updated_by_id => users.id) ON DELETE => nullify
#

# CrmZeus A0 — artículo: catalogado (el del ERP) o no catalogado (dado de alta para cotizar),
# como ES_CATALOGADO de CRMZeus. Un solo registro para los dos; «catalogar» cambia el tipo
# y conserva el id. Clave y nombre no se repiten entre ambos (el nombre, sin acentos ni
# mayúsculas, como CRMZeus).
class CrmArticle < ApplicationRecord
  DUPLICATE_MESSAGE = 'ya está dado de alta en otro artículo'.freeze
  IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  IMAGE_MAX_SIZE = 5.megabytes

  belongs_to :account
  belongs_to :line, class_name: 'CrmArticleLine', optional: true
  belongs_to :unit, class_name: 'CrmUnit', optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  has_many :prices, -> { order(:id) }, class_name: 'CrmArticlePrice', foreign_key: :article_id, inverse_of: :article,
                                       dependent: :destroy
  has_many :article_taxes, class_name: 'CrmArticleTax', foreign_key: :article_id, inverse_of: :article, dependent: :destroy
  has_many :taxes, through: :article_taxes
  accepts_nested_attributes_for :prices, allow_destroy: true

  has_one_attached :image

  # Mismos valores que ES_CATALOGADO (S → 1, N → 2).
  enum catalog_status: { catalogued: 1, uncatalogued: 2 }
  # Mismas letras que ESTATUS de los artículos de Microsip.
  enum status: { active: 'A', inactive: 'B', purchases_suspended: 'C', sales_suspended: 'V', suspended: 'S' }, _prefix: :status

  before_validation :normalize
  after_validation :report_duplicate_name_on_name

  validates :catalog_status, :status, presence: true
  validates :name, presence: true, length: { maximum: 200 }
  validates :key, length: { maximum: 20 }
  validates :key, uniqueness: { scope: :account_id, case_sensitive: false, message: DUPLICATE_MESSAGE }, allow_nil: true
  validates :normalized_name, uniqueness: { scope: :account_id, message: DUPLICATE_MESSAGE }
  validates :purchase_unit, length: { maximum: 20 }
  validates :purchase_unit_content, numericality: { greater_than: 0 }
  validates :unit_weight, numericality: { greater_than_or_equal_to: 0 }
  validate :references_belong_to_account
  validate :image_is_valid

  scope :search, lambda { |term|
    next all if term.blank?

    like = "%#{sanitize_sql_like(normalize_name(term))}%"
    where('crm_articles.normalized_name LIKE :q OR lower(crm_articles.key) LIKE :q', q: like)
  }

  # «Cañón  Azul» → «canon azul»: lo que se compara para no repetir nombres.
  def self.normalize_name(value)
    I18n.transliterate(value.to_s.squish).downcase
  end

  # No catalogado → catalogado. Conserva el id (las partidas que lo apunten siguen ligadas).
  def catalog!(user = nil)
    raise ActiveRecord::RecordInvalid.new(self), 'ya está catalogado' if catalogued?

    update!(catalog_status: :catalogued, cataloged_at: Time.current, updated_by: user || updated_by)
  end

  private

  def normalize
    self.name = name.to_s.squish
    self.normalized_name = self.class.normalize_name(name)
    self.key = key.to_s.strip.upcase.presence
    self.purchase_unit = purchase_unit.to_s.strip.presence
  end

  # El nombre repetido se informa en `name` (lo que ve la persona), no en la columna interna.
  def report_duplicate_name_on_name
    errors[:normalized_name].each { |message| errors.add(:name, message) }
    errors.delete(:normalized_name)
  end

  def references_belong_to_account
    { line: line, unit: unit }.each do |name, record|
      errors.add(name, 'no pertenece a la cuenta') if record && record.account_id != account_id
    end
  end

  def image_is_valid
    return unless image.attached?

    errors.add(:image, 'debe ser una imagen (JPG, PNG, WebP o GIF)') unless IMAGE_TYPES.include?(image.blob.content_type)
    errors.add(:image, 'no puede pesar más de 5 MB') if image.blob.byte_size > IMAGE_MAX_SIZE
  end
end
