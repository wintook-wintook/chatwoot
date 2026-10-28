# CrmZeus O0 — lo común de los catálogos de organizaciones: nombre limpio y único
# (sin distinguir mayúsculas, como CRMZeus) y un solo «predeterminado».
#
#   crm_catalog_entry unique_within: %i[account_id kind], default_within: %i[account_id kind]
module CrmCatalogEntry
  extend ActiveSupport::Concern

  class_methods do
    def crm_catalog_entry(unique_within: [:account_id], default_within: [:account_id])
      belongs_to :account

      before_validation { self.name = name.to_s.squish }
      validates :name, presence: true
      validates :name, uniqueness: { scope: unique_within, case_sensitive: false }

      define_method(:default_within) { default_within }
      after_save :clear_other_defaults, if: -> { has_attribute?(:is_default) && is_default? && saved_change_to_is_default? }
    end
  end

  private

  def clear_other_defaults
    others = self.class.where(default_within.index_with { |col| self[col] }).where.not(id: id)
    others.where(is_default: true).update_all(is_default: false, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
