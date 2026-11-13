json.payload @applied_slas do |applied_sla|
  conversation = applied_sla.conversation
  json.applied_sla do
    json.id applied_sla.id
    json.sla_id applied_sla.sla_policy_id
    json.sla_name applied_sla.sla_policy.name
    json.sla_status applied_sla.sla_status
    json.created_at applied_sla.created_at.to_i
  end
  json.conversation do
    json.id conversation.display_id
    json.created_at conversation.created_at.to_i
    json.labels conversation.label_list.join(',')
    json.contact do
      json.id conversation.contact_id
      json.name conversation.contact.name
    end
    if conversation.assignee
      json.assignee do
        json.id conversation.assignee.id
        json.name conversation.assignee.name
        json.avatar_url conversation.assignee.avatar_url
        json.thumbnail conversation.assignee.avatar_url
      end
    end
  end
  json.sla_events applied_sla.sla_events.sort_by(&:created_at) do |sla_event|
    json.event_type sla_event.event_type
    json.created_at sla_event.created_at.to_i
  end
end
json.meta do
  json.count @applied_slas.total_count
  json.current_page @applied_slas.current_page
end
