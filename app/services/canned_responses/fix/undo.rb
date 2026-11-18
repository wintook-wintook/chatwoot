# frozen_string_literal: true

# ================================================================================
# proyecto@arreglar_predefinidas F2 — «DESHACER» UN ARREGLO APLICADO
# ================================================================================
# Unir y dividir borran predefinidas: sin esto no hay vuelta atrás. Durante
# CannedResponseFix::UNDO_DAYS se puede regresar todo a como estaba (snapshot):
#   · lo que el arreglo creó se elimina;
#   · lo que cambió vuelve a su texto, nombre y categoría de antes;
#   · lo que borró se vuelve a crear con su mismo id (si sigue libre).
#
# Si alguien editó después lo que dejó el arreglo, no se pisa en silencio: Conflict con
# los nombres, y solo con force se deshace igual.
# Lo restaurado se vuelve a vectorizar y a auditar solo.
# ================================================================================

class CannedResponses::Fix::Undo
  class NotUndoable < StandardError; end

  class Conflict < StandardError
    attr_reader :names

    def initialize(names)
      @names = names
      super('conflict')
    end
  end

  RESTORE_FIELDS = %w[short_code content content_prompts content_is_prompt category_id menu opcion content_full
                      url_content url_short_code].freeze

  def initialize(fix)
    @fix = fix
    @account = fix.account
  end

  def call(force: false)
    raise NotUndoable unless @fix.undoable?

    cambiadas = edited_since
    raise Conflict, cambiadas.map(&:short_code) if cambiadas.any? && !force

    CannedResponse.transaction do
      @account.canned_responses.where(id: Array(@fix.result['created_ids'])).find_each(&:destroy!)
      @fix.snapshot.each { |foto| restore(foto) }
      @fix.update!(status: 'undone', undone_at: Time.current)
    end
  end

  private

  # Las que dejó el arreglo y que alguien cambió después.
  def edited_since
    huellas = @fix.result['applied_digests'] || {}
    @account.canned_responses.where(id: huellas.keys.map(&:to_i)).reject do |r|
      huellas[r.id.to_s] == CannedResponseFix.digest_for(r)
    end
  end

  def restore(foto)
    datos = foto.slice(*RESTORE_FIELDS).select { |k, _| CannedResponse.column_names.include?(k) }
    existente = @account.canned_responses.find_by(id: foto['id'])
    return existente.update!(datos) if existente

    libre = !CannedResponse.exists?(id: foto['id'])
    @account.canned_responses.create!(datos.merge(libre ? { 'id' => foto['id'] } : {}))
  end
end
