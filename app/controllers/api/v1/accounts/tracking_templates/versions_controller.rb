# ================================================================================
# proyecto@ai_agent_assistant - F4
# ================================================================================
# Controlador: TrackingTemplates::VersionsController
# Descripción: Historial en sitio de un Agente IA (anidado bajo tracking_templates,
#   account-scoped). Cada guardado que cambia el comportamiento deja un snapshot;
#   aquí se listan, se comparan y se restauran.
# Acciones: index (metadatos + qué campos cambió cada versión),
#           show (snapshot + diff contra la anterior o contra ?compare_with=),
#           restore (aplica el snapshot al agente vivo, dejando una versión nueva)
# ================================================================================

class Api::V1::Accounts::TrackingTemplates::VersionsController < Api::V1::Accounts::BaseController
  before_action :fetch_tracking_template
  before_action :fetch_version, only: [:show, :restore]

  def index
    versions = @tracking_template.versions.includes(:user).ordered.to_a
    render json: { versions: versions.map { |v| version_json(v, previous_of(versions, v)) } }
  end

  def show
    render json: version_json(@version, comparison_base).merge(
      snapshot: @version.snapshot,
      diff: AiAgentAssistant::VersionDiff.between(comparison_base&.snapshot, @version.snapshot)
    )
  end

  # Restaurar no borra historial: aplica el snapshot y el `after_save` del modelo deja
  # una versión nueva con `source: restore`. Se avanza hacia adelante, nunca hacia atrás.
  def restore
    @tracking_template.assign_attributes(restorable_attributes)
    @tracking_template.version_source = 'restore'
    @tracking_template.version_note = params[:note].presence || "Restaurado desde la versión #{@version.version}"
    @tracking_template.save!

    render json: { tracking_template_id: @tracking_template.id,
                   restored_from: @version.version,
                   version: @tracking_template.versions.maximum(:version) }
  end

  private

  def fetch_tracking_template
    @tracking_template = Current.account.tracking_templates.find(params[:tracking_template_id])
  end

  def fetch_version
    @version = @tracking_template.versions.find(params[:id])
  end

  # Contra qué se compara en `show`: la versión pedida en ?compare_with=, o la anterior.
  def comparison_base
    return @comparison_base if defined?(@comparison_base)

    @comparison_base = if params[:compare_with].present?
                         @tracking_template.versions.find_by(id: params[:compare_with])
                       else
                         @tracking_template.versions.where(version: ...@version.version).ordered.first
                       end
  end

  def previous_of(versions, version)
    versions.find { |candidate| candidate.version < version.version }
  end

  # El inbox pudo borrarse entre el snapshot y la restauración: se restaura sin inbox
  # antes que con un puntero muerto que rompería el guardado.
  def restorable_attributes
    attrs = @version.snapshot.slice(*TrackingTemplateVersion::VERSIONED_FIELDS)
    attrs['inbox_id'] = nil if attrs['inbox_id'].present? && !Current.account.inboxes.exists?(id: attrs['inbox_id'])
    attrs
  end

  def version_json(version, base)
    {
      id: version.id,
      version: version.version,
      source: version.source,
      note: version.note,
      author: version.author_name,
      created_at: version.created_at,
      # La versión de origen no «cambió» nada: es el punto de partida.
      changed_fields: base ? AiAgentAssistant::VersionDiff.between(base.snapshot, version.snapshot).pluck(:field) : []
    }
  end
end
