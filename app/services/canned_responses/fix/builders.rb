# frozen_string_literal: true

# proyecto@arreglar_predefinidas F2 — qué arma la propuesta de cada tipo de arreglo.
# Regresa [{ proposal:, checks: } | nil, código de error | nil].
module CannedResponses::Fix::Builders
  module_function

  def build(context, api_key: nil, corpus: nil)
    if context.kind == 'oversize'
      builder = CannedResponses::Fix::Builder.new(context.account, api_key: api_key, corpus: corpus)
      return [builder.call(context.target), builder.error_code]
    end

    builder = klass(context.kind).new(context, api_key: api_key, corpus: corpus)
    [builder.call, builder.error_code]
  end

  def klass(kind)
    { 'writing' => CannedResponses::Fix::WritingBuilder, 'merge' => CannedResponses::Fix::MergeBuilder,
      'separate' => CannedResponses::Fix::SeparateBuilder, 'resolve' => CannedResponses::Fix::ResolveBuilder }.fetch(kind)
  end
end
