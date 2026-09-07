# frozen_string_literal: true

# Parámetros de una ejecución de @buscar_predefinidas sin conversación real (ver
# KnowledgeBase::DirectiveRunner). Resuelve los mismos defaults por cuenta
# (KnowledgeBaseResponseService.kbase_setting) que usa el motor conversacional, para
# que un mismo umbral/límite aplique sin importar si la búsqueda vino de una
# conversación real o de esta API.
class KnowledgeBase::Context
  attr_reader :account, :query, :contact_name, :max_results, :similarity_threshold, :compose

  # rubocop:disable Metrics/ParameterLists
  def initialize(account:, query:, contact_name: nil, max_results: nil, similarity_threshold: nil, compose: true)
    @account              = account
    @query                = query.to_s.strip
    @contact_name         = contact_name.presence || 'cliente'
    @max_results          = (max_results.presence || KnowledgeBaseResponseService.kbase_setting(account, 'max_results')).to_i
    @similarity_threshold = (similarity_threshold.presence || KnowledgeBaseResponseService.kbase_setting(account, 'similarity_threshold')).to_f
    @compose              = compose
  end
  # rubocop:enable Metrics/ParameterLists
end
