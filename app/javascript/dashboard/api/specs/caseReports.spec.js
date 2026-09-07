import caseReportsAPI from '../caseReports';
import ApiClient from '../ApiClient';

describe('#CaseReports API', () => {
  it('creates correct instance', () => {
    expect(caseReportsAPI).toBeInstanceOf(ApiClient);
    expect(caseReportsAPI.apiVersion).toBe('/api/v2');
    expect(caseReportsAPI).toHaveProperty('getFunnel');
    expect(caseReportsAPI).toHaveProperty('getOutcome');
    expect(caseReportsAPI).toHaveProperty('getTimeseries');
    expect(caseReportsAPI).toHaveProperty('getAssignees');
    expect(caseReportsAPI).toHaveProperty('getVelocity');
    expect(caseReportsAPI).toHaveProperty('getStalled');
  });

  describe('API calls', () => {
    const originalAxios = window.axios;
    const axiosMock = {
      post: vi.fn(() => Promise.resolve()),
      get: vi.fn(() => Promise.resolve()),
      patch: vi.fn(() => Promise.resolve()),
      delete: vi.fn(() => Promise.resolve()),
    };

    beforeEach(() => {
      window.axios = axiosMock;
    });

    afterEach(() => {
      window.axios = originalAxios;
    });

    it('#getFunnel', () => {
      caseReportsAPI.getFunnel({
        caseTypeId: 3,
        assigneeId: 7,
        teamId: 2,
        from: 1621103400,
        to: 1621621800,
      });
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v2/case_reports/funnel',
        {
          params: {
            case_type_id: 3,
            assignee_id: 7,
            team_id: 2,
            since: 1621103400,
            until: 1621621800,
          },
        }
      );
    });

    it('#getOutcome', () => {
      caseReportsAPI.getOutcome({
        caseTypeId: 3,
        assigneeId: 7,
        teamId: 2,
        from: 1621103400,
        to: 1621621800,
      });
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v2/case_reports/outcome',
        {
          params: {
            case_type_id: 3,
            assignee_id: 7,
            team_id: 2,
            since: 1621103400,
            until: 1621621800,
          },
        }
      );
    });

    it('#getTimeseries', () => {
      caseReportsAPI.getTimeseries({
        caseTypeId: 3,
        groupBy: 'week',
        from: 1621103400,
        to: 1621621800,
      });
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v2/case_reports/timeseries',
        {
          params: {
            case_type_id: 3,
            assignee_id: undefined,
            team_id: undefined,
            since: 1621103400,
            until: 1621621800,
            group_by: 'week',
            timezone_offset: -0,
          },
        }
      );
    });

    it('#getAssignees', () => {
      caseReportsAPI.getAssignees({
        caseTypeId: 3,
        teamId: 2,
        from: 1621103400,
        to: 1621621800,
      });
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v2/case_reports/assignees',
        {
          params: {
            case_type_id: 3,
            assignee_id: undefined,
            team_id: 2,
            since: 1621103400,
            until: 1621621800,
          },
        }
      );
    });

    it('#getVelocity', () => {
      caseReportsAPI.getVelocity({ caseTypeId: 3 });
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v2/case_reports/velocity',
        {
          params: {
            case_type_id: 3,
            assignee_id: undefined,
            team_id: undefined,
            since: undefined,
            until: undefined,
          },
        }
      );
    });

    it('#getStalled', () => {
      caseReportsAPI.getStalled({ caseTypeId: 3, thresholdDays: 5 });
      expect(axiosMock.get).toHaveBeenCalledWith(
        '/api/v2/case_reports/stalled',
        {
          params: {
            case_type_id: 3,
            assignee_id: undefined,
            team_id: undefined,
            since: undefined,
            until: undefined,
            threshold_days: 5,
          },
        }
      );
    });
  });
});
