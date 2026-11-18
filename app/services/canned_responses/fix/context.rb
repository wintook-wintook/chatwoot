# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas F2 — LO QUE CADA TIPO DE ARREGLO TIENE QUE RESPETAR
# ================================================================================
# Un solo lugar que, para un tipo y sus predefinidas de origen, dice:
#
#   reference     el texto contra el que se revisa que no se pierda nada
#                 (oversize: la original limpia; los demás: todas las de origen juntas)
#   target        merge: con cuál se queda (la que tiene categoría, o prefijo de grupo que
#                 usan los agentes; si empatan, la más antigua). La otra se elimina.
#   prefixes      prefijos de grupo que el nombre resultante no puede perder
#   fixed_names   separate / resolve: cada parte conserva el nombre de su original
#   baselines     writing / resolve / separate: el texto de antes de cada parte, para
#                 medir cuánto cambió
#   forbidden / required   resolve: el dato equivocado no puede quedar en ninguna parte y
#                 el correcto tiene que estar (Fix::Resolution)
#
# Lo usan el job que arma la propuesta, «Volver a comprobar» y «Aplicar», así que los
# tres revisan exactamente lo mismo.
# ================================================================================

class CannedResponses::Fix::Context
  attr_reader :account, :kind, :sources, :input

  def self.for(fix) = new(fix.account, kind: fix.kind, sources: fix.sources, input: fix.input)

  def initialize(account, kind:, sources:, input: {})
    @account = account
    @kind = kind
    @sources = sources
    @input = (input || {}).to_h.deep_stringify_keys
  end

  def target
    return @sources.first unless @kind == 'merge'

    @target ||= @sources.min_by do |r|
      [r.kind == 'general' ? 1 : 0, groups.required_prefixes(r.short_code).any? ? 0 : 1, r.created_at || Time.current, r.id.to_i]
    end
  end

  def other = (@sources - [target]).first

  def cleaned_content
    @cleaned_content ||= CannedResponses::Fix::Cleanup.call(target.content)
  end

  # merge: de la que se elimina cuenta el contenido, no el nombre («079 ¿Pueden armar…»:
  # el 079 es un código del nombre, no un dato que se tenga que conservar).
  def reference
    @reference ||= case @kind
                   when 'oversize' then CannedResponse.agent_text(target.short_code, cleaned_content.content)
                   when 'merge' then [target.agent_text, other&.content].compact.join("\n\n")
                   else @sources.map(&:agent_text).join("\n\n")
                   end
  end

  # merge: los del que se queda; si la otra tenía otros, se avisa (lost_groups) pero no
  # se pueden cumplir los dos en un solo nombre.
  def prefixes
    return groups.required_prefixes(target.short_code) if %w[oversize merge writing].include?(@kind)

    []
  end

  def lost_groups
    return [] unless @kind == 'merge' && other

    perdidos = groups.required_prefixes(other.short_code) - groups.required_prefixes(target.short_code)
    perdidos.uniq
  end

  def fixed_names = %w[separate resolve].include?(@kind) ? @sources.map(&:short_code) : nil

  def baselines = %w[writing separate resolve].include?(@kind) ? @sources.map(&:agent_text) : nil

  def resolution
    @resolution ||= CannedResponses::Fix::Resolution.new(@input['contradictions'], @input['choices']) if @kind == 'resolve'
  end

  def digests = @sources.to_h { |r| [r.id.to_s, CannedResponseFix.digest_for(r)] }

  def checks(api_key: nil, corpus: nil)
    CannedResponses::Fix::Checks.new(
      @account, originals: @sources, reference_text: reference, prefixes: prefixes, api_key: api_key, corpus: corpus,
                forbidden: resolution&.forbidden || [], required: resolution&.required || [],
                baselines: baselines, compare_pair: @kind == 'separate',
                measure_changes: %w[writing resolve].include?(@kind), coverage_blocks: @kind == 'separate'
    )
  end

  def groups = @groups ||= CannedResponses::Fix::Groups.new(@account)
end
