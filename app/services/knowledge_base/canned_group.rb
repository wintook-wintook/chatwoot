# frozen_string_literal: true

# ================================================================================
# proyecto@contact_tracking — ALCANCE DE @buscar_predefinidas(GRUPO)
# ================================================================================
# Qué items mira una búsqueda y con qué umbral, cuando la directiva acota un grupo.
#
# La regla original vive en KnowledgeBaseResponseService (#grouped_items /
# #group_threshold), que solo se puede usar con un mensaje y una conversación reales.
# La prueba en seco del Asistente (ContactTrackings::Assistant::DryRunService) tiene
# que buscar EXACTO igual que el motor pero sin conversación, así que necesita estas
# mismas reglas por fuera.
#
# ⚠ HAY DOS COPIAS A PROPÓSITO — y por eso están amarradas por un spec.
#   El motor de producción NO delega acá: se decidió no tocar ese archivo por una
#   pantalla nueva. El riesgo de eso es conocido y documentado en el encabezado de
#   KnowledgeBase::Directives: esa cadena estuvo duplicada, divergió, y el arreglo
#   hubo que hacerlo en cuatro sitios a la vez.
#
#   Acá divergir sería peor: la prueba en seco existe para decirle a alguien qué va a
#   hacer el motor, así que una copia desfasada no falla — miente, y con cara de
#   autoridad. Para que no pase en silencio,
#   spec/services/knowledge_base/canned_group_spec.rb corre ESTE módulo y el método
#   privado del servicio real sobre los mismos datos y exige el mismo resultado.
#   Si alguien cambia uno solo de los dos, el spec se pone rojo.
#
# El umbral sigue definido en KnowledgeBaseResponseService, donde está el comentario
# con la medición que lo justifica. Referenciarlo desde acá es el mismo camino que ya
# hace KnowledgeBase::Context con kbase_setting.
# ================================================================================

module KnowledgeBase::CannedGroup
  module_function

  # El grupo es un PREFIJO del nombre de la respuesta predefinida (su short_code, que
  # es lo que se vectoriza como título). Con `!` delante, el grupo se excluye.
  def scope(account, source_type, group)
    scope = account.knowledge_items.where(source_type: source_type)
    return scope if group.blank?

    negated = group.start_with?('!')
    name    = group.delete_prefix('!').strip
    return scope if name.blank?

    pattern = "#{ActiveRecord::Base.sanitize_sql_like(name)}%"

    # title IS NULL en la rama negada: un NOT ILIKE contra NULL da NULL y descartaría
    # el item en silencio.
    negated ? scope.where('title IS NULL OR title NOT ILIKE ?', pattern) : scope.where('title ILIKE ?', pattern)
  end

  # Solo el grupo positivo sube el listón. El negado (!GESTION) sigue siendo el corpus
  # general con un recorte, no un corpus estrecho, así que conserva el umbral de siempre.
  def threshold(group)
    return nil if group.blank? || group.start_with?('!')

    KnowledgeBaseResponseService::GROUP_SIMILARITY_THRESHOLD
  end
end
