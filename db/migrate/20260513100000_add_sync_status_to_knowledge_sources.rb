# @knowledge_sources
class AddSyncStatusToKnowledgeSources < ActiveRecord::Migration[6.1]
  def change
    add_column :knowledge_sources, :sync_status, :string, default: 'idle', null: false
    add_column :knowledge_sources, :sync_jobs_pending, :integer, default: 0, null: false
  end
end
