# Probador de agentes:
#   agent_test_cases.bad_reply  la respuesta que se marcó con 👎, para que el juez sepa contra qué
#                               compara («antes contestó esto y estaba mal porque…»);
#   agent_test_runs.error       por qué una corrida no terminó (p. ej. se reinició Sidekiq).
class AddBadReplyAndErrorToAgentTester < ActiveRecord::Migration[7.0]
  def change
    add_column :agent_test_cases, :bad_reply, :text
    add_column :agent_test_runs, :error, :string
  end
end
