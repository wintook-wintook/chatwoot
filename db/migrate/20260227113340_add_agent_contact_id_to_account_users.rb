# ================================================================================
# proyecto@user_contact
# ================================================================================
class AddAgentContactIdToAccountUsers < ActiveRecord::Migration[7.0]
  def change
    add_reference :account_users, :agent_contact,
                  foreign_key: { to_table: :contacts },
                  null: true,
                  index: true
  end
end
