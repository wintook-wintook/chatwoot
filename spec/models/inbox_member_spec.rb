# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InboxMember do
  include ActiveJob::TestHelper

  describe '#DestroyAssociationAsyncJob' do
    let(:inbox_member) { create(:inbox_member) }

    # ref: https://github.com/chatwoot/chatwoot/issues/4616
    context 'when parent inbox is destroyed' do
      it 'enques and processes DestroyAssociationAsyncJob' do
        perform_enqueued_jobs do
          inbox_member.inbox.destroy!
        end
        expect { inbox_member.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'round robin queue sync' do
    let(:account) { create(:account) }
    let(:inbox) { create(:inbox, account: account) }

    def queue_for(inbox)
      Redis::Alfred.lrange(format(Redis::Alfred::ROUND_ROBIN_AGENTS, inbox_id: inbox.id)).map(&:to_i)
    end

    it 'keeps the redis queue in sync with the db members on create' do
      members = create_list(:inbox_member, 3, inbox: inbox)
      expect(queue_for(inbox)).to match_array(members.map(&:user_id))
    end

    it 'rebuilds the queue removing the member on destroy' do
      members = create_list(:inbox_member, 3, inbox: inbox)
      members.first.destroy!
      expect(queue_for(inbox)).to match_array(members.drop(1).map(&:user_id))
    end

    it 'self-heals a desynced queue from the db on the next membership change' do
      members = create_list(:inbox_member, 2, inbox: inbox)
      # corrompemos la cola con ids basura, simulando un Redis flusheado / callback fallido
      service = AutoAssignment::InboxRoundRobinService.new(inbox: inbox)
      service.clear_queue
      service.add_agent_to_queue(99_999)
      expect(queue_for(inbox)).to eq([99_999])

      new_member = create(:inbox_member, inbox: inbox)

      expect(queue_for(inbox)).to match_array((members + [new_member]).map(&:user_id))
    end
  end
end
