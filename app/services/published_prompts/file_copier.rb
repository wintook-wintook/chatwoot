# frozen_string_literal: true

# ================================================================================
# proyecto@publicar_prompts (F6) — COPIAR UN ARCHIVO ADJUNTO A OTRO REGISTRO
# ================================================================================
# Al publicar (AiAgentAttachment → PublishedPromptFile) y al bajar (PublishedPromptFile
# → AiAgentAttachment del agente nuevo) el archivo se COPIA, no se comparte el blob:
# así borrar el archivo en un lado nunca deja sin archivo al otro, y cada cuenta es
# dueña de lo suyo. Los archivos de un agente son pocos y chicos (catálogos, imágenes).
# ================================================================================

module PublishedPrompts::FileCopier
  module_function

  # source: un ActiveStorage::Attached::One con archivo; target: el Attached::One destino.
  # Se sube YA (create_and_upload!) y luego se adjunta el blob: con attach(io:) en un
  # registro nuevo, Rails sube el archivo recién al confirmar la transacción, y el que
  # venga detrás (bajar justo después de publicar) no lo encontraría.
  def copy(source, target)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(source.download), filename: source.filename.to_s, content_type: source.content_type
    )
    target.attach(blob)
  end
end
