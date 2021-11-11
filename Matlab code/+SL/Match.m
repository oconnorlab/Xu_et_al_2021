classdef Match
    % Match similar sequences
    
    methods(Static)
        function AlignTime(se, ops)
            % Apply preset alignment to SE
            
            % Compute alignment times
            bt = se.GetTable('behavTime');
            switch ops.alignType
                case {'init', 'iti'}
                    tAlign = bt.cue;
                case {'mid', 'seq'}
                    tAlign = cellfun(@(x) x(4), bt.posIndex);
                case 'term'
                    tAlign = bt.endConsump;
                case 'cons'
                    tAlign = SL.Behav.GetConsTime(bt, 'on');
                case 'seq_zz'
                    for i = height(bt) : -1 : 1
                        tMid = bt.posIndex{i}(7);
                        licks = bt.lickObj{i};
                        [~, I] = min(abs(double(licks) - tMid));
                        tAlign(i,1) = licks(I).MidTime;
                    end
                case 'first_drive'
                    tAlign = cellfun(@(x) x(1), bt.posIndex);
                otherwise
                    error('%s is not a valid alignType', ops.alignType);
            end
            
            % Check NaN
            indNaN = find(isnan(tAlign));
            if ~isempty(indNaN)
                warning('Found %d NaN alignment times. Corresponding trials will be removed.', numel(indNaN));
                se.RemoveEpochs(indNaN);
                tAlign(indNaN) = [];
            end
            
            % Alignment
            se.AlignTime(tAlign);
        end
        
        function se = MatchTrials(se, ops)
            % Keep trials with the most similar behavior and remove others
            
            % Make a hard copy of the object
            se = se.Duplicate();
            
            % Match trials
            if se.numEpochs <= ops.minTrials
                warning('Not enough trials to match.');
                return;
            end
            nTrials = round(se.numEpochs * ops.fracTrials);
            nTrials = max(nTrials, ops.minTrials);
            nTrials = min(nTrials, ops.maxTrials);
            ops.nTrials = nTrials;
            [matchInd, matchStats] = ops.algorithm(se, ops);
            
            % Remove unmatched
            trialInd = se.epochInd(matchInd);
            se.RemoveEpochs(~ismember(se.epochInd, trialInd));
            
            % Save metadata
            se.userData.matchInfo = matchStats;
        end
        
        function [trial_ind, stats] = Algorithm1(se, ops)
            % Find trials with the most similar lick and touch times, using double(lickObj)
            
            % Unpack data
            bt = se.GetTable('behavTime');
            tWin = ops.matchWin;
            ntop = ops.nTrials;
            
            % Preallocate for 7 licks per second
            nLickMatch = round(diff(tWin) * 7);
            tTouch = zeros(height(bt), nLickMatch);
            tLick = zeros(height(bt), nLickMatch);
            
            % Loop through trials
            for i = 1 : height(bt)
                lickObj = bt.lickObj{i}';
                lickObj(lickObj < tWin(1)) = [];
                
                % Find time stamps of available touches
                touches = double(lickObj(lickObj.IsTouch));
                nAvail = min(numel(touches), nLickMatch);
                tTouch(i, 1:nAvail) = touches(1:nAvail);
                
                % Find time stamps of all available licks
                licks = double(lickObj);
                nAvail = min(numel(licks), nLickMatch);
                tLick(i, 1:nAvail) = licks(1:nAvail);
            end
            
            % Make features vectors using lick and touch times
            tTouch(isnan(tTouch)) = 0;
            tLick(isnan(tLick)) = 0;
            q = [tTouch, tLick]; % q is a #trial-by-(2*7/s) matrix
            
            % Find most similar feature vectors
            [trial_ind, stats] = SL.Match.FindSimilar(q, ntop);
        end
        
        function [trial_ind, stats] = Algorithm2(se, ops)
            % Find trials with the most similar lick and touch times, using lickObj.MidTime
            
            % Unpack data
            bt = se.GetTable('behavTime');
            tWin = ops.matchWin;
            ntop = ops.nTrials;
            
            % Preallocate for 7 licks per second
            nLickMatch = round(diff(tWin) * 7);
            tTouch = zeros(height(bt), nLickMatch);
            tLick = zeros(height(bt), nLickMatch);
            
            % Loop through trials
            for i = 1 : height(bt)
                lickObj = bt.lickObj{i}';
                lickObj(lickObj < tWin(1)) = [];
                [tAll, ~, tT] = lickObj.MidTime;
                
                % Find timestamps of available touches
                tT = tT(~isnan(tT));
                nAvail = min(numel(tT), nLickMatch);
                tTouch(i, 1:nAvail) = tT(1:nAvail);
                
                % Find timestamps of all available licks
                nAvail = min(numel(tAll), nLickMatch);
                tLick(i, 1:nAvail) = tAll(1:nAvail);
            end
            
            % Make features vectors using lick and touch times
            tTouch(isnan(tTouch)) = 0;
            tLick(isnan(tLick)) = 0;
            q = [tTouch, tLick]; % q is a #trial-by-(2*7/s) matrix
            
            % Find most similar feature vectors
            [trial_ind, stats] = SL.Match.FindSimilar(q, ntop);
        end
        
        function [trial_ind, stats] = Algorithm3(se, ops)
            % Find trials with the most similar lick, touch and drive pattern
            
            % Unpack data
            bt = se.GetTable('behavTime');
            tWin = ops.matchWin;
            ntop = ops.nTrials;
            
            % Preallocate for feature vectors
            tBinSize = 0.01;
            tEdges = tWin(1) : tBinSize : tWin(2);
            q = zeros(height(bt), numel(tEdges)-1);
            
            % Generate smoothed time series where licks are 1, touches are 2, drives are 3
            for i = 1 : height(bt)
                lickObj = bt.lickObj{i}';
                tLick = lickObj.MidTime;
                isTouch = lickObj.IsTouch;
                isDr = [lickObj.isDrive] | [lickObj.isReward];
                q(i,:) = histcounts([tLick tLick(isTouch) tLick(isDr)], tEdges);
            end
            q = MNeuro.Filter1(q', 1/tBinSize, 'gaussian', 0.02, 0.1)';
            
            % Find most similar feature vectors
            [trial_ind, stats] = SL.Match.FindSimilar(q, ntop);
        end
        
        function [trial_ind, stats] = Algorithm4(se, ops)
            % Find trials with the most similar lick, touch and drive pattern
            
            % Get data and parameters
            bt = se.GetTable('behavTime');
            tWin = ops.matchWin;
            ntop = ops.nTrials;
            tBinSize = 0.01;
            tEdges = tWin(1) : tBinSize : tWin(2);
            
            % Generate smoothed time series of licks, touches and drives
            q = cell(1,3);
            for i = height(bt) : -1 : 1
                lickObj = bt.lickObj{i}';
                tLick = lickObj.MidTime;
                isTouch = lickObj.IsTouch;
                isDr = [lickObj.isDrive] | [lickObj.isReward];
                q{1}(i,:) = histcounts(tLick, tEdges);
                q{2}(i,:) = histcounts(tLick(isTouch), tEdges);
                q{3}(i,:) = histcounts(tLick(isDr), tEdges);
            end
            for i = 1 : numel(q)
                q{i} = MNeuro.Filter1(q{i}', 1/tBinSize, 'gaussian', 0.02, 0.1)';
            end
            q = cat(2, q{:});
            
            % Find most similar feature vectors
            [trial_ind, stats] = SL.Match.FindSimilar(q, ntop);
            stats.q = q(trial_ind,:);
        end
        
        function [trial_ind, stats] = FindSimilar(q, ntop)
            
            r_vect = pdist(q, 'euclidean');
            r = squareform(r_vect);
            
            [r_sorted, i_r_sorted] = sort(r, 'ascend');
            r_sum = nansum(r_sorted(1:ntop,:));
            [~, i_sum_sorted] = sort(r_sum, 'ascend');
            
            stats.r = r;
            stats.r_sorted = r_sorted(:, i_sum_sorted);
            stats.i_r_sorted = i_r_sorted(1:ntop,:);
            stats.r_sum = r_sum;
            stats.i_sum_sorted = i_sum_sorted;
            
            trial_ind = i_r_sorted(1:ntop, i_sum_sorted(1)); % use the best group
        end
        
        function [trial_ind, stats] = AlgorithmZ(se, ops)
            % Find sequences without miss or break
            
            % Unpack data
            bt = se.GetTable('behavTime');
            tWin = ops.matchWin;
            
            % Preallocate for label and angle
            nLick = round(diff(tWin) * 6.5);
            isPerfect = true(height(bt), 1);
            
            % Loop through trials
            for i = 1 : height(bt)
                lickObj = bt.lickObj{i}';
                lickObj(lickObj < tWin(1) | lickObj > tWin(2)) = []; % remove licks outside time window
                isPerfect(i) = all(lickObj.IsTouch) && numel(lickObj) == nLick; % check for no miss and no break
            end
            
            % Return results if perfect sequences are less than required
            trial_ind = find(isPerfect);
            stats = [];
        end
        
        function ReviewMatching(seTbPaths)
            %  Make and save plots for one or more seTbs showing overlays of matched behavior
            
            % Find files
            if ~exist('seTbPaths', 'var') || isempty(seTbPaths)
                seTbPaths = MBrowse.Files(SL.Data.analysisRoot, 'Select one or more seTb');
            end
            
            % Go through each seTb
            for k = 1 : numel(seTbPaths)
                % Load seTb
                load(seTbPaths{k});
                
                % Select standard and backtracking sequenes wo opto
                isSelect = ismember(seTb.seqId, [SL.Param.stdSeqs SL.Param.backSeqs SL.Param.zzSeqs]) & seTb.opto == -1;
                if ~any(isSelect)
                    warning('%s is not plotted because it does not have supported sequence', seTb.sessionId{1});
                    continue
                end
                seTb = seTb(isSelect,:);
                
                % Plot behavior overlays
                f = MPlot.Figure(1); clf
                f.WindowState = 'maximized';
                SL.Match.PlotOverlays(seTb.se);
                
                % Save figure
                seTbDir = fileparts(seTbPaths{k});
                figName = [seTb.sessionId{1} ' matching'];
                print(f, fullfile(seTbDir, figName), '-dpng', '-r0');
            end
        end
        
        function PlotOverlays(seArray)
            % Plot overlays of matched behavior
            %   Rows of the subplots are lick times, tongue angle, length, and lick forces
            %   Columns of the subplots are for individual se in seArray
            
            nRows = 4;
            nSE = numel(seArray);
            
            for i = 1 : nSE
                se = seArray(i);
                ops = se.userData.ops;
                tWin = ops.matchWin;
                [bt, bv, hsv, adc] = se.GetTable('behavTime', 'behavValue', 'hsv', 'adc');
                
                ax = subplot(nRows, nSE, i+nSE*0); cla
                SL.BehavFig.TrialRaster(bt);
                ax.Title.String = [char(bv.seqId(1)) ' ' ops.alignType ', ' num2str(se.numEpochs) ' trials'];
                ax.Title.Interpreter = 'none';
                ax.XLim = tWin;
                ax.XAxis.Visible = 'off';
                ax.YAxis.Visible = 'off';
                ax.XGrid = 'off';
                ax.YGrid = 'off';
                
%                 tEdges = tWin(1) : 1/6.5 : tWin(2);
%                 plot([tEdges; tEdges], ax.YLim', 'Color', [0 0 0 .2]);
                
                ax = subplot(nRows, nSE, i+nSE*1); cla
                SL.Match.PlotAngleOverlay(hsv.time, hsv.tongue_bottom_angle, ...
                    'Color', [0 0 0 .2]);
                ax.XLim = tWin;
                ax.XAxis.Visible = 'off';
                
                ax = subplot(nRows, nSE, i+nSE*2); cla
                SL.Match.PlotLengthOverlay(hsv.time, hsv.tongue_bottom_length, ...
                    'Color', [0 0 0 .2]);
                ax.XLim = tWin;
                ax.XAxis.Visible = 'off';
                
                ax = subplot(nRows, nSE, i+nSE*3); cla
                SL.Match.PlotPerchOverlay(adc.time, adc.forceV, 50, 0.65, 'Color', [0 0 0 .2]);
                SL.Match.PlotPerchOverlay(adc.time, adc.forceH, 50, 0.25, 'Color', [0 0 0 .2]);
                ax.XLim = tWin;
            end
        end
        
        function PlotAngleOverlay(tt, aa, varargin)
            for i = 1 : numel(tt)
                plot(tt{i}, aa{i}, varargin{:}); hold on
            end
            ax = gca;
            ax.YLim = [-55 55];
            ax.YTick = -45:15:45;
            ax.TickLength = [0 0];
            ax.XLabel.String = 'Time (s)';
            ax.YLabel.String = 'Angle (deg)';
            grid(ax, 'on');
            ax.XMinorGrid = 'on';
            box(ax, 'off');
        end
        
        function PlotLengthOverlay(tt, ll, varargin)
            for i = 1 : numel(tt)
                plot(tt{i}, ll{i}, varargin{:}); hold on
            end
            ax = gca;
            ax.YLim = [0 5];
            ax.YTick = 0:1:5;
            ax.TickLength = [0 0];
            ax.XLabel.String = 'Time (s)';
            ax.YLabel.String = 'Length (mm)';
            grid(ax, 'on');
            ax.XMinorGrid = 'on';
            box(ax, 'off');
        end
        
        function PlotPerchOverlay(tt, pp, r, c, varargin)
            for i = 1 : numel(tt)
                t = downsample(tt{i}, 5);
                p = ProcFunc(pp{i});
                plot(t, p*r+c, varargin{:}); hold on
            end
            ax = gca;
            ax.YLim = [0 1];
            ax.TickLength = [0 0];
            ax.XLabel.String = 'Time (s)';
            ax.YLabel.String = 'Touch forces (AU)';
            ax.XMinorGrid = 'on';
            box(ax, 'off');
            
            function x = ProcFunc(x)
                if isempty(x)
                    return;
                end
                x = decimate(double(x), 5);
                x = x - median(x);
            end
        end
    end
end




