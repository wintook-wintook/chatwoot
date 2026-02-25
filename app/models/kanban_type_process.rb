# == Schema Information
#
# Table name: kanban_type_processes
#
#  id           :bigint           not null, primary key
#  default      :boolean          default(FALSE)
#  is_system    :boolean          default(FALSE)
#  process_name :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
# Indexes
#
#  index_kanban_type_processes_on_account_id                   (account_id)
#  index_kanban_type_processes_on_account_id_and_default       (account_id,default)
#  index_kanban_type_processes_on_account_id_and_is_system     (account_id,is_system)
#  index_kanban_type_processes_on_account_id_and_process_name  (account_id,process_name) UNIQUE
#  unique_default_kanban_type_process_per_account              (account_id) UNIQUE WHERE ("default" = true)
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

  validates :process_name, presence: true, uniqueness: { scope: :account_id }
  validates :account_id, presence: true
  
  scope :default_processes, -> { where(default: true) }
  scope :system_processes, -> { where(is_system: true) }
  scope :custom_processes, -> { where(is_system: false) }

  before_save :ensure_single_default, if: :default_changed?

  private

  def ensure_single_default
    return unless default?
    
    KanbanTypeProcess.where(account: account, default: true)
                     .where.not(id: id)
                     .update_all(default: false)
  end
end
