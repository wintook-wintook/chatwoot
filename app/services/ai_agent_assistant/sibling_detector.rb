# ================================================================================
# proyecto@ai_agent_assistant - F4
# ================================================================================
# Servicio: AiAgentAssistant::SiblingDetector
# Descripción: Detecta las copias «… V2 / V3 / V4» de un mismo Agente IA.
#
# Motivo (§13.4 del plan): en la cuenta 778 hay seis agentes vivos en el mismo
# inbox para un solo caso de uso, sin marca de cuál está asignado y con un error
# que sobrevivió a tres versiones. Con F4 se itera en sitio, así que las copias que
# ya existen se pueden absorber como historial y archivar.
#
# Deliberadamente conservador: solo agrupa por un marcador EXPLÍCITO de versión al
# final del nombre. Un «Recordatorio 2» puede ser el segundo paso de una secuencia,
# no una copia, y proponer archivarlo sería un consejo caro.
# ================================================================================

class AiAgentAssistant::SiblingDetector
  # «… V4», «… v.4», «… ver 4», «… versión 4», con o sin guion antes.
  VERSION_SUFFIX = /\s*[-–—_]?\s*(?:v|ver|versi[oó]n)\s*\.?\s*(\d+)\s*\z/i

  # Nombre sin el sufijo de versión. nil si el nombre no lleva marcador.
  def self.base_name(name)
    return nil unless name.to_s.match?(VERSION_SUFFIX)

    base = name.to_s.sub(VERSION_SUFFIX, '').strip
    base.presence
  end

  def self.version_number(name)
    name.to_s[VERSION_SUFFIX, 1]&.to_i
  end

  # Grupo de hermanos del agente dado, él incluido. [] si no forma parte de ninguno.
  def self.for(template)
    new(template).call
  end

  def initialize(template)
    @template = template
  end

  def call
    return [] if base.blank?

    group = candidates.select { |t| self.class.base_name(t.name) == base }
    return [] if group.size < 2

    group.sort_by { |t| self.class.version_number(t.name) || 0 }
         .map { |t| entry_for(t) }
  end

  private

  attr_reader :template

  def base
    @base ||= self.class.base_name(template.name)
  end

  # Prefiltro en SQL por el nombre base; el match fino lo hace la regex en Ruby
  # («Tickets V4» y «Tickets Verano» comparten prefijo pero no son hermanos).
  def candidates
    template.account.tracking_templates
            .where('name ILIKE ?', "#{ActiveRecord::Base.sanitize_sql_like(base)}%")
            .order(:name)
  end

  # `trackings_count` es el dato que decide: archivar un agente con seguimientos en
  # curso no los rompe (cada seguimiento tiene su propia copia del prompt), pero sí
  # conviene saberlo antes de proponerlo.
  def entry_for(candidate)
    {
      id: candidate.id,
      name: candidate.name,
      version: self.class.version_number(candidate.name),
      inbox_id: candidate.inbox_id,
      archived: candidate.archived?,
      current: candidate.id == template.id,
      updated_at: candidate.updated_at,
      trackings_count: ContactTracking.where(tracking_template_id: candidate.id).count
    }
  end
end
