# frozen_string_literal: true

# == Schema Information
#
# Table name: agent_test_logs
#
#  id                   :bigint           not null, primary key
#  diagnosis            :jsonb            not null
#  engine               :string           not null
#  feedback             :text
#  kind                 :string           not null
#  reply                :text
#  retest               :jsonb            not null
#  status               :string           default("pending"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  account_id           :bigint           not null
#  agent_test_case_id   :bigint
#  conversation_id      :bigint
#  message_id           :bigint
#  motor2_report_id     :bigint
#  tracking_template_id :bigint
#  user_id              :bigint
#
# Indexes
#
#  index_agent_test_logs_on_account_id                 (account_id)
#  index_agent_test_logs_on_account_id_and_created_at  (account_id,created_at)
#  index_agent_test_logs_on_tracking_template_id       (tracking_template_id)
#  index_agent_test_logs_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (tracking_template_id => tracking_templates.id)
#  fk_rails_...  (user_id => users.id)
#
class AgentTestLog < ApplicationRecord
  KINDS = %w[prompt content search category model engine question].freeze
  # Seguimiento de cada 👎: pendiente → «Ya lo corregí» corre su prueba otra vez → quedó / sigue fallando.
  STATUSES = %w[pending retesting passed failing].freeze

  belongs_to :account
  belongs_to :tracking_template, optional: true
  belongs_to :user, optional: true
  belongs_to :agent_test_case, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :engine, inclusion: { in: %w[1 2] }
  validates :status, inclusion: { in: STATUSES }

  # Al terminar la corrida de «Probar de nuevo»: quedó o sigue fallando, con lo que contestó.
  def self.finish_retests(run)
    where(account_id: run.account_id).where("retest ->> 'run_id' = ?", run.id.to_s).find_each do |log|
      result = Array(run.results).find { |r| r['case_id'].to_i == log.agent_test_case_id }
      ok = run.status == 'done' && result && result['ok']
      log.update!(status: ok ? 'passed' : 'failing',
                  retest: log.retest.merge('reply' => result&.dig('reply').to_s, 'at' => Time.current,
                                           'reason' => result&.dig('reason').presence || 'No se pudo correr la prueba.'))
    end
  end
end
