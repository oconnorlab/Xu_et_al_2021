classdef SE
    methods (Static)
        function EnrichLPF(se)
            % Add data derived from LFP signals
            
            % Define filter
            fs = se.userData.intanInfo.LFP_table_sample_rate;
            func = @(x) bandpass(x, [1 50], fs); % e.g. between 1 to 50 Hz
            
            % Filter signals
            lfp = se.GetColumn('LFP', 'series1');
            se.SetColumn('LFP', 'filtered', lfp);
            se.SetColumn('LFP', 'filtered', func, 'all');
        end
        
        function AddStateTable(se)
            % Add a new state table
            
            if ismember('state', se.tableNames)
                warning('state table already exist.');
                return
            end
            
            % Find the duration of recording
            rt = se.GetReferenceTime();
            tLFP = se.GetColumn('LFP', 'time');
            tEnd = rt(end) + tLFP{end}(end);
            
            % Initialize state table
            res = 0.1;
            t = (0 : res : tEnd)';
            s = zeros(size(t));
            tb = MSessionExplorer.MakeTimeSeriesTable(t, s, ...
                'DelimiterTimes', rt, 'VariableNames', {'state'});
            
            % Add table to SE
            se.SetTable('state', tb, 'timeSeries', rt);
        end
    end
end

