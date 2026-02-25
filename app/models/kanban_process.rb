# == Schema Information
#
# Table name: kanban_processes
#
#  id                     :bigint           not null, primary key
#  default                :boolean          default(FALSE)
#  is_system              :boolean          default(FALSE)
#  position               :integer          default(0)
#  type_process_name      :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  kanban_type_process_id :bigint           not null
#
# Indexes
#
#  index_kanban_processes_on_account_id                             (account_id)
#  index_kanban_processes_on_account_id_and_default                 (account_id,default)
#  index_kanban_processes_on_account_id_and_is_system               (account_id,is_system)
#  index_kanban_processes_on_account_id_and_kanban_type_process_id  (account_id,kanban_type_process_id)
#  index_kanban_processes_on_kanban_type_process_id                 (kanban_type_process_id)
#  unique_default_kanban_process_per_type                           (kanban_type_process_id) UNIQUE WHERE ("default" = true)
#  unique_position_per_kanban_type                                  (kanban_type_process_id,position) UNIQUE
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

  before_save :ensure_single_default, if: :default_changed?

  private

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
