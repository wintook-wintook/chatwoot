# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas — APLICAR UNA PROPUESTA (con lo que la persona editó)
# ================================================================================
#   oversize  split          se crean las partes y se elimina la original
#             clean/condense la original se queda (mismo id) con el texto nuevo
#             mark_prompt    igual, marcada «El mensaje es el prompt»; en varias partes,
#                            como split pero todas marcadas
#   writing   la original se queda (mismo id) con el texto corregido
#   merge     la que se conserva (Context#target) toma la primera parte; las demás partes
#             se crean; la otra se elimina
#   separate / resolve   cada original se queda (mismo id) con su parte; el nombre no cambia
#
# Antes de guardar se vuelven a correr los candados que bloquean sobre lo que llegó (la
# persona pudo editar). `force` solo deja pasar los de Checks::FORCEABLE.
#
# Snapshot: cómo estaban las de origen, para «Deshacer» (Fix::Undo). result guarda qué se
# creó, cambió y borró, y la huella con que quedó cada una (si alguien la edita después,
# deshacer avisa en vez de pisar el cambio).
#
# Lo nuevo hereda de su original lo que no es texto: categoría, prompt propio y si el
# mensaje es prompt. Las opciones del bot viejo (menú, opción) NO: duplicarían la entrada
# del menú. Al guardarse, cada una se vectoriza y se audita sola, y los hallazgos que
# tenían las originales se borran (CannedResponse#sync_knowledge_embedding).
# ================================================================================

class CannedResponses::Fix::Applier
  class Blocked < StandardError
    attr_reader :checks

    def initialize(checks)
      @checks = checks
      super('blocked')
    end
  end

  class Stale < StandardError; end

  SNAPSHOT_FIELDS = %w[id short_code content content_prompts content_is_prompt category_id menu opcion content_full
                       url_content url_short_code created_at].freeze

  def initialize(fix)
    @fix = fix
    @context = CannedResponses::Fix::Context.for(fix)
  end

  def call(parts:, force: false)
    raise Stale if @fix.status != 'proposed' || @fix.stale_source?
    # La IA desaconsejó separarlas: no hay nada que aplicar.
    raise Blocked, @fix.checks.merge('blocking' => ['not_advised']) if @fix.proposal['not_advised']

    parts = normalize(parts)
    revision = @context.checks.call(parts, [], embeddings: false)
    bloquean = revision['blocking'] - (force ? CannedResponses::Fix::Checks::FORCEABLE : [])
    raise Blocked, revision if bloquean.any? || parts.empty?

    CannedResponse.transaction do
      foto = @context.sources.map { |r| r.attributes.slice(*SNAPSHOT_FIELDS) }
      salida = apply(parts)
      @fix.update!(status: 'applied', snapshot: foto, result: salida.merge('applied_digests' => digests(salida)),
                   checks: @fix.checks.merge(revision.except('blocking')))
      salida
    end
  end

  private

  # separate / resolve: el nombre es el de cada original, aunque llegue otro.
  def normalize(parts)
    limpias = parts.map { |p| { 'short_code' => p['short_code'].to_s.strip, 'content' => p['content'].to_s.strip } }
    nombres = @context.fixed_names
    return limpias unless nombres

    limpias.first(nombres.size).each_with_index.map { |p, i| p.merge('short_code' => nombres[i]) }
  end

  def apply(parts)
    case @fix.kind
    when 'oversize' then apply_oversize(parts)
    when 'merge' then apply_merge(parts)
    when 'separate', 'resolve' then update_each(parts)
    else update(@context.target, parts.first)
    end
  end

  def apply_oversize(parts)
    accion = @fix.proposal['action']
    original = @context.target
    return split(original, parts, prompt: accion == 'mark_prompt') if accion == 'split' || parts.size > 1
    return update(original, parts.first, content_is_prompt: true) if accion == 'mark_prompt'

    update(original, parts.first)
  end

  def split(original, parts, prompt: false)
    heredado = inherited_attrs(original).merge(content_is_prompt: prompt || original.content_is_prompt)
    id_original = original.id
    original.destroy!
    nuevas = parts.map { |p| create(heredado, p) }
    { 'created_ids' => nuevas.map(&:id), 'deleted_ids' => [id_original], 'updated_ids' => [] }
  end

  # La otra se borra primero: así la parte que se conserva puede tomar cualquier nombre.
  def apply_merge(parts)
    target = @context.target
    otra = @context.other
    borrada = otra&.id
    otra&.destroy!
    target.update!(short_code: parts.first['short_code'], content: parts.first['content'])
    nuevas = parts.drop(1).map { |p| create(inherited_attrs(target), p) }
    { 'created_ids' => nuevas.map(&:id), 'deleted_ids' => [borrada].compact, 'updated_ids' => [target.id] }
  end

  def update_each(parts)
    @context.sources.zip(parts).each { |r, p| r.update!(content: p['content']) if p }
    { 'created_ids' => [], 'deleted_ids' => [], 'updated_ids' => @context.sources.map(&:id) }
  end

  def update(original, part, extra = {})
    original.update!({ short_code: part['short_code'], content: part['content'] }.merge(extra))
    { 'created_ids' => [], 'deleted_ids' => [], 'updated_ids' => [original.id] }
  end

  def inherited_attrs(original)
    { category_id: original.category_id, content_prompts: original.content_prompts,
      content_is_prompt: original.content_is_prompt }
  end

  def create(heredado, part)
    @fix.account.canned_responses.create!(heredado.merge(short_code: part['short_code'], content: part['content']))
  end

  def digests(salida)
    ids = salida['created_ids'] + salida['updated_ids']
    @fix.account.canned_responses.where(id: ids).to_h { |r| [r.id.to_s, CannedResponseFix.digest_for(r)] }
  end
end
