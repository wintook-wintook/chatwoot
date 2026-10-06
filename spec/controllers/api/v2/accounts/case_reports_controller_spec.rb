require 'rails_helper'

RSpec.describe 'Case Reports API', type: :request do
  let(:account) { create(:account) }
  let(:admin)   { create(:user, account: account, role: :administrator) }
  let(:agent)   { create(:user, account: account, role: :agent) }

  describe 'GET /api/v2/accounts/:account_id/case_reports/funnel' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/case_reports/funnel"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'returns unauthorized for agents' do
        get "/api/v2/accounts/#{account.id}/case_reports/funnel",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'calls V2::Reports::Cases::DistributionBuilder with the right params if the user is an admin' do
        distribution_builder = double
        allow(V2::Reports::Cases::DistributionBuilder).to receive(:new).and_return(distribution_builder)
        allow(distribution_builder).to receive(:funnel).and_return([{ id: 'open', label: 'open', count: 3 }])

        get "/api/v2/accounts/#{account.id}/case_reports/funnel",
            params: { case_type_id: '7', assignee_id: '9' },
            headers: admin.create_new_auth_token,
            as: :json

        expect(V2::Reports::Cases::DistributionBuilder).to have_received(:new)
          .with(account: account, params: ActionController::Parameters.new(case_type_id: '7', assignee_id: '9').permit!)
        expect(distribution_builder).to have_received(:funnel)

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response.length).to eq(1)
        expect(json_response.first['id']).to eq('open')
        expect(json_response.first['count']).to eq(3)
      end
    end
  end

  describe 'GET /api/v2/accounts/:account_id/case_reports/outcome' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/case_reports/outcome"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'returns unauthorized for agents' do
        get "/api/v2/accounts/#{account.id}/case_reports/outcome",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'calls V2::Reports::Cases::DistributionBuilder with the right params if the user is an admin' do
        distribution_builder = double
        allow(V2::Reports::Cases::DistributionBuilder).to receive(:new).and_return(distribution_builder)
        allow(distribution_builder).to receive(:outcome).and_return({ open: 1, won: 2, lost: 3, other_closed: 0 })

        get "/api/v2/accounts/#{account.id}/case_reports/outcome",
            params: { case_type_id: '7' },
            headers: admin.create_new_auth_token,
            as: :json

        expect(V2::Reports::Cases::DistributionBuilder).to have_received(:new)
          .with(account: account, params: ActionController::Parameters.new(case_type_id: '7').permit!)
        expect(distribution_builder).to have_received(:outcome)

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response['won']).to eq(2)
        expect(json_response['lost']).to eq(3)
      end
    end
  end

  describe 'GET /api/v2/accounts/:account_id/case_reports/timeseries' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/case_reports/timeseries"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'returns unauthorized for agents' do
        get "/api/v2/accounts/#{account.id}/case_reports/timeseries",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'calls V2::Reports::Cases::TimeseriesBuilder with the right params if the user is an admin' do
        timeseries_builder = double
        allow(V2::Reports::Cases::TimeseriesBuilder).to receive(:new).and_return(timeseries_builder)
        allow(timeseries_builder).to receive(:timeseries).and_return(
          { created: [{ value: 1, timestamp: 123 }], closed: [] }
        )

        get "/api/v2/accounts/#{account.id}/case_reports/timeseries",
            params: { group_by: 'week' },
            headers: admin.create_new_auth_token,
            as: :json

        expect(V2::Reports::Cases::TimeseriesBuilder).to have_received(:new)
          .with(account: account, params: ActionController::Parameters.new(group_by: 'week').permit!)
        expect(timeseries_builder).to have_received(:timeseries)

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response['created'].first['value']).to eq(1)
        expect(json_response['closed']).to eq([])
      end
    end
  end

  describe 'GET /api/v2/accounts/:account_id/case_reports/assignees' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/case_reports/assignees"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'returns unauthorized for agents' do
        get "/api/v2/accounts/#{account.id}/case_reports/assignees",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'calls V2::Reports::Cases::AssigneeSummaryBuilder with the right params if the user is an admin' do
        assignee_summary_builder = double
        allow(V2::Reports::Cases::AssigneeSummaryBuilder).to receive(:new).and_return(assignee_summary_builder)
        allow(assignee_summary_builder).to receive(:build).and_return(
          [{ assignee_id: 1, assignee_name: 'John', open: 1, won: 2, lost: 3, other_closed: 0, conversion_rate: 40, avg_close_days: 2.5 }]
        )

        get "/api/v2/accounts/#{account.id}/case_reports/assignees",
            params: { case_type_id: '7' },
            headers: admin.create_new_auth_token,
            as: :json

        expect(V2::Reports::Cases::AssigneeSummaryBuilder).to have_received(:new)
          .with(account: account, params: ActionController::Parameters.new(case_type_id: '7').permit!)
        expect(assignee_summary_builder).to have_received(:build)

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response.first['assignee_name']).to eq('John')
        expect(json_response.first['won']).to eq(2)
      end
    end
  end

  describe 'GET /api/v2/accounts/:account_id/case_reports/velocity' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/case_reports/velocity"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'returns unauthorized for agents' do
        get "/api/v2/accounts/#{account.id}/case_reports/velocity",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'calls V2::Reports::Cases::StageDurationBuilder with the right params if the user is an admin' do
        stage_duration_builder = double
        allow(V2::Reports::Cases::StageDurationBuilder).to receive(:new).and_return(stage_duration_builder)
        allow(stage_duration_builder).to receive(:velocity).and_return([{ status: 'open', avg_days: 1.5, count: 3 }])

        get "/api/v2/accounts/#{account.id}/case_reports/velocity",
            params: { case_type_id: '7' },
            headers: admin.create_new_auth_token,
            as: :json

        expect(V2::Reports::Cases::StageDurationBuilder).to have_received(:new)
          .with(account: account, params: ActionController::Parameters.new(case_type_id: '7').permit!)
        expect(stage_duration_builder).to have_received(:velocity)

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response.first['status']).to eq('open')
        expect(json_response.first['avg_days']).to eq(1.5)
      end
    end
  end

  describe 'GET /api/v2/accounts/:account_id/case_reports/stalled' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/case_reports/stalled"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'returns unauthorized for agents' do
        get "/api/v2/accounts/#{account.id}/case_reports/stalled",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'calls V2::Reports::Cases::StageDurationBuilder with the right threshold if the user is an admin' do
        stage_duration_builder = double
        allow(V2::Reports::Cases::StageDurationBuilder).to receive(:new).and_return(stage_duration_builder)
        allow(stage_duration_builder).to receive(:stalled).and_return(
          [{ id: 1, folio: 'COM-0001', title: 'x', status: 'open', assignee_id: nil, assignee_name: nil, stalled_days: 7.0 }]
        )

        get "/api/v2/accounts/#{account.id}/case_reports/stalled",
            params: { case_type_id: '7', threshold_days: '5' },
            headers: admin.create_new_auth_token,
            as: :json

        expect(V2::Reports::Cases::StageDurationBuilder).to have_received(:new)
          .with(account: account, params: ActionController::Parameters.new(case_type_id: '7', threshold_days: '5').permit!)
        expect(stage_duration_builder).to have_received(:stalled).with(threshold_days: '5')

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body

        expect(json_response.first['folio']).to eq('COM-0001')
        expect(json_response.first['stalled_days']).to eq(7.0)
      end

      it 'defaults the threshold when none is given' do
        stage_duration_builder = double
        allow(V2::Reports::Cases::StageDurationBuilder).to receive(:new).and_return(stage_duration_builder)
        allow(stage_duration_builder).to receive(:stalled).and_return([])

        get "/api/v2/accounts/#{account.id}/case_reports/stalled",
            headers: admin.create_new_auth_token,
            as: :json

        expect(stage_duration_builder).to have_received(:stalled)
          .with(threshold_days: V2::Reports::Cases::StageDurationBuilder::DEFAULT_THRESHOLD_DAYS)
      end
    end
  end
end
