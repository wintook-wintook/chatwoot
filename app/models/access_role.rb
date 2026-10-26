# == Schema Information
#
# Table name: access_roles
#
#  id         :bigint           not null, primary key
#  actions    :jsonb            not null
#  areas      :jsonb            not null
#  key        :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_access_roles_on_account_id          (account_id)
#  index_access_roles_on_account_id_and_key  (account_id,key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# Plan-Roles-Permisos — rol de una cuenta: a qué áreas entra cada agente, si ve
# solo lo suyo o todo, y qué acciones puede hacer.
#
# Las 4 plantillas (DEFAULTS) se crean solas la primera vez que se piden
# (`for_account`); cada empresa las edita directo y puede «Restaurar como
# venía» (`restore!`). El Administrador NO es un AccessRole: es fijo.
class AccessRole < ApplicationRecord
  AREAS = %w[conversations agenda sales service clients campaigns ai_agents reports settings].freeze
  # none: no entra · own: solo lo suyo · view: ve todo sin cambiar nada · all: todo
  LEVELS = %w[none own view all].freeze
  # «Solo lo suyo» solo existe donde las cosas tienen dueño; Ajustes es del Administrador.
  AREA_LEVELS = AREAS.index_with { LEVELS }.merge(
    'campaigns' => %w[none view all], 'ai_agents' => %w[none view all], 'reports' => %w[none view all],
    'settings' => %w[none]
  ).freeze
  ACTIONS = %w[reassign take_unassigned delete export see_amounts].freeze
  KEYS = %w[supervisor seller technician viewer].freeze
  DEFAULT_KEY = 'supervisor'.freeze

  DEFAULTS = {
    'supervisor' => {
      areas: { conversations: 'all', agenda: 'all', sales: 'all', service: 'all', clients: 'all',
               campaigns: 'view', ai_agents: 'view', reports: 'all', settings: 'none' },
      actions: { reassign: true, take_unassigned: true, delete: false, export: true, see_amounts: true }
    },
    'seller' => {
      areas: { conversations: 'own', agenda: 'own', sales: 'own', service: 'none', clients: 'own',
               campaigns: 'none', ai_agents: 'none', reports: 'none', settings: 'none' },
      actions: { reassign: false, take_unassigned: true, delete: false, export: false, see_amounts: true }
    },
    'technician' => {
      areas: { conversations: 'own', agenda: 'own', sales: 'none', service: 'own', clients: 'own',
               campaigns: 'none', ai_agents: 'none', reports: 'none', settings: 'none' },
      actions: { reassign: false, take_unassigned: true, delete: false, export: false, see_amounts: false }
    },
    'viewer' => {
      areas: { conversations: 'none', agenda: 'none', sales: 'none', service: 'none', clients: 'none',
               campaigns: 'none', ai_agents: 'none', reports: 'view', settings: 'none' },
      actions: { reassign: false, take_unassigned: false, delete: false, export: true, see_amounts: true }
    }
  }.deep_stringify_keys.freeze

  belongs_to :account
  has_many :account_users, dependent: :nullify

  validates :key, inclusion: { in: KEYS }, uniqueness: { scope: :account_id }
  validate :valid_areas_and_actions

  # Los 4 roles de la cuenta, creándolos si faltan.
  def self.for_account(account)
    existing = account.access_roles.to_a
    missing = KEYS - existing.map(&:key)
    missing.each { |key| existing << account.access_roles.create!(key: key, **DEFAULTS[key].symbolize_keys) }
    existing.sort_by { |role| KEYS.index(role.key) }
  rescue ActiveRecord::RecordNotUnique
    account.access_roles.reload.sort_by { |role| KEYS.index(role.key) }
  end

  def self.default_for(account)
    for_account(account).find { |role| role.key == DEFAULT_KEY }
  end

  def restore!
    update!(DEFAULTS[key])
  end

  # Lo que falte (un área nueva que todavía no estaba guardada) sale de la plantilla.
  def area_level(area)
    areas[area.to_s].presence || DEFAULTS.dig(key, 'areas', area.to_s) || 'none'
  end

  def action?(action)
    value = actions.key?(action.to_s) ? actions[action.to_s] : DEFAULTS.dig(key, 'actions', action.to_s)
    ActiveModel::Type::Boolean.new.cast(value) || false
  end

  private

  def valid_areas_and_actions
    errors.add(:areas, 'tiene un área desconocida') unless (areas.keys - AREAS).empty?
    errors.add(:areas, 'tiene un nivel que esa área no admite') unless areas.all? { |area, level| AREA_LEVELS[area]&.include?(level) }
    errors.add(:actions, 'tiene una acción desconocida') unless (actions.keys - ACTIONS).empty?
  end
end
