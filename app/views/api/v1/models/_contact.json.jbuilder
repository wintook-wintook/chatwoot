json.additional_attributes resource.additional_attributes
json.availability_status resource.availability_status
json.email resource.email
json.id resource.id
json.name resource.name
json.phone_number resource.phone_number
json.identifier resource.identifier
json.thumbnail resource.avatar_url
json.custom_attributes resource.custom_attributes
# Plan-Organizaciones O1 — la ficha la carga aparte (/organizations/:id)
json.organization_id resource.organization_id
json.last_activity_at resource.last_activity_at.to_i if resource[:last_activity_at].present?
json.created_at resource.created_at.to_i if resource[:created_at].present?
# prospeccion V4: pidió no ser contactado (enlace, respuesta o a mano)
json.opted_out_at resource.opted_out_at.to_i if resource[:opted_out_at].present?
json.opted_out_source resource.opted_out_source if resource[:opted_out_at].present?
# prospeccion V7b: su correo rebotó
json.email_bounced_at resource.email_bounced_at.to_i if resource[:email_bounced_at].present?
json.email_bounce_reason resource.email_bounce_reason if resource[:email_bounced_at].present?
# we only want to output contact inbox when its /contacts endpoints
if defined?(with_contact_inboxes) && with_contact_inboxes.present?
  json.contact_inboxes do
    json.array! resource.contact_inboxes do |contact_inbox|
      json.partial! 'api/v1/models/contact_inbox', formats: [:json], resource: contact_inbox
    end
  end
end
