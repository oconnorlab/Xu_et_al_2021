classdef BehavFig
    methods(Static)
        % Evaluation
        function ReviewSession(se)
            % Plot performance in one session
            
            nRows = 5;
            nCols = 5;
            
            % Print session info
            seInfo = SL.SE.GetSessionInfoTable(se);
            ax = subplot(nRows, nCols, 1);
            textContent = [ ...
                seInfo.animalId{1} '\n' ...
                datestr(seInfo.sessionDatetime, 31) '\n' ...
                '{\\color{blue}Right to Left}\n' ...
                '{\\color{red}Left to Right}\n'];
            text(0, 0, sprintf(textContent), 'Interpreter', 'tex', 'FontSize', 16, 'VerticalAlignment', 'top');
            ax.YDir = 'reverse';
            axis off
            
            % Prepare data
            bt = se.GetTable('behavTime');
            bv = se.GetTable('behavValue');
            bv.isRL = cellfun(@(x) x(end) > x(1), bv.posIndex);
            
            % Plot running averages
            layoutMat = zeros(nRows, nCols);
            layoutMat(2:nRows-2,1) = 1;
            ax = subplot(nRows, nCols, find(layoutMat'));
            m = bv.isRL & isnan(bv.opto);
            SL.BehavFig.SessionRunAvg(ax, bt(m,:), bv(m,:), SL.Param.RLColor);
            m = ~bv.isRL & isnan(bv.opto);
            SL.BehavFig.SessionRunAvg(ax, bt(m,:), bv(m,:), SL.Param.LRColor);
            
            % Plot CDFs
            layoutMat = zeros(nRows, nCols);
            layoutMat(nRows-1,1) = 1;
            ax = subplot(nRows, nCols, find(layoutMat'));
            m = bv.isRL & isnan(bv.opto);
            SL.BehavFig.SessionCDF(ax, bt(m,:), bv(m,:), SL.Param.RLColor);
            m = ~bv.isRL & isnan(bv.opto);
            SL.BehavFig.SessionCDF(ax, bt(m,:), bv(m,:), SL.Param.LRColor);
            
            % Plot IDI histograms
            layoutMat = zeros(nRows, nCols);
            layoutMat(nRows,1) = 1;
            ax = subplot(nRows, nCols, find(layoutMat'));
            m = bv.isRL & isnan(bv.opto);
            SL.BehavFig.SessionIDI(ax, bt(m,:), SL.Param.RLColor);
            m = ~bv.isRL & isnan(bv.opto);
            SL.BehavFig.SessionIDI(ax, bt(m,:), SL.Param.LRColor);
            
            
            % Sort trials
            [~, sortInd] = sortrows([bv.opto, bt.water]);
            bt = bt(sortInd,:);
            bv = bv(sortInd,:);
            
            % Find and rank sequences
            [G, seqTb] = findgroups(bv(:,{'seqId','isRL'}));
            seqTb.seqId = cellstr(seqTb.seqId);
            seqTb.numTrials = splitapply(@length, G, G);
            seqTb.trialInd = splitapply(@(x) {x}, (1:height(bt))', G);
            seqTb = sortrows(seqTb, {'isRL', 'numTrials'}, {'ascend', 'descend'});
            seqTbRL = seqTb(seqTb.isRL,:);
            seqTbLR = seqTb(~seqTb.isRL,:);
            
            tPlotEnd = prctile(bt.water(~isnan(bt.water)), 75) + 1.5;
            
            % Plot trial rasters for each sequence type
            layoutMat = zeros(nRows, nCols, 3);
            layoutMat(:,2,1) = 1;
            layoutMat(1:2,3,2) = 1;
            layoutMat(3:4,3,3) = 1;
            
            for i = 1 : min(3, height(seqTbRL))
                subplot(nRows, nCols, find(layoutMat(:,:,i)'));
                SL.BehavFig.TrialRaster(bt(seqTbRL.trialInd{i},:));
                xlim([0 tPlotEnd]);
                ylabel(seqTbRL.seqId(i));
            end
            
            layoutMat = circshift(layoutMat, 2, 2);
            
            for i = 1 : min(3, height(seqTbLR))
                subplot(nRows, nCols, find(layoutMat(:,:,i)'));
                SL.BehavFig.TrialRaster(bt(seqTbLR.trialInd{i},:));
                xlim([0 tPlotEnd]);
                ylabel(seqTbLR.seqId(i));
            end
            
        end
        
        function SessionRunAvg(varargin)
            % 
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [bt, bv, cc] = varargin{:};
            if isempty(bt)
                return
            end
            
            sFD = SL.Behav.FirstDriveRunAvg(bt, bv);
            sSD = SL.Behav.SeqDurRunAvg(bt, bv);
            sNL = SL.Behav.NolickRunAvg(bv);
            
            plot(sFD.tPos0S * 1e3, sFD.x, '-', 'Color', cc); hold on
            plot(sSD.seqDurS * 1e3, sSD.x, ':', 'Color', cc, 'LineWidth', 1.5); hold on
            plot(sNL.nolickS, sNL.x, '-.', 'Color', cc); hold on
            
            ax.XScale = 'log';
            ax.XTick = 10.^(0:3) * 100;
            ax.YDir = 'reverse';
            grid on
            xlim([1e2 2e4]);
            ylim([0 max(sFD.x)+1]);
            xlabel('ms');
            ylabel('Trial');
            title('1st drive time, seq duration, timeout');
            MPlot.Axes(ax);
        end
        
        function SessionCDF(varargin)
            % 
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [bt, bv, cc] = varargin{:};
            
            sFD = SL.Behav.FirstDriveCDF(bt); hold on
            sSD = SL.Behav.SeqDurCDF(bt);
            sNL = SL.Behav.NolickCDF(bv);
            
            stairs(sFD.tEdges(1:end-1)*1e3, sFD.N, '-', 'Color', cc);
            stairs(sSD.tEdges(1:end-1)*1e3, sSD.N, ':', 'Color', cc, 'LineWidth', 1.5);
            stairs(sNL.tEdges(1:end-1), sNL.N, '-.', 'Color', cc); hold on
            
            ax.XScale = 'log';
            ax.XTick = 10.^(0:3) * 100;
            grid on
            xlim([1e2 2e4]);
            ylim([0 1]);
            xlabel('ms');
            ylabel('Fraction');
            title('1st drive time, seq duration, timeout');
            MPlot.Axes(ax);
        end
        
        function SessionIDI(ax, bt, cc)
            % 
            sIDI = SL.Behav.IDIHist(bt);
            tEdges = sIDI.tEdges * 1e3;
            IDI = max([sIDI.N 0], 1e-3);
            stairs(ax, tEdges, IDI, 'Color', cc); hold on
            grid on
            
            ax.YScale = 'log';
            ax.YTick = 10.^(-3:0);
            ax.XLim = tEdges([1 end]);
            ax.YLim = ax.YTick([1 end]);
            xlabel('ms');
            ylabel('Prob.');
            title('inter-drive interval');
            MPlot.Axes(ax);
        end
        
        function TrialRaster(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            
            switch numel(varargin)
                case 1
                    bt = varargin{:};
                otherwise
                    error('Unexpected number of input arguments');
            end
            
            hold(ax, 'on');
            
            [cueOn, cueY, yTickVal] = SL.BehavFig.ConvertEventTimesForRasters(bt.cue);
            plot(ax, Segment(cueOn, cueOn+0.1), Segment(cueY), 'Color', [.75 .5 0], 'LineWidth', 2);
            
            [optoOn, optoY] = SL.BehavFig.ConvertEventTimesForRasters(bt.opto);
            plot(ax, Segment(optoOn, optoOn+0.1), Segment(optoY), 'c', 'LineWidth', 2);
            
            [waterOn, waterY] = SL.BehavFig.ConvertEventTimesForRasters(bt.water);
            plot(ax, Segment(waterOn, waterOn+0.2), Segment(waterY), 'b', 'LineWidth', 2);
            
            if ismember('airOn', bt.Properties.VariableNames)
                [air, airY] = SL.BehavFig.ConvertEventTimesForRasters(bt.airOn);
                MPlot.PlotPointAsLine(air, airY, .6, 'Color', [0 0 0 .5], 'Parent', ax);
            end
            
            [lick, lickY] = SL.BehavFig.ConvertEventTimesForRasters(bt.lickOn);
            MPlot.PlotPointAsLine(lick, lickY, .6, 'Color', [0 0 0], 'LineWidth', 1.5, 'Parent', ax);
            
            [posTime, posY] = SL.BehavFig.ConvertEventTimesForRasters(bt.posIndex);
            MPlot.PlotPointAsLine(posTime, posY, .6, 'Color', [0 .5 .75], 'LineWidth', 1.5, 'Parent', ax);
            
            [wTrig, wTrigY] = SL.BehavFig.ConvertEventTimesForRasters(bt.waterTrig);
            MPlot.PlotPointAsLine(wTrig, wTrigY, .6, 'Color', [0 .5 .75], 'LineWidth', 1.5, 'Parent', ax);
            
            ax.YLim = [0 height(bt)+1];
            ax.XLabel.String = 'Time (s)';
            ax.YDir = 'reverse';
            ax.YTick = yTickVal(1:2:end);
            ax.YLabel.String = 'Trial';
            ax.TickLength = [0 0];
            grid(ax, 'on');
            title(ax, [ ...
                '{\color[rgb]{.75,.5,0}cue}, ' ...
                '{\color[rgb]{.5,.5,.5}air lick}, ' ...
                '{\color[rgb]{0,.5,.75}drive touch}, ' ...
                'other touch, ' ...
                '{\color{blue}water}']);
            
            % Utilities
            function x = Segment(x1, x2)
                x1 = x1(:);
                if nargin > 1
                    x2 = x2(:);
                    x = [x1, x2];
                else
                    x = [x1, x1];
                end
                x = [x, NaN(size(x1))]';
                x = x(:);
            end
        end
        
        function [evtTimes, evtY, yTickVal] = ConvertEventTimesForRasters(evtTimes)
            
            if isnumeric(evtTimes)
                evtTimes = num2cell(evtTimes, 2);
            end
            evtTimes = evtTimes(:);
            
            evtNumber = cellfun(@length, evtTimes);
            yTickVal = (1:length(evtNumber))';
            evtY = arrayfun(@(n,i) ones(n,1)*i, evtNumber, yTickVal, 'Uni', false);
            
            evtTimes = cell2mat(evtTimes);
            evtY = cell2mat(evtY);
        end
        
        function SingleTrial(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            
            switch numel(varargin)
                case 3
                    [k, bt, bv] = varargin{:};
                case 4
                    [k, bt, bv, hsv] = varargin{:};
                otherwise
                    error('Unexpected number of input arguments');
            end
            
            hold(ax, 'on');
            
            cueWin = [bt.cue(k), bt.cueOff(k)] + 0.005;
            MPlot.Blocks(cueWin, 55+[0 10], [.75 .5 0], 'FaceAlpha', 0.8, 'Parent', ax);
            
            waterWin = [bt.water(k), bt.waterOff(k)];
            MPlot.Blocks(waterWin, 55+[0 10], 'b', 'FaceAlpha', 0.8, 'Parent', ax);
            
            touchWin = [bt.lickOn{k}, bt.lickOff{k}];
            MPlot.Blocks(touchWin, 55+[0 10], [0 0 0], 'FaceAlpha', 0.6, 'Parent', ax);
            
            [tPos, iPos] = GetPortTrace(bt.posIndex{k}, 45-bv.posIndex{k}*15);
            plot(ax, tPos, iPos, '-', 'Color', [0 .5 .75], 'LineWidth', 1.5, 'MarkerSize', 6);
            
            if exist('hsv', 'var')
                hsvTime = hsv.time{k};
                
                tonOut = hsv.is_tongue_out{k};
                tonOutWin = hsvTime(MMath.Logical2Bounds(tonOut));
                if iscolumn(tonOutWin)
                    tonOutWin = tonOutWin';
                end
                MPlot.Blocks(tonOutWin, [-45 45], [0 0 0], 'FaceAlpha', 0.1, 'Parent', ax);
                
                ang = hsv.tongue_bottom_angle{k};
                plot(ax, hsvTime, ang, 'r.', 'MarkerSize', 2);
                
                len = hsv.tongue_bottom_length{k};
                len = len / 4.5 * 90 - 45;
                plot(ax, hsvTime, len, 'g.', 'MarkerSize', 2);
            end
            
            ax.XLabel.String = 'Time (s)';
            ax.TickLength = [0 0];
            ax.YLim = [-60 75];
            ax.YTick = -45:45:45;
            ax.YLabel.String = 'Angle (deg)';
            grid(ax, 'on');
            box(ax, 'off');
            
            title(ax, [ ...
                '{\color[rgb]{.75,.5,0}cue}, ' ...
                '{\color[rgb]{.7,.7,.7}air lick}, ' ...
                '{\color[rgb]{.3,.3,.3}touch}, ' ... ...
                '{\color{blue}water}, ' ...
                '{\color[rgb]{0,.5,0.75}water port}, ' ...
                '{\color{red}tongue angle}']);
            
            function [pt, pid] = GetPortTrace(pt, pid)
                pt = [pt pt+0.08]';
                pt = [-24*60*60; pt(:); 24*60*60];
                
                pid = [pid(1) + diff(pid([2 1])); pid];   % assume normal transition for the first drive
                pid = [pid pid]';
                pid = pid(:);
            end
        end
        
        function ProgressReview1(ss)
            % 
            
            % 
            nRows = 5;
            nCols = 5;
            width1 = 1;
            width2 = 2:4;
            width3 = 1;
            sessNum = arrayfun(@(x) "{\bf" + string(x) + "}", (1:numel(ss.sessionInfo.sessionId))');
            sessDate = string(datestr(ss.sessionInfo.sessionDatetime, 'mm/dd'));
            
            % Animal info
            ax = subplot(nRows, nCols, 1);
            textContent = [ss.sessionInfo.animalId '\n'];
            text(0, 0, sprintf(textContent), 'FontSize', 16, 'VerticalAlignment', 'top');
            ax.YDir = 'reverse';
            axis off
            
            % Number of trials
            layoutMat = zeros(nRows, nCols);
            layoutMat(1, width2) = 1;
            ax = subplot(nRows, nCols, find(layoutMat'));
            s = ss.numTrials;
            plot(s.x, s.numTrials, 'k-o');
            formatAxes(ax, sessNum);
            ax.YLim(1) = 0;
            ax.YLabel.String = 'ms';
            ax.Title.String = 'Number of trials performed';
            
            % ITI
            layoutMat = zeros(nRows, nCols);
            layoutMat(2, width2) = 1;
            ax = subplot(nRows, nCols, find(layoutMat'));
            s = ss.ITI;
            errorbar(s.x, s.mean, s.mean-s.ci(:,1), s.ci(:,2)-s.mean, 'k');
            formatAxes(ax, sessNum);
            ax.YLim(1) = 3;
            ax.YLabel.String = 'sec (Mean ± CI)';
            ax.Title.String = 'Intertrial interval';
            
            % Number of licks during no-lick period
            layoutMat = zeros(nRows, nCols);
            layoutMat(3, width2) = 1;
            ax = subplot(nRows, nCols, find(layoutMat'));
            s = ss.impulseLick_L;
            errorbar(s.x, s.median, s.median-s.prct25, s.prct75-s.median, 'r'); hold on
            s = ss.impulseLick_R;
            errorbar(s.x, s.median, s.median-s.prct25, s.prct75-s.median, 'b'); hold on
            formatAxes(ax, sessNum);
            ax.YLim(1) = 0;
            ax.YLim(2) = min(ax.YLim(2), 20);
            ax.Title.String = 'Number of impulsive licks ({\color{blue}R}, {\color{red}L})';
            
            % First-drive time
            layoutMat = zeros(nRows, nCols);
            layoutMat(4, width2) = 1;
            ax = subplot(nRows, nCols, find(layoutMat'));
            s = ss.firstDrive_L;
            errorbar(s.x, s.median*1e3, (s.median-s.prct25)*1e3, (s.prct75-s.median)*1e3, 'b'); hold on
            s = ss.firstDrive_R;
            errorbar(s.x, s.median*1e3, (s.median-s.prct25)*1e3, (s.prct75-s.median)*1e3, 'r'); hold on
            formatAxes(ax, sessNum);
            ax.YScale = 'log';
            ax.YTick = 10.^(0:3) * 100;
            ax.YLim = [1e2 2e4];
            ax.YLabel.String = 'ms (Median IQR)';
            ax.Title.String = 'First-drive time ({\color{blue}RL}, {\color{red}LR})';
            
            % Sequence duration
            layoutMat = zeros(nRows, nCols);
            layoutMat(5, width2) = 1;
            ax = subplot(nRows, nCols, find(layoutMat'));
            s = ss.seqDur_L;
            errorbar(s.x, s.median*1e3, (s.median-s.prct25)*1e3, (s.prct75-s.median)*1e3, 'b'); hold on
            s = ss.seqDur_R;
            errorbar(s.x, s.median*1e3, (s.median-s.prct25)*1e3, (s.prct75-s.median)*1e3, 'r'); hold on
            formatAxes(ax, sessNum);
            ax.YScale = 'log';
            ax.YTick = 10.^(0:3) * 100;
            ax.YLim = [7e2 1e4];
            ax.YLabel.String = 'ms (Median IQR)';
            ax.Title.String = 'Sequence duration ({\color{blue}RL}, {\color{red}LR})';
            
            formatAxes(ax, sessNum + ": " + sessDate);
            
            
            % Helper functions
            function formatAxes(ax, sessStr)
                MPlot.Axes(ax);
                ax.XLim = [0 numel(sessStr)+1];
                ax.XTick = 1 : numel(sessStr);
                ax.XTickLabel = sessStr;
                ax.XTickLabelRotation = -90;
                ax.YGrid = 'on';
            end
            
        end
        
        function DiagAngDenoise(ax, t, ang, len)
            % A temporary function for testing angle denoising parameters
            
            isShort = len < 1;
            plot(ax, t(isShort), ang(isShort), 'bx', 'MarkerSize', 6);
            
            ang(isShort) = NaN;
            plot(ax, t, ang, 'r');
        end
        
        % Manuscript
        function TrialBinary(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, bt] = varargin{:};
            
            hold(ax, 'on');
            t = 0:0.001:10;
            cue = MMath.Bound([bt.cue(k) bt.cueOff(k)]+0.005, t);
            water = MMath.Bound([bt.water(k) bt.waterOff(k)], t);
            cue = MakeTimeSeries(t, cue);
            water = MakeTimeSeries(t, water);
            plot(t, cue, 'k');
            plot(t, water-2, 'k');
            
            ax.YLim = [-3 2];
            ax.YTick = (-2:2:0)+0.5;
            ax.YTickLabel = {'Water delivery', 'Auditory cue'};
            MPlot.Axes(ax);
            
            function ts = MakeTimeSeries(t, et)
                ts = zeros(size(t));
                ts(t == et(:,1)) = 1;
                ts(t == et(:,2)) = -1;
                ts = cumsum(ts);
            end
        end
        
        function TrialForce(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, adc] = varargin{:};
            
            t = adc.time{k};
            lv = adc.forceV{k};
            lh = adc.forceH{k};
            lv = ProcFunc(lv);
            lh = ProcFunc(lh);
            t = interp1(t, (1:numel(lv))/numel(lv)*numel(t));
            
            hold(ax, 'on');
            plot(t, lv + 4, 'Color', 'k', 'LineWidth', 1); hold on
            plot(t, lh, 'Color', 'k', 'LineWidth', 1);
            
            ax.YLim = [-2 8];
            ax.YTick = [0 5];
            ax.YTickLabel = {'F_{hori} (mN)', 'F_{vert} (mN)'};
            MPlot.Axes(ax);
            
            function x = ProcFunc(x)
                if isempty(x)
                    return;
                end
                x = decimate(double(x), 5);
                x = x * 1000;
            end
        end
        
        function TrialAngle(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, hsv] = varargin{:};
            
            hold(ax, 'on');
            t = hsv.time{k};
            A = hsv.tongue_bottom_angle{k};
            L = hsv.tongue_bottom_length{k};
            A(L < SL.Param.minLen4Ang) = NaN;
            
            plot(ax, t([1 end]), [0 0], 'Color', [0 0 0 .15]);
            plot(ax, t, A, 'k', 'LineWidth', 1);
            
            ax.YLim = [-45 45];
            ax.YTick = -30:30:30;
            ax.YLabel.String = '\theta (deg)';
            MPlot.Axes(ax);
        end
        
        function TrialLength(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, hsv] = varargin{:};
            
            hold(ax, 'on');
            hsvTime = hsv.time{k};
            L = hsv.tongue_bottom_length{k};
            plot(ax, hsvTime, L, 'k', 'LineWidth', 1);
            
            ax.YLim = [0 ceil(nanmax(L))];
            ax.YTick = ax.YLim(1) : ax.YLim(2);
            ax.YLabel.String = 'L (mm)';
            MPlot.Axes(ax);
        end
        
        function TrialVelocity(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, hsv] = varargin{:};
            
            hold(ax, 'on');
            t = hsv.time{k};
            V = hsv.tongue_bottom_velocity{k};
            
            plot(ax, t([1 end]), [0 0], 'Color', [0 0 0 .15]);
            plot(ax, t, V, 'k', 'LineWidth', 1);
            
            ax.YLim = [-300 200];
            ax.YTick = [-200 0 200];
            ax.YLabel.String = 'L'' (mm/s)';
            MPlot.Axes(ax);
        end
        
        function TrialTouch(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, bt] = varargin{:};
            
            hold(ax, 'on');
            touchWin = [bt.lickOn{k}, bt.lickOff{k}];
            MPlot.Blocks(touchWin, ax.YLim, [0 0 0], 'FaceAlpha', 0.15, 'Parent', ax);
            
            tPos = [bt.posIndex{k}; bt.waterTrig(k)];
            plot([tPos tPos]', repmat(ax.YLim, [numel(tPos) 1])', 'Color', [0 .7 0]);
        end
        
        function TrialPort(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, bt, bv] = varargin{:};
            
            hold(ax, 'on');
            
            [tPos, iPos] = GetPortTrace(bt.posIndex{k}, 7-bv.posIndex{k});
            plot(ax, tPos, iPos, '-', 'Color', [0 0 0], 'LineWidth', 1);
            
            licks = bt.lickObj{k};
            isTrans = [licks.isDrive] | [licks.isReward];
            tLick = licks.GetTfield('tTouchOn');
            portPos = 7 - [licks.portPos]';
            plot(ax, tLick(isTrans), portPos(isTrans), '.', 'Color', [0 0 0], 'MarkerSize', 8);
            
            ax.YLim = [0.5 7.5];
            ax.YTick = 1:7;
            ax.YTickLabel = ["L" + (3:-1:1), "Mid", "R" + (1:3)];
            MPlot.Axes(ax);
            
            function [pt, pid] = GetPortTrace(pt, pid)
                pt = [pt pt+0.08]';
                pt = [-24*60*60; pt(:); 24*60*60];
                pid = [pid(1) + diff(pid([2 1])); pid];   % assume normal transition for the first drive
                pid = [pid pid]';
                pid = pid(:);
            end
        end
        
        function LickTrajectory(varargin)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = gca;
            end
            [k, bt] = varargin{:};
            
            hold(ax, 'on');
            licks = bt.lickObj{k};
            licks = licks([licks.isDrive] | [licks.isReward]);
            cc = winter(numel(licks));
            for i = 1 : numel(licks)
                x = licks(i).coor(:,1);
                y = licks(i).coor(:,3);
%                 x = x/320*224;
%                 y = y/320*224;
                x = x*SL.Param.mmPerPx;
                y = y*SL.Param.mmPerPx;
                plot(x, y, 'Color', cc(i,:)); hold on
                plot(x(1), y(1), '*', 'Color', cc(i,:), 'MarkerSize', 4);
                plot(x(end), y(end), 'o', 'Color', cc(i,:), 'MarkerSize', 4);
            end
            ax.YDir = 'reverse';
            axis equal
            MPlot.Axes(ax);
            
            colormap(cc);
            cb = colorbar;
            cb.Box = 'off';
            cb.Ticks = [0 0.5 1];
            cb.TickLabels = {'first', 'fourth', 'seventh'};
        end
        
        function LickProfile(s, quantName, varargin)
            
            p = inputParser;
            p.addParameter('Color', [0 0 0]);
            p.addParameter('ErrorType', 'SD');
            p.parse(varargin{:});
            cc = p.Results.Color;
            errType = lower(p.Results.ErrorType);
            
            tb = s.(quantName);
            for i = 1 : height(tb)
                if ismember('mask', tb.Properties.VariableNames)
                    mask = tb.mask{i};
                else
                    mask = true(size(tb.t{i}));
                end
                t = tb.t{i}(mask) * 0.4 + i;
                m = tb.mean{i}(mask);
                e = tb.(errType){i}(mask,:);
                
                if ismember(errType, {'sd', 'se'})
                    MPlot.ErrorShade(t, m, e, 'Color', cc);
                elseif ismember(errType, {'ci'})
                    MPlot.ErrorShade(t, m, e(:,1), e(:,2), 'IsRelative', false, 'Color', cc);
                end
                hold on
                plot(t, m, 'Color', cc);
            end
            
            ax = MPlot.Axes(gca);
            ax.XTick = 1:height(tb);
            ax.XTickLabel = s.(quantName).lickId;
            ax.XLim = [0 height(tb)+1];
        end
        
        function ControlStatsByMice(aTb)
            % 
            
            nMice = height(aTb);
            
            subplot(3,1,1); cla
            yStar = 10;
            for i = 1 : nMice
                % Extract stats
                sCtrl = aTb.tFT{i}(1);
                sNumb = aTb.tFT{i}(2);
                mm = [sCtrl.median sNumb.median];
                ee = [sCtrl.qt' sNumb.qt'] - mm;
                [~, p] = kstest2(sCtrl.sample, sNumb.sample, 'Tail', 'larger');
                
                % Plot stats
                errorbar([i-0.25 i+0.25], mm, ee(1,:), ee(2,:), 'o-', 'Color', 'k', 'MarkerSize', 4); hold on
                if p < 0.05/nMice
                    plot(i, yStar, '*', 'Color', 'k');
                end
                fprintf('tFT %s: %.2g\n', aTb.animalId{i}, p);
            end
            ax = gca;
            ax.YScale = 'log';
            ax.YGrid = 'on';
            ax.XTick = 1 : nMice;
            xlim([0 nMice+.5]);
            ylim([0.1 yStar]);
            xlabel('Animal');
            ylabel('Second');
            title('Time to first touch');
            MPlot.Axes(ax);
            
            subplot(3,1,2); cla
            yStar = 6;
            for i = 1 : nMice
                % Extract stats
                sCtrl = aTb.mFT{i}(1);
                sNumb = aTb.mFT{i}(2);
                mm = [sCtrl.mean sNumb.mean];
                ee = [sCtrl.ci' sNumb.ci'] - mm;
                [~, p] = kstest2(sCtrl.sample, sNumb.sample, 'Tail', 'larger');
                
                % Plot stats
                errorbar([i-0.25 i+0.25], mm, ee(1,:), ee(2,:), 'o-', 'Color', 'k', 'MarkerSize', 4); hold on
                if p < 0.05/nMice
                    plot(i, yStar, '*', 'Color', 'k');
                end
                fprintf('mFT %s: %.2g\n', aTb.animalId{i}, p);
            end
            ax = gca;
            ax.YGrid = 'on';
            ax.XTick = 1 : nMice;
            xlim([0 nMice+.5]);
            ylim([0 yStar]);
            xlabel('Animal');
            ylabel('# of missed licks');
            title('Miss before first touch');
            MPlot.Axes(ax);
            
            subplot(3,1,3); cla
            yStar = 15;
            for i = 1 : nMice
                % Extract stats
                sCtrl = aTb.mSQ{i}(1);
                sNumb = aTb.mSQ{i}(2);
                mm = [sCtrl.mean sNumb.mean];
                ee = [sCtrl.ci' sNumb.ci'] - mm;
                [~, p] = kstest2(sCtrl.sample, sNumb.sample, 'Tail', 'larger');
                
                % Plot stats
                errorbar([i-0.25 i+0.25], mm, ee(1,:), ee(2,:), 'o-', 'Color', 'k', 'MarkerSize', 4); hold on
                if p < 0.05/nMice
                    plot(i, yStar, '*', 'Color', 'k');
                end
                fprintf('mSQ %s: %.2g\n', aTb.animalId{i}, p);
            end
            ax = gca;
            ax.YGrid = 'on';
            ax.XTick = 1 : nMice;
            xlim([0 nMice+.5]);
            ylim([0 yStar]);
            xlabel('Animal');
            ylabel('# of missed licks');
            title('Miss during sequence');
            MPlot.Axes(ax);
        end
        
        function ControlStatsGrouped(aTb)
            % 
            
            nMice = height(aTb);
            D = zeros(2, nMice, 3); % cond-by-mice-by-quant
            
            for i = 1 : nMice
                D(:,i,1) = arrayfun(@(x) x.median, aTb.tFT{i});
                D(:,i,2) = arrayfun(@(x) x.mean, aTb.mFT{i});
                D(:,i,3) = arrayfun(@(x) x.mean, aTb.mSQ{i});
            end

            for i = size(D,3) : -1 : 1
                [~, mm] = MMath.BootCI(1e3, @mean, D(2,:,i)'-D(1,:,i)');
                pd = fitdist(mm, 'Normal');
                pVal(i) = pd.cdf(0);
            end
            
            % Time to first touch
            ax = subplot(3,1,1); cla
            plot(D(:,:,1), 'Color', [0 0 0]); hold on
            bar(mean(D(:,:,1), 2), 'FaceColor', 'none')
            ax.YScale = 'log';
            ax.YGrid = 'on';
            ax.XTick = 1 : 2;
            ax.XTickLabel = {'-', '+'};
            xlim([0 3]);
            ylim([0.1 4]);
            xlabel(['p = ' num2str(pVal(1))]);
            ylabel('Second');
            title('Time to first touch');
            MPlot.Axes(ax);
            
            % Miss before first touch
            ax = subplot(3,1,2); cla
            plot(D(:,:,2), 'Color', [0 0 0]); hold on
            bar(mean(D(:,:,2), 2), 'FaceColor', 'none')
            ax.YGrid = 'on';
            ax.XTick = 1 : 2;
            ax.XTickLabel = {'-', '+'};
            xlim([0 3]);
            ylim([0 5]);
            xlabel(['p = ' num2str(pVal(2))]);
            ylabel('# of missed licks');
            title('Miss before first touch');
            MPlot.Axes(ax);
            
            % Miss during sequence
            ax = subplot(3,1,3); cla
            plot(D(:,:,3), 'Color', [0 0 0]); hold on
            bar(mean(D(:,:,3), 2), 'FaceColor', 'none')
            ax.YGrid = 'on';
            ax.XTick = 1 : 2;
            ax.XTickLabel = {'-', '+'};
            xlim([0 3]);
            ylim([0 6]);
            xlabel(['p = ' num2str(pVal(3))]);
            ylabel('# of missed licks');
            title('Miss during sequence');
            MPlot.Axes(ax);
        end
        
        function SaveExampleMovie(vidPath, mp, xSlow)
            % Make and save an example movie
            
            % Change figure size
            f = figure(1);
            f.Color = 'w';
            % tightfig(f)
            % f.Position(3:4) = [4 3]*130;
            tightfig(f)
            f.Position(3:4) = [4 3]*150;
            
            % Generate video matrix
            stepTime = 1/400 * (400/xSlow)/30;
            vidMat = mp.MakeVideo(f, stepTime);
            
            % Save video
            vidObj = VideoWriter(vidPath, 'MPEG-4');
            vidObj.Quality = 95;
            vidObj.FrameRate = 30;
            open(vidObj);
            writeVideo(vidObj, vidMat);
            close(vidObj);
            
            disp('finished');
        end
    end
end

