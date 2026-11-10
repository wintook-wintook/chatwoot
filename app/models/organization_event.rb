# == Schema Information
#
# Table name: organization_events
#
#  id              :bigint           not null, primary key
#  action          :string           not null
#  data            :jsonb            not null
#  created_at      :datetime         not null
#  organization_id :bigint           not null
#  user_id         :bigint
#
# Indexes
#
#  index_organization_events_on_organization_id  (organization_id)
#  index_organization_events_on_user_id          (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (organization_id => organizations.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
# Plan-Organizaciones O1 — bitácora: quién cambió la etapa de la organización y cuándo.
class OrganizationEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :user, optional: true

  validates :action, presence: true
end
