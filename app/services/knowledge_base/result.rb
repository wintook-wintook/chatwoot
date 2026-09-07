# frozen_string_literal: true

# Salida de KnowledgeBase::DirectiveRunner. `reason` solo se puebla cuando
# resolved? es false, y documenta por qué para que quien llama (la action del
# controller, o Daiko del otro lado de la API) pueda decidir sin adivinar:
# :no_directive, :embedding_failed, :no_match, :llm_empty.
class KnowledgeBase::Result
  attr_reader :threshold, :model, :items, :reply, :source, :reason

  # rubocop:disable Metrics/ParameterLists
  def initialize(resolved:, threshold:, model:, items: [], reply: nil, source: nil, reason: nil)
    @resolved  = resolved
    @threshold = threshold
    @model     = model
    @items     = items
    @reply     = reply
    @source    = source
    @reason    = reason
  end
  # rubocop:enable Metrics/ParameterLists

  def resolved?
    @resolved
  end
end
