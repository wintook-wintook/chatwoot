# frozen_string_literal: true

# ================================================================================
# proyecto@automatizacion_campanas — LAS INSCRIPCIONES DE UNA CAMPAÑA, EN JSON
# ================================================================================
# Plan: docs/automatizacion_campanas_plan.md (§7.2). Lo que muestra la pestaña
# "Inscritos" del detalle: el resumen (cuántos entraron por lote y por automatización,
# cuántos se omitieron y por qué) y la lista paginada, la más reciente primero.
# ================================================================================
module TrackingCampaignEntriesJson
  ENTRIES_PER_PAGE = 25

  private

  def entries_payload(campaign, page)
    scope = campaign.entries.includes(:contact, :automation_rule).order(created_at: :desc, id: :desc)
    {
      summary: entries_summary(campaign),
      meta: { count: scope.count, page: page, per_page: ENTRIES_PER_PAGE },
      entries: scope.offset((page - 1) * ENTRIES_PER_PAGE).limit(ENTRIES_PER_PAGE).map { |entry| entry_json(entry) }
    }
  end

  def entries_summary(campaign)
    enrolled = campaign.entries.enrolled.group(:source).count
    {
      enrolled: enrolled.values.sum,
      batch: enrolled.fetch('batch', 0),
      automation: enrolled.fetch('automation', 0),
      skipped: campaign.entries.skipped.count,
      skipped_by_reason: campaign.entries.skipped.group(:reason).count
    }
  end

  def entry_json(entry)
    {
      id: entry.id, contact_id: entry.contact_id, contact_name: entry.contact&.name,
      source: entry.source, automation_rule_id: entry.automation_rule_id,
      automation_rule_name: entry.automation_rule&.name, status: entry.status, reason: entry.reason,
      contact_tracking_id: entry.contact_tracking_id, conversation_id: entry.conversation_id,
      created_at: entry.created_at
    }
  end
end
