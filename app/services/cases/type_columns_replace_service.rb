# frozen_string_literal: true

# ================================================================================
# @tickets_cases — Columnas del Kanban por Tipo de Caso (Opción A+)
# ================================================================================
# Servicio: Cases::TypeColumnsReplaceService
#
# Reemplaza EL SET COMPLETO de columnas de un tipo, en una sola transacción.
# Se guarda el set entero (no columna por columna) por dos razones:
#   1. La cobertura de los 13 estados es una propiedad del CONJUNTO, no de una
#      columna suelta → solo se puede validar con el set completo delante.
#   2. Guardar de a una obligaría a pasar por estados intermedios inválidos
#      (p. ej. dos columnas sobre el mismo estado a mitad de la reordenación).
#
# Tras guardar, limpia los punteros (case_type_column_id) que quedaron fuera del
# invariante — el 4º caso límite del §7 que el hook del ticket NO ve, porque el
# que cambió fue la columna, no el ticket.
# ================================================================================

class Cases::TypeColumnsReplaceService
  Result = Struct.new(:success?, :columns, :errors, keyword_init: true)

  def initialize(case_type:, columns_params:)
    @case_type = case_type
    @account   = case_type.account
    # Array de hashes { id?, label, color, position, statuses: [] }. Se normaliza a
    # acceso indiferente para aceptar tanto params del controller como símbolos.
    @params    = Array(columns_params).map { |c| c.respond_to?(:to_unsafe_h) ? c.to_unsafe_h : c }
                                      .map(&:with_indifferent_access)
  end

  def call
    coverage_error = missing_coverage
    return failure([coverage_error]) if coverage_error

    ActiveRecord::Base.transaction do
      @columns = upsert_columns
      delete_removed_columns
      nullify_orphaned_pointers
    end

    Result.new(success?: true, columns: @case_type.case_type_columns.ordered, errors: [])
  rescue ActiveRecord::RecordInvalid => e
    failure(e.record.errors.full_messages)
  end

  private

  # Cobertura total: cada uno de los 13 estados debe caer en al menos una columna.
  # Sin esto, un ticket con puntero NULL en un estado no cubierto no se pinta en
  # ninguna columna (queda invisible en el tablero).
  def missing_coverage
    covered = @params.flat_map { |c| Array(c[:statuses]) }.map(&:to_s).uniq
    missing = CaseTicket.statuses.keys - covered
    return nil if missing.empty?

    "Faltan estados por cubrir: #{missing.join(', ')}"
  end

  # Crea/actualiza las columnas del payload; devuelve las que sobreviven.
  def upsert_columns
    @params.each_with_index.map do |raw, index|
      column = raw[:id].present? ? @case_type.case_type_columns.find(raw[:id]) : @case_type.case_type_columns.new
      column.account = @account
      column.assign_attributes(
        label: raw[:label],
        color: raw[:color],
        position: raw[:position] || index,
        statuses: raw[:statuses] || []
      )
      column.save!
      column
    end
  end

  # Borra las columnas del tipo que ya no vienen en el payload (los tickets que
  # apuntaban a ellas caen a NULL vía FK on_delete: :nullify).
  def delete_removed_columns
    kept_ids = @columns.map(&:id)
    @case_type.case_type_columns.where.not(id: kept_ids).destroy_all
  end

  # Limpia punteros que dejaron de cumplir el invariante porque la columna cambió
  # sus `statuses` (el ticket no cambió, así que su hook nunca se disparó).
  def nullify_orphaned_pointers
    @columns.each do |col|
      # rubocop:disable Rails/SkipsModelValidations
      col.case_tickets.where.not(status: col.statuses).update_all(case_type_column_id: nil)
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  def failure(errors)
    Result.new(success?: false, columns: [], errors: errors)
  end
end
