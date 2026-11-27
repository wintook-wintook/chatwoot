# == Schema Information
#
# Table name: catalog_categories
#
#  id         :bigint           not null, primary key
#  active     :boolean          default(TRUE), not null
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#  parent_id  :bigint
#
# Indexes
#
#  index_catalog_categories_on_account_id  (account_id)
#  index_catalog_categories_on_parent_id   (parent_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (parent_id => catalog_categories.id)
#

# Productos y servicios › Parámetros — una categoría del catálogo, con subcategorías de un nivel
# («Refacciones › Frenos»). El producto guarda su categoría y, como copia, el texto completo en
# catalog_items.category (lo que leen cotizaciones, agentes y el CSV). No se borra si tiene productos o
# subcategorías: se desactiva (ya no se ofrece al elegir, pero quien la tiene la conserva).
class CatalogCategory < ApplicationRecord
  SEPARATOR = ' › '.freeze

  belongs_to :account
  belongs_to :parent, class_name: 'CatalogCategory', optional: true
  has_many :children, class_name: 'CatalogCategory', foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :catalog_items, dependent: :restrict_with_error

  before_validation { self.name = name.to_s.squish }
  validates :name, presence: true, length: { maximum: 80 }
  validate :name_unique
  validate :one_level
  after_update :sync_items, if: -> { saved_change_to_name? || saved_change_to_parent_id? }

  scope :ordered, -> { order(Arel.sql('LOWER(name)')) }

  def path = [parent&.name, name].compact.join(SEPARATOR)

  def in_use? = catalog_items.exists? || children.exists?

  # Ella y sus subcategorías (para filtrar el catálogo).
  def self_and_child_ids = [id, *children.ids]

  private

  def name_unique
    same = account&.catalog_categories&.where(parent_id: parent_id)&.where('LOWER(name) = ?', name.downcase)
    same = same.where.not(id: id) if persisted?
    errors.add(:name, :taken) if same&.exists?
  end

  def one_level
    errors.add(:parent, 'no puede ser una subcategoría') if parent&.parent_id.present? || (parent && children.exists?)
    errors.add(:parent, 'no puede ser ella misma') if parent_id.present? && parent_id == id
  end

  # El texto que copian los productos: el suyo y el de sus subcategorías.
  def sync_items
    [self, *children].each do |category|
      category.catalog_items.update_all(category: category.path, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
