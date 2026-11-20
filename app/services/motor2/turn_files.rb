# frozen_string_literal: true

# Motor 2.0 — los archivos que van con la respuesta del turno (máximo Motor2::Runner::MAX_FILES; no se
# repiten en el mismo mensaje). Lo incluye Motor2::Runner (usa @config, @attachments y @trace).
module Motor2::TurnFiles
  # Un archivo del agente que va con la respuesta (máximo 5; no se repite en el mismo mensaje).
  def attach(name)
    file = @config.attachments.where('LOWER(name) = ?', name.to_s.downcase).first
    file&.file&.attached? ? attach_blob(file.id, file.name, file.file.blob) : false
  end

  # Cualquier archivo guardado (p. ej. la foto de un producto del Catálogo: Motor2::Skills::Recommend).
  def attach_blob(id, name, blob)
    return true if @attachments.any? { |a| a[:id] == id }
    return false if @attachments.size >= Motor2::Runner::MAX_FILES

    @attachments << { id: id, name: name, signed_id: blob.signed_id }
    @trace.event(:archivo, name)
    true
  end
end
