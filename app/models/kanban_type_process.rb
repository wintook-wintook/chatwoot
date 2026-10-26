# == Schema Information
#
# Table name: kanban_type_processes
#
#  id                 :bigint           not null, primary key
#  ai_move            :boolean          default(FALSE), not null
#  auto_move          :boolean          default(FALSE), not null
#  cold_after_days    :integer
#  default            :boolean          default(FALSE)
#  discard_after_days :integer
#  entry_inbox_ids    :jsonb            not null
#  is_system          :boolean          default(FALSE)
#  process_name       :string           not null
#  created_at         :datetime
#  updated_at         :datetime
#  account_id         :bigint           not null
#
# Indexes
#
#  index_kanban_type_processes_on_account_id       (account_id)
#  unique_default_kanban_type_process_per_account  (account_id) UNIQUE WHERE ("default" = true)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

# KANBAN0725-MODEL
class KanbanTypeProcess < ApplicationRecord
  belongs_to :account
  has_many :kanban_processes, dependent: :destroy
  has_many :conversations, dependent: :nullify
  has_many :kanban_moves, dependent: :delete_all

  validates :process_name, presence: true, uniqueness: { scope: :account_id }
  validates :account_id, presence: true
  
  scope :default_processes, -> { where(default: true) }
  scope :system_processes, -> { where(is_system: true) }
  scope :custom_processes, -> { where(is_system: false) }

  before_save :ensure_single_default, if: :default_changed?

  # Embudo de contactos — columna por la que entra una conversación nueva: la que
  # tiene el disparador «conversación nueva», si no la predeterminada, si no la primera.
  def entry_column
    columns = kanban_processes.by_position.to_a
    columns.detect { |c| c.triggered_by?(:conversation_created) } || columns.detect(&:default?) || columns.first
  end

  def entry_inbox?(inbox_id)
    Array(entry_inbox_ids).map(&:to_i).include?(inbox_id.to_i)
  end

  private

  def ensure_single_default
    return unless default?
    
    KanbanTypeProcess.where(account: account, default: true)
                     .where.not(id: id)
                     .update_all(default: false)
  end
end
