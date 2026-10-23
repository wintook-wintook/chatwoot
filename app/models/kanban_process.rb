# == Schema Information
#
# Table name: kanban_processes
#
#  id                     :bigint           not null, primary key
#  ai_criteria            :text
#  default                :boolean          default(FALSE)
#  entry_triggers         :jsonb            not null
#  is_system              :boolean          default(FALSE)
#  position               :integer          default(0)
#  stage_kind             :integer          default(0), not null
#  type_process_name      :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  convert_case_type_id   :bigint
#  kanban_type_process_id :bigint           not null
#
# Indexes
#
#  index_kanban_processes_on_account_id              (account_id)
#  index_kanban_processes_on_kanban_type_process_id  (kanban_type_process_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_type_process_id => kanban_type_processes.id)
#

# KANBAN0725-MODEL
class KanbanProcess < ApplicationRecord
  belongs_to :account
  belongs_to :kanban_type_process
  has_many :conversations, dependent: :nullify

  validates :type_process_name, presence: true
  validates :kanban_type_process_id, presence: true
  validates :account_id, presence: true
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  # Validar que el kanban_type_process pertenezca a la misma cuenta
  validate :kanban_type_process_belongs_to_account

  scope :default_processes, -> { where(default: true) }
  scope :system_processes, -> { where(is_system: true) }
  scope :custom_processes, -> { where(is_system: false) }
  scope :by_position, -> { order(:position) }

  # Embudo de contactos — qué es la columna y qué hace que una conversación entre
  # sola (solo si el tablero tiene «Movimiento automático»). Ver Kanban::FunnelMover.
  TRIGGER_TYPES = %w[conversation_created first_reply label_added appointment_scheduled case_created
                     conversation_resolved].freeze
  enum stage_kind: { open: 0, converted: 1, discarded: 2 }, _prefix: :stage
  belongs_to :convert_case_type, class_name: 'CaseType', optional: true
  validate :entry_triggers_shape

  # ¿Este hecho mete la conversación a esta columna?
  def triggered_by?(type, labels: [], case_class: nil)
    Array(entry_triggers).any? do |trigger|
      next false unless trigger['type'] == type.to_s

      case type.to_s
      when 'label_added' then Array(trigger['labels']).map(&:to_s).intersect?(Array(labels).map(&:to_s))
      when 'case_created' then trigger['case_class'].blank? || trigger['case_class'] == 'any' || trigger['case_class'] == case_class.to_s
      else true
      end
    end
  end

  before_save :ensure_single_default, if: :default_changed?

  private

  def entry_triggers_shape
    return errors.add(:entry_triggers, 'must be a list') unless entry_triggers.is_a?(Array)

    bad = entry_triggers.reject { |t| t.is_a?(Hash) && TRIGGER_TYPES.include?(t['type'].to_s) }
    errors.add(:entry_triggers, 'has an unknown trigger') if bad.any?
  end

  def kanban_type_process_belongs_to_account
    return unless kanban_type_process && account
    
    unless kanban_type_process.account_id == account_id
      errors.add(:kanban_type_process, 'must belong to the same account')
    end
  end

  def ensure_single_default
    return unless default?
    
    KanbanProcess.where(kanban_type_process: kanban_type_process, default: true)
                 .where.not(id: id)
                 .update_all(default: false)
  end
end
