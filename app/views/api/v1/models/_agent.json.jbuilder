json.id resource.id
# could be nil for a deleted agent hence the safe operator before account id
json.account_id Current.account&.id
json.availability_status resource.availability_status
json.auto_offline resource.auto_offline
json.confirmed resource.confirmed?
json.email resource.email
json.available_name resource.available_name
json.custom_attributes resource.custom_attributes if resource.custom_attributes.present?
json.name resource.name
json.role resource.role
json.thumbnail resource.avatar_url
json.custom_role_id resource.current_account_user&.custom_role_id if ChatwootApp.enterprise?
# ================================================================================
# proyecto@user_contact
# ================================================================================
json.agent_contact_id resource.current_account_user&.agent_contact_id
if (agent_contact = resource.current_account_user&.agent_contact)
  json.agent_contact do
    json.id agent_contact.id
    json.name agent_contact.name
    json.phone_number agent_contact.phone_number
    json.email agent_contact.email
  end
end
# ================================================================================
