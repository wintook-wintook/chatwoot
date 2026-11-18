# frozen_string_literal: true

# Probador de agentes — cierra las corridas que dejaron de avanzar (AgentTestRun.close_stale!):
# sin esto, si Sidekiq se caía a media corrida, quedaba «Corriendo…» para siempre y sus
# «Probar de nuevo» en «probando».
class AgentTester::StaleRunsJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    AgentTestRun.close_stale!
  end
end
