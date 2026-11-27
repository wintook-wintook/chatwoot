# == Schema Information
#
# Table name: quote_formats
#
#  id         :bigint           not null, primary key
#  is_default :boolean          default(FALSE), not null
#  name       :string           not null
#  settings   :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_quote_formats_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# Cotizaciones › Formatos — cómo se ve la cotización (la liga del cliente, su impresión y el PDF). La empresa
# diseña varios con bloques y escoge uno por cotización; uno es el de por omisión (Dali y los agentes lo usan).
#
#   brand    color, tipografía, hoja (carta/A4), logo (posición y tamaño)
#   blocks   [{ key, on }] en orden: header, client, intro, items, totals, terms, bank, signatures, footer
#   header   qué datos de la empresa se ven; company: los que cambian en este formato (otra razón social…)
#   client   qué datos del cliente · intro/terms/bank/footer: textos (intro con variables {{cliente}}…)
#   items    columnas (clave, foto, unidad, descuento, impuesto) y precios con IVA
#   totals   IVA desglosado, retenciones una por una, total con letra
#   signatures  firma del vendedor y del cliente
# Los datos de la empresa salen de case_settings.company_profile (Quotes::Company). Lo que no esté en settings
# toma el valor de DEFAULTS (config).
class QuoteFormat < ApplicationRecord
  BLOCKS = %w[header client intro items totals terms bank signatures footer].freeze
  FONTS = %w[Inter Roboto Lato Montserrat Merriweather].freeze
  COMPANY_FIELDS = %w[legal_name tax_id address phone email website].freeze
  CLIENT_FIELDS = %w[name organization tax_id email phone].freeze
  ITEM_COLUMNS = %w[sku image unit discount tax].freeze

  DEFAULTS = {
    'brand' => { 'color' => '#4f46e5', 'font' => 'Inter', 'paper' => 'letter', 'logo_position' => 'left', 'logo_size' => 'medium' },
    'blocks' => BLOCKS.map { |key| { 'key' => key, 'on' => %w[intro bank].exclude?(key) } },
    'header' => { 'fields' => %w[legal_name tax_id address phone email], 'company' => {} },
    'client' => { 'fields' => %w[name organization email phone] },
    'intro' => { 'text' => '' },
    'items' => { 'columns' => %w[unit discount tax], 'prices_with_tax' => false },
    'totals' => { 'tax_breakdown' => true, 'withholdings' => true, 'amount_in_words' => false },
    'terms' => { 'text' => '' },
    'bank' => { 'text' => '' },
    'signatures' => { 'seller' => false, 'client' => true },
    'footer' => { 'text' => '' }
  }.freeze

  belongs_to :account
  has_many :quotes, dependent: :nullify
  has_one_attached :logo

  before_validation :clean_settings
  validates :name, presence: true, length: { maximum: 80 }
  validate :logo_ok, if: -> { logo.attached? }
  after_save :single_default, if: :is_default?

  scope :ordered, -> { order(is_default: :desc, name: :asc) }

  # El de la cotización, el de por omisión o, si la cuenta no tiene, uno de fábrica sin guardar.
  def self.for(quote)
    quote.quote_format || default_for(quote.account)
  end

  def self.default_for(account)
    account.quote_formats.find_by(is_default: true) || account.quote_formats.order(:id).first ||
      account.quote_formats.new(name: I18n.t('quote_formats.default_name'), settings: {})
  end

  # La primera vez: uno «Formato principal» por omisión.
  def self.ensure_for!(account)
    return if account.quote_formats.exists?

    account.quote_formats.create!(name: I18n.t('quote_formats.default_name'), is_default: true, settings: {})
  end

  # Lo guardado encima de DEFAULTS (los bloques nuevos que no estén se agregan al final, apagados).
  def config
    @config = nil if settings_changed?
    @config ||= begin
      merged = DEFAULTS.deep_merge(settings.to_h.except('blocks'))
      merged['blocks'] = ordered_blocks
      merged
    end
  end

  def block_on?(key) = config['blocks'].any? { |b| b['key'] == key && b['on'] }

  private

  def ordered_blocks
    return DEFAULTS['blocks'].map(&:dup) if settings.to_h['blocks'].blank?

    saved = Quotes::FormatSettings.blocks(settings.to_h['blocks'])
    saved + (BLOCKS - saved.pluck('key')).map { |key| { 'key' => key, 'on' => false } }
  end

  # Solo lo que se conoce, con sus topes.
  def clean_settings
    self.name = name.to_s.squish
    self.settings = Quotes::FormatSettings.clean(settings.to_h)
  end

  def single_default
    account.quote_formats.where.not(id: id).where(is_default: true).update_all(is_default: false) # rubocop:disable Rails/SkipsModelValidations
  end

  def logo_ok
    errors.add(:logo, 'debe ser PNG, JPG o WEBP') unless CatalogItem::IMAGE_TYPES.include?(logo.blob.content_type)
    errors.add(:logo, 'debe pesar menos de 2 MB') if logo.blob.byte_size > 2.megabytes
  end
end
