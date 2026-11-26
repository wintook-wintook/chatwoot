# frozen_string_literal: true

# Campaña con Vendedor IA — «A quién»: la audiencia clasificada (le llega, ya está con un agente, sin teléfono o correo
# válido, quitados por ti) y UNA página de ella, con filtro por grupo y búsqueda. Clasifica hasta MAX contactos
# (ContactTrackings::BulkAssignPreviewService); arriba de eso solo el total.
#
#   params  payload, inbox_id, excluded_contact_ids, page (1…), per_page (50), bucket (all|ready|in_tracking|
#           unreachable|excluded), q (nombre, teléfono, correo o empresa), facts (Reactivar/Recordar), ids (1: los ids
#           de todo lo filtrado, para quitar o regresar a todos)
#   → { channel, counts, contacts (la página), matching, page, per_page, counts_only, ids? }
#   .csv → todo lo filtrado en CSV (nombre, empresa, teléfono, correo, le llega, motivo)
class TrackingCampaigns::AudiencePage
  MAX = 20_000
  PER_PAGE = 50
  BUCKETS = %w[ready in_tracking unreachable excluded].freeze

  def initialize(account, user, params)
    @account = account
    @user = user
    @params = params.to_h.with_indifferent_access
  end

  def call
    result = classified
    return result if result[:error] || result[:counts_only]

    rows = filtered(result[:contacts])
    page_rows = rows.slice((page - 1) * per_page, per_page) || []
    out = result.merge(contacts: page_rows, matching: rows.size, page: page, per_page: per_page)
    out = TrackingCampaigns::PreviewFacts.call(@account, out) if @params[:facts].present?
    @params[:ids].present? ? out.merge(ids: rows.pluck(:id)) : out
  end

  REASONS = { 'NO_PHONE' => 'Sin teléfono', 'NO_EMAIL' => 'Sin correo', 'UNSUPPORTED_CHANNEL' => 'El canal no permite escribirle primero',
              'OPTED_OUT' => 'Pidió no ser contactado', 'INVALID_EMAIL' => 'Correo mal escrito o que no recibe' }.freeze
  HEADERS = ['Nombre', 'Empresa', 'Teléfono', 'Correo', 'Le llega', 'Motivo'].freeze

  def csv
    result = classified
    rows = result[:contacts].is_a?(Array) ? filtered(result[:contacts]) : []
    CSV.generate do |out|
      out << HEADERS
      rows.each { |r| out << [r[:name], r[:company], r[:phone_number], r[:email], csv_status(r), REASONS.fetch(r[:reason], r[:reason])] }
    end
  end

  private

  def classified
    @classified ||= ContactTrackings::BulkAssignPreviewService.new(
      account: @account, current_user: @user, filter_payload: @params[:payload] || [], template_id: nil,
      inbox_id: @params[:inbox_id], excluded_contact_ids: @params[:excluded_contact_ids] || [], limit: MAX
    ).call
  end

  def filtered(rows)
    rows = rows.select { |r| in_bucket?(r) } if BUCKETS.include?(@params[:bucket])
    query = @params[:q].to_s.strip.downcase
    return rows if query.blank?

    rows.select { |r| [r[:name], r[:phone_number], r[:email], r[:company]].compact.join(' ').downcase.include?(query) }
  end

  def in_bucket?(row)
    return row[:excluded] if @params[:bucket] == 'excluded'

    !row[:excluded] && row[:bucket].to_s == @params[:bucket]
  end

  def page = [@params[:page].to_i, 1].max

  def per_page = (@params[:per_page].presence || PER_PAGE).to_i.clamp(10, 200)

  def csv_status(row)
    return 'Quitado' if row[:excluded]

    row[:bucket].to_s == 'ready' ? 'Sí' : 'No'
  end
end
