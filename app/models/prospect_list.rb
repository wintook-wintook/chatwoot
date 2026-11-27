# frozen_string_literal: true

# == Schema Information
#
# Table name: prospect_lists
#
#  id                   :bigint           not null, primary key
#  cleaned_at           :datetime
#  cleanup_days         :integer          default(30), not null
#  name                 :string           not null
#  stats                :jsonb            not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  tracking_campaign_id :bigint
#  uploaded_by_id       :bigint
#
# Indexes
#
#  index_prospect_lists_on_account_id            (account_id)
#  index_prospect_lists_on_tracking_campaign_id  (tracking_campaign_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (tracking_campaign_id => tracking_campaigns.id) ON DELETE => nullify
#
# Una lista fría de correos subida a una Campaña con Vendedor IA (ProspectLists::Import). Sus contactos nuevos
# quedan en cuarentena (contacts.list_quarantine: no salen en Contactos) hasta que contestan o dan clic
# (ProspectLists.promote!); los que nunca contestan se borran cleanup_days después de que termina la campaña
# (ProspectLists::CleanupJob). stats: { rows, valid, created, existing, discarded: { motivo => n }, contact_ids }.
class ProspectList < ApplicationRecord
  belongs_to :account
  belongs_to :tracking_campaign, optional: true
  belongs_to :uploaded_by, class_name: 'User', optional: true
  has_many :contacts, dependent: :nullify

  validates :name, presence: true, length: { maximum: 160 }
  validates :cleanup_days, numericality: { only_integer: true, in: 1..365 }

  def contact_ids = Array(stats.to_h['contact_ids']).map(&:to_i)

  def summary
    s = stats.to_h
    { id: id, name: name, cleanup_days: cleanup_days, cleaned_at: cleaned_at, created_at: created_at,
      rows: s['rows'].to_i, valid: s['valid'].to_i, created: s['created'].to_i, existing: s['existing'].to_i,
      discarded: s['discarded'].to_h, promoted: contacts.where(list_quarantine: false).count,
      quarantined: contacts.where(list_quarantine: true).count, removed: s['removed'].to_i }
  end
end
