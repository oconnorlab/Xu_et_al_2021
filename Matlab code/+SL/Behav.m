classdef Behav
    
    methods(Static)
        function ExcludeTrials(se, ops)
            
            % Get data
            [bt, bv] = se.GetTable('behavTime', 'behavValue');
            isRm = false(se.numEpochs,1);
            
            % The first trial
            if ops.isRemoveFirst && bv.trialNum(1) == 1
                isRm(1) = true;
            end
            
            % The last trial (if unfinished)
            numTouch = sum(bt.lickOn{end} < bt.water(end));
            numPos = numel(bt.posIndex{end});
            if ops.isRemoveLast && numTouch < numPos
                isRm(end) = true;
            end
            
            % Trials with slow reaction
            tFirstDrive = cellfun(@(x) x(1), bt.posIndex);
            isRm = isRm | (tFirstDrive - bt.cue > ops.maxReactionTime);
            
            % Trials with prolonged sequence
            tEnd = bt.waterOff + 2;
            isRm = isRm | (tEnd - bt.cue > ops.maxEndTime);
            
            % Removal
            se.RemoveEpochs(isRm);
        end
        
        function StandardizeLickRange(se)
            % Center the range of lick angle
            
            lickObj = se.GetColumn('behavTime', 'lickObj');
            opto = se.GetColumn('behavValue', 'opto');
            s = SL.Behav.GetKinematicStats(lickObj(isnan(opto))); % only include non-opto trials
            
            offset = s.ang3; % for setting mean shooting angle of mid-licks to zero
            scale = 60 / diff(s.angPrct); % for scaling the middle 90 percentile of shooting angles to span 60 degrees (~median span)
            
            lickObj = cellfun(@(x) x.StandardizeAngle(offset, scale), lickObj, 'Uni', false);
            se.SetColumn('behavTime', 'lickObj', lickObj);
            
            if ismember('hsv', se.tableNames)
                angCol = se.GetColumn('hsv', 'tongue_bottom_angle');
                angCol = cellfun(@(x) (x - offset) * scale, angCol, 'Uni', false);
                se.SetColumn('hsv', 'tongue_bottom_angle', angCol);
            end
        end
        
        function s = GetKinematicStats(L)
            
            if iscell(L)
                L = cat(1, L{:});
            end
            L = L(L.IsTracked & ([L.isDrive]' | [L.isReward]'));
            T = table;
            T.pos = [L.portPos]';
            T.ang = L.ShootingAngle;
            T.len = L.MaxLength;
            
            s = struct;
            s.ang0 = mean(T.ang(T.pos == 0));
            s.ang3 = mean(T.ang(T.pos == 3));
            s.ang6 = mean(T.ang(T.pos == 6));
            s.len = mean(T.len);
            s.len3 = mean(T.len(T.pos == 3));
            s.angPrct = prctile(T.ang, [5 95]);
        end
        
        function seTb = ExtractLickData(seTb, isInvert)
            % Extract tInit, tMid, tCons, tWater and lickObj from se and add them as new columns in seTb.
            % If isInvert is true, angle value in sequences starting from right will be inverted.
            
            for i = height(seTb) : -1 : 1
                % Extract metadata
                seTb.sessionInfo(i) = seTb.se(i).userData.sessionInfo;
                if isfield(seTb.se(i).userData, 'xlsInfo')
                    seTb.xlsInfo(i) = seTb.se(i).userData.xlsInfo;
                end
                
                % Extract opto trigger times
                bt = seTb.se(i).GetTable('behavTime');
                seTb.tInit{i} = bt.cue;
                seTb.tMid{i} = cellfun(@(x) x(4), bt.posIndex);
                seTb.tCons{i} = SL.Behav.GetConsTime(bt, 'off');
                seTb.tWater{i} = bt.water;
                
                % Process Lick objects
                lickObj = bt.lickObj;
                for k = 1 : numel(lickObj)
                    % Invert direction
                    if isInvert && lickObj{k}(1).portPos == 0
                        lickObj{k} = lickObj{k}.InvertDirection;
                    end
                end
                seTb.lickObj{i} = lickObj;
            end
            
            % Delete SE objets
            seTb.se = [];
        end
        
        function tCons = GetConsTime(bt, waterType)
            if ~exist('waterType', 'var')
                waterType = 'off';
            end
            tCons = NaN(height(bt),1);
            for k = 1 : height(bt)
                lobj = bt.lickObj{k};
                tTouch = lobj.GetTfield('tTouchOn');
                switch waterType
                    case 'on'
                        tWater = bt.water(k);
                    case 'off'
                        tWater = bt.waterOff(k);
                end
                idx = find(tTouch-tWater > 0, 1);
                if isempty(idx)
                    warning('No touch after water delivery. Water %g, last lick %g', ...
                        tWater, double(tTouch(end)));
                    tCons(k) = tWater;
                    continue;
                end
                switch waterType
                    case 'on'
                        tCons(k) = (lobj(idx).T.tOut + lobj(idx).T.tIn) / 2;
                    case 'off'
                        tCons(k) = tTouch(idx);
                end
            end
        end
        
        function s = ComputeLickProfile(lickObj, lickId, quantNames, pCI)
            
            % Exclude short and untracked licks
            minFrames = 5;
            isShort = cellfun(@numel, lickObj.GetTfield('tHSV')) < minFrames;
            lickObj(isShort) = [];
            
            % Resample lick data
            nPtInterp = 30;
            lickObj = lickObj.Resample(nPtInterp);
            
            % Cache variables into a table
            tb = table();
            tb.lickId = lickObj.GetVfield('lickId');
            tb.tTouch = [lickObj.GetTfield('tTouchOn') lickObj.GetTfield('tTouchOff')];
            for i = 1: numel(quantNames)
                qn = quantNames{i};
                tb.(qn) = arrayfun(@(x) x.(qn), lickObj, 'Uni', false);
            end
            
            % Initialize outputs
            lickId = lickId(:);
            s.lickId = lickId;
            s.quantNames = quantNames;
            s.pCI = pCI;
            t = linspace(-1, 1, nPtInterp)';
            t = repmat({t}, [numel(lickId) 1]);
            s.tTouch = table(lickId);
            for i = 1: numel(quantNames)
                s.(quantNames{i}) = table(lickId, t);
            end
            
            for i = 1 : numel(lickId)
                % Find licks for a given position
                ind = tb.lickId == lickId(i);
                
                % 
                tTouch = tb.tTouch(ind,:);
                tTouchQt = prctile(tTouch, [25 50 75], 1);
                s.tTouch.samples{i} = tTouch;
                s.tTouch.qt{i} = tTouchQt;
                
                % Compute stats for each quantity
                for j = 1 : numel(quantNames)
                    qn = quantNames{j};
                    sp = cat(2, tb.(qn){ind});
                    
                    % Remove samples with NaN (e.g. merged tracking or force without touch)
                    nanInd = any(isnan(sp),1);
                    fprintf('#%d, %s has %d samples (%d NaN)\n', lickId(i), qn, numel(nanInd), sum(nanInd));
                    pause(0.1);
                    sp(:,nanInd) = [];
                    
                    % Compute stats
                    switch qn
                        case {'forceH', 'forceV' ,'force'}
                            sp = sp * 1e3; % convert to mN
                    end
                    s.(qn).samples{i} = sp;
                    if pCI
                        ops = statset('UseParallel', true);
                        nBoot = max(1e3, 1/pCI*20);
                        [s.(qn).mean{i}, s.(qn).sd{i}, s.(qn).se{i}, s.(qn).ci{i}] = ...
                            MMath.MeanStats(sp, 2, 'NBoot', nBoot, 'Alpha', pCI, 'Options', ops);
                    else
                        [s.(qn).mean{i}, s.(qn).sd{i}, s.(qn).se{i}] = MMath.MeanStats(sp, 2);
                    end
                    
                    % Add mask
                    switch qn
                        case 'angle'
                            s.(qn).mask{i} = s.length.mean{i} >= SL.Param.minLen4Ang;
                        case {'forceH', 'forceV' ,'force'}
                            s.(qn).mask{i} = t{i} > tTouchQt(2,1) & t{i} < tTouchQt(2,2);
                    end
                end
            end
        end
        
        function [histTb, statTb] = ComputeLickStats(lickObj, quantTb, lickId)
            % Compute angle and length histograms from a vector of Lick objects according to specifications
            % in quantTb (including quant name, edges, centers)
            
            % Get lickIds and remove irrelvant licks
            if ~exist('lickId', 'var')
                lickId = 1;
                lickIds = ones(size(lickObj));
            else
                lickIds = lickObj.GetVfield('lickId');
            end
            
            % Compute stats to a table
            histTb = table();
            histTb.lickId = lickId(:);
            statTb = histTb;
            for k = 1 : height(quantTb)
                % Compute quantity
                qn = quantTb.name{k};
                switch qn
                    case 'angle'
                        q = lickObj.ShootingAngle;
                    case 'length'
                        q = lickObj.MaxLength;
                    case 'dAngle'
                        q = [NaN; diff(lickObj.ShootingAngle)];
                    case 'rate'
                        [~, ~, tShoot] = lickObj.ShootingLength;
                        q = 1 ./ [Inf; diff(tShoot)];
                end
                
                % Compute histograms and stats
                for i = 1 : numel(lickId)
                    isId = lickIds == lickId(i);
                    
                    histTb.(qn)(i,:) = histcounts(q(isId), quantTb.edges{k}, 'Normalization', 'probability');
                    
                    [m, sd, se] = MMath.MeanStats(q(isId));
                    statTb.([qn 'Mean'])(i) = m;
                    statTb.([qn 'SD'])(i) = sd;
                    statTb.([qn 'SE'])(i) = se;
                end
            end
        end
        
        function [meanTb, stdTb] = ComputeMeanLickStats(lickObjArray, quantTb, lickId)
            
            histTbArray = cell(size(lickObjArray));
            for i = 1 : numel(lickObjArray)
                licks = lickObjArray{i};
                
                % Remove irrelevant licks
                isInclude = ismember(licks.GetVfield('lickId'), lickId) & licks.IsTracked;
                licks = licks(isInclude);
                
                if ~exist('lickId', 'var')
                    % Compute overall distributions
                    histTbArray{i} = SL.Behav.ComputeLickStats(licks, quantTb);
                else
                    % Compute distributions by lickId
                    histTbArray{i} = SL.Behav.ComputeLickStats(licks, quantTb, lickId);
                end
            end
            
            if exist('lickId', 'var')
                % Average across tables
                meanTb = table(lickId);
                stdTb = meanTb;
                for i = 1 : height(quantTb)
                    qn = quantTb.name{i};
                    D = cellfun(@(x) x.(qn), histTbArray, 'Uni', false);
                    D = cat(3, D{:});
                    [meanTb.(qn), stdTb.(qn)] = MMath.MeanStats(D, 3);
                end
            else
                meanTb = histTbArray{1};
                stdTb = [];
            end
        end
        
        function s = TrialNumStat(varargin)
            % Extract the number of trials for each session and optionally make a plot
            %   s = TrialNumStat(seArray)
            %   s = TrialNumStat(ax, seArray)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = [];
            end
            
            switch numel(varargin)
                case 1
                    seArray = varargin{:};
                otherwise
                    error('Unexpected number of input arguments');
            end
            
            s.x = (1:numel(seArray))';
            s.numTrials = arrayfun(@(x) x.numEpochs, seArray(:));
            
            if ~isempty(ax)
                bar(s.x, s.numTrials, 'FaceColor', 'none');
                xlabel('Session');
                title('Number of trials performed');
                ax.XTick = s.x;
                ax.XTickLabel = s.x;
                ax.TickLength = [0 0];
                ax.YGrid = 'on';
                ax.Box = 'off';
                xlim([0 length(s.x)+1]);
            end
        end
        
        function s = PosParamStat(varargin)
            % Compute the stats of port distances for each session and optionally make a plot
            %   s = PosParamStat(bv)
            %   s = PosParamStat(bvCell)
            %   s = PosParamStat(ax, ...)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = [];
            end
            
            switch numel(varargin)
                case 1
                    bv = varargin{:};
                otherwise
                    error('Unexpected number of input arguments');
            end
            
            if iscell(bv)
                ss = cellfun(@SL.Behav.PosParamStat, bv);
                s.x = cumsum(cat(1, ss.x));
                s.mean = cat(1, ss.mean);
                s.std = cat(1, ss.std);
                s.sem = cat(1, ss.sem);
                s.ci = cat(1, ss.ci);
            else
                s.x = 1;
                [s.mean, s.std, s.sem, s.ci] = MMath.MeanStats([bv.distX, bv.distY]);
                s.ci = permute(s.ci, [3 2 1]);
            end
            
            if ~isempty(ax)
                errorbar(s.x, s.mean, s.mean-s.ci(:,1), s.ci(:,2)-s.mean, 'ko-');
                xlabel('Session');
                ylabel('Inter-trial interval (s)');
                title('Level of impulsive licking');
                ax.XTick = s.x;
                ax.XTickLabel = s.x;
                ax.TickLength = [0 0];
                ax.Box = 'off';
                xlim([0 length(s.x)+1]);
                grid on
            end
        end
        
        function s = InterTrialIntervalStat(varargin)
            % Compute the stats of intertrial interval duration (from water delivery to next cue), 
            % and optionally make a plot
            %   s = InterTrialIntervalStat(bt, tRef)
            %   s = InterTrialIntervalStat(ax, bt, tRef)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = [];
            end
            
            switch numel(varargin)
                case 2
                    [bt, tRef] = varargin{:};
                otherwise
                    error('Unexpected number of input arguments');
            end
            
            if iscell(bt)
                ss = cellfun(@SL.Behav.InterTrialIntervalStat, bt, tRef);
                s.x = cumsum([ss.x]');
                s.mean = [ss.mean]';
                s.std = [ss.std]';
                s.sem = [ss.sem]';
                s.ci = cat(1, ss.ci);
            else
                iti = diff(tRef) - bt.water(1:end-1) - 2;
                s.x = 1;
                [s.mean, s.std, s.sem, s.ci] = MMath.MeanStats(iti);
                s.ci = s.ci';
            end
            
            if ~isempty(ax)
                errorbar(s.x, s.mean, s.mean-s.ci(:,1), s.ci(:,2)-s.mean, 'ko-');
                xlabel('Session');
                ylabel('Inter-trial interval (s)');
                title('Level of impulsive licking');
                ax.XTick = s.x;
                ax.XTickLabel = s.x;
                ax.TickLength = [0 0];
                ax.Box = 'off';
                xlim([0 length(s.x)+1]);
                grid on
            end
        end
        
        function s = ImpulsiveLickStat(bt)
            % Compute the stats of impulsive licking
            %   s = ImpulsiveLickStat(bt)
            
            if iscell(bt)
                ss = cellfun(@SL.Behav.ImpulsiveLickStat, bt);
                s.x = cumsum([ss.x]');
                s.median = [ss.median]';
                s.prct25 = [ss.prct25]';
                s.prct75 = [ss.prct75]';
                s.mean = [ss.mean]';
                s.std = [ss.std]';
                s.sem = [ss.sem]';
                s.ci = cat(1, ss.ci);
            else
                nLicks = cellfun(@(x,y) sum(x > y+2.1), bt.lickOn, num2cell(bt.water)); % 0.1 water delivery + 2s drink time
                s.x = 1;
                [s.median, qt, s.ad] = MMath.MedianStats(nLicks);
                s.prct25 = qt(1);
                s.prct75 = qt(2);
                [s.mean, s.std, s.sem, s.ci] = MMath.MeanStats(nLicks, 1, 'IsOutlierArgs', 'quartiles');
                s.ci = s.ci';
            end
        end
        
        function s = FirstDriveStat(varargin)
            % Compute the stats of the time to first drive/touch, and optionally make a plot
            %   s = FirstDriveStat(bt)
            %   s = FirstDriveStat(ax, bt)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = [];
            end
            
            switch numel(varargin)
                case 1
                    bt = varargin{:};
                otherwise
                    error('Unexpected number of input arguments');
            end
            
            if iscell(bt)
                ss = cellfun(@SL.Behav.FirstDriveStat, bt);
                s.x = cumsum([ss.x]');
                s.median = [ss.median]';
                s.prct25 = [ss.prct25]';
                s.prct75 = [ss.prct75]';
                s.mean = [ss.mean]';
                s.std = [ss.std]';
                s.sem = [ss.sem]';
                s.ci = cat(1, ss.ci);
            else
                tDr1 = cellfun(@(x) x(1), bt.posIndex);
                s.x = 1;
                [s.median, qt, s.ad] = MMath.MedianStats(tDr1);
                s.prct25 = qt(1);
                s.prct75 = qt(2);
                [s.mean, s.std, s.sem, s.ci] = MMath.MeanStats(tDr1, 1, 'IsOutlierArgs', 'quartiles');
                s.ci = s.ci';
            end
            
            if ~isempty(ax)
%                 errorbar(s.x, s.median*1e3, (s.median-s.prct25)*1e3, (s.prct75-s.median)*1e3, 'ko--'); hold on
                errorbar(s.x, s.mean*1e3, (s.mean-s.ci(:,1))*1e3, (s.ci(:,2)-s.mean)*1e3, 'ko-');
                ax.YScale = 'log';
                grid on
                ax.XTick = s.x;
                ax.XTickLabel = s.x;
                ax.YTick = 10.^(0:3) * 100;
                ax.TickLength(1) = 0;
                ax.Box = 'off';
                xlim([0 length(s.x)+1]);
                ylim([100 2e4]);
                xlabel('Session');
                ylabel('Time from cue onset (ms)');
            end
        end
        
        function s = SeqDurStat(varargin)
            % Compute the stats of sequence or subsequence duration for each session, and optionally make a plot
            %   s = SeqDurStat(bt)
            %   s = SeqDurStat(bt, itvl)
            %   s = SeqDurStat(ax, ...)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = [];
            end
            
            switch numel(varargin)
                case 1
                    bt = varargin{:};
                    itvl = [1 Inf];
                case 2
                    [bt, itvl] = varargin{:};
                otherwise
                    error('Unexpected number of input arguments');
            end
            
            if iscell(bt)
                ss = cellfun(@(x) SL.Behav.SeqDurStat(x, itvl), bt);
                s.x = cumsum([ss.x]');
                s.median = [ss.median]';
                s.prct25 = [ss.prct25]';
                s.prct75 = [ss.prct75]';
                s.mean = [ss.mean]';
                s.std = [ss.std]';
                s.sem = [ss.sem]';
                s.ci = cat(1, ss.ci);
            else
                s.x = 1;
                if itvl(2) == Inf
                    seqDur = cellfun(@(x,y) y - x(1), bt.posIndex, num2cell(bt.waterTrig));
                else
                    seqDur = cellfun(@(x) x(itvl(2)) - x(itvl(1)), bt.posIndex);
                end
                [s.median, qt, s.ad] = MMath.MedianStats(seqDur);
                s.prct25 = qt(1);
                s.prct75 = qt(2);
                [s.mean, s.std, s.sem, s.ci] = MMath.MeanStats(seqDur, 1, 'IsOutlierArgs', 'quartiles');
                s.ci = s.ci';
            end
            
            if ~isempty(ax)
%                 errorbar(s.x, s.median*1e3, (s.median-s.prct25)*1e3, (s.prct75-s.median)*1e3, 'ko--'); hold on
                errorbar(s.x, s.mean*1e3, (s.mean-s.ci(:,1))*1e3, (s.ci(:,2)-s.mean)*1e3, 'ko-');
                ax.YScale = 'log';
                ax.XTick = s.x;
                ax.XTickLabel = s.x;
                ax.YTick = 10.^(0:3) * 100;
                MPlot.Axes(ax);
                grid on
%                 xlim([0 length(s.x)+1]);
                ylim([700 2e4]);
                xlabel('Session');
                ylabel('Duration (ms)');
            end
        end
        
        function s = SeqSpeedStat(varargin)
            % Compute the stats of licking speed for each session, and optionally make a plot
            %   s = SeqSpeedStat(bt)
            %   s = SeqSpeedStat(bt, itvl)
            %   s = SeqSpeedStat(ax, ...)
            
            switch numel(varargin)
                case 1
                    bt = varargin{:};
                    itvl = [1 Inf];
                case 2
                    [bt, itvl] = varargin{:};
                otherwise
                    error('Unexpected number of input arguments');
            end
            
            if iscell(bt)
                ss = cellfun(@(x) SL.Behav.SeqSpeedStat(x, itvl), bt);
                s.x = cumsum([ss.x]');
                s.median = [ss.median]';
                s.prct25 = [ss.prct25]';
                s.prct75 = [ss.prct75]';
                s.mean = [ss.mean]';
                s.std = [ss.std]';
                s.sem = [ss.sem]';
                s.ci = cat(1, ss.ci);
            else
                s.x = 1;
                if itvl(2) == Inf
                    seqDur = cellfun(@(x,y) y - x(1), bt.posIndex, num2cell(bt.waterTrig));
                else
                    seqDur = cellfun(@(x) x(itvl(2)) - x(itvl(1)), bt.posIndex);
                end
                [s.median, qt, s.ad] = MMath.MedianStats(seqDur);
                s.prct25 = qt(1);
                s.prct75 = qt(2);
                [s.mean, s.std, s.sem, s.ci] = MMath.MeanStats(seqDur, 1, 'IsOutlierArgs', 'quartiles');
                s.ci = s.ci';
            end
        end
        
        function s = SeqMissStat(varargin)
            % Compute the stats of missed licks for each session, and optionally make a plot
            %   s = SeqMissStat(bt)
            %   s = SeqMissStat(bt, itvl)
            %   s = SeqMissStat(ax, ...)
            
            if isa(varargin{1}, 'matlab.graphics.axis.Axes')
                ax = varargin{1};
                varargin(1) = [];
            else
                ax = [];
            end
            
            switch numel(varargin)
                case 1
                    bt = varargin{:};
                    itvl = [1 Inf];
                case 2
                    [bt, itvl] = varargin{:};
                otherwise
                    error('Unexpected number of input arguments');
            end
            
            if iscell(bt)
                ss = cellfun(@(x) SL.Behav.SeqMissStat(x, itvl), bt);
                s.x = cumsum([ss.x]');
                s.median = [ss.median]';
                s.prct25 = [ss.prct25]';
                s.prct75 = [ss.prct75]';
                s.mean = [ss.mean]';
                s.std = [ss.std]';
                s.sem = [ss.sem]';
                s.ci = cat(1, ss.ci);
            else
                s.x = 1;
                tPos = cellfun(@(x,y) [x; y], bt.posIndex, num2cell(bt.waterTrig), 'Uni', false);
                nMiss = cellfun(@(x,y) sum(y > x(itvl(1)) & y < x(min(end,itvl(2)))), tPos, bt.airOn);
                nMiss = nMiss - 1; % because the redefined airOn contains both touch and miss
                nMiss(nMiss < 0) = 0;
                [s.median, qt, s.ad] = MMath.MedianStats(nMiss);
                s.prct25 = qt(1);
                s.prct75 = qt(2);
                [s.mean, s.std, s.sem, s.ci] = MMath.MeanStats(nMiss, 1, 'IsOutlierArgs', 'quartiles');
                s.ci = s.ci';
            end
            
            if ~isempty(ax)
%                 errorbar(s.x, s.median, s.median-s.prct25, s.prct75-s.median, 'ko-');
                errorbar(s.x, s.mean, s.mean-s.ci(:,1), s.ci(:,2)-s.mean, 'ko-');
                grid on
                ax.XTick = s.x;
                ax.XTickLabel = s.x;
                ax.TickLength(1) = 0;
                ax.Box = 'off';
                xlim([0 length(s.x)+1]);
                xlabel('Session');
                ylabel('Count');
            end
        end
        
        function s = FirstDriveRunAvg(bt, bv, winSize)
            % Compute a running average of the time to first drive/touch
            %   s = FirstDriveRunAvg(bt, bv)
            %   s = FirstDriveRunAvg(bt, bv, winSize)
            
            if ~exist('winSize', 'var')
                winSize = 9;
            end
            
            tPos0 = cellfun(@(x) x(1), bt.posIndex);
            tPos0S = medfilt1(tPos0, winSize);
            
            s.x = bv.trialNum;
            s.tPos0 = tPos0;
            s.tPos0S = tPos0S;
            s.winSize = winSize;
        end
        
        function s = SeqDurRunAvg(bt, bv, winSize)
            % Compute a running average of sequence duration
            %   s = SeqDurRunAvg(bt, bv)
            %   s = SeqDurRunAvg(bt, bv, winSize)
            
            if ~exist('winSize', 'var')
                winSize = 9;
            end
            
            seqDur = cellfun(@(x,y) y - x(1), bt.posIndex, num2cell(bt.waterTrig));
%             seqDur = cellfun(@(x) x(end) - x(1), bt.posIndex);
            seqDurS = medfilt1(seqDur, winSize);
            
            s.x = bv.trialNum;
            s.seqDur = seqDur;
            s.seqDurS = seqDurS;
            s.winSize = winSize;
        end
        
        function s = NolickRunAvg(bv, winSize)
            % Compute a running average of no-lick ITI
            %   s = NolickRunAvg(bt)
            %   s = NolickRunAvg(bt, winSize)
            
            if ~exist('winSize', 'var')
                winSize = 9;
            end
            
            % nolickITI cloumn was not added to se before 11/26/2021
            if ismember('nolickITI', bv.Properties.VariableNames)
                nolick = bv.nolickITI;
            else
                nolick = NaN(height(bv), 1);
            end
            nolickS = medfilt1(nolick, winSize);
            
            s.x = bv.trialNum;
            s.nolick = nolick;
            s.nolickS = nolickS;
            s.winSize = winSize;
        end
        
        function s = FirstDriveCDF(bt)
            % Compute CDF of the time to first drive/touch for a session
            %   s = FirstDriveCDF(bt)
            tPos0 = cellfun(@(x) x(1), bt.posIndex);
            tEdges = [10.^(2:0.1:4)*1e-3, Inf];
            N = histcounts(tPos0, tEdges, 'Normalization', 'cdf');
            s.tEdges = tEdges;
            s.N = N;
        end
        
        function s = SeqDurCDF(bt)
            % Compute CDF of sequence duration for a session
            %   s = FirstDriveCDF(bt)
            seqDur = cellfun(@(x,y) y - x(1), bt.posIndex, num2cell(bt.waterTrig));
%             seqDur = cellfun(@(x) x(end) - x(1), bt.posIndex);
            tEdges = [10.^(2.7:0.05:4)*1e-3, Inf];
            N = histcounts(seqDur, tEdges, 'Normalization', 'cdf');
            s.tEdges = tEdges;
            s.N = N;
        end
        
        function s = NolickCDF(bv)
            % Compute CDF of the noLick ITI for a session
            %   s = FirstDriveCDF(bt)
            
            tEdges = [10.^(3:0.05:4), Inf];
            
            % nolickITI cloumn was not added to se before 11/26/2021
            if ismember('nolickITI', bv.Properties.VariableNames)
                N = histcounts(bv.nolickITI, tEdges, 'Normalization', 'cdf');
            else
                N = NaN(numel(tEdges)-1, 1);
            end
            
            s.tEdges = tEdges;
            s.N = N;
        end
        
        function s = IDIHist(bt)
            % Compute histogram of interdrive interval
            %   s = IDIHist(bt)
            IDI = cellfun(@(x,y) diff([x; y]), bt.posIndex, num2cell(bt.waterTrig), 'Uni' ,false);
            IDI = cell2mat(IDI);
            binSize = 0.02;
            tEdges = -binSize/2 : binSize : 1+binSize/2;
            s.tEdges = tEdges;
            s.N = histcounts(min(IDI,1), tEdges, 'Normalization', 'probability');
        end
        
        function P = ResamplePosition(varargin)
            
            if isa(varargin{1}, 'MSessionExplorer')
                [se, tEdges] = varargin{1:2};
                [bt, bv] = se.GetTable('behavTime', 'behavValue');
                varargin(1:2) = [];
            elseif istable(varargin{1}) && istable(varargin{2})
                [bt, bv, tEdges] = varargin{1:3};
                varargin(1:3) = [];
            else
                error('Wrong input arguments');
            end
            tq = tEdges(1:end-1) + diff(tEdges)/2;
            tq = tq(:);
            
            p = inputParser;
            p.addOptional('isInvert', false);
            p.addOptional('isMono', false);
            p.parse(varargin{:});
            isInvert = p.Results.isInvert;
            isMono = p.Results.isMono;
            
            P = cell(height(bt),1);
            for i = 1 : height(bv)
                % Find drive times
%                 t = [tq(1); bt.posIndex{i}; bt.waterTrig(i)];
                t = [tq(1); bt.posIndex{i}];
                
                % Find drive positions
                ind = bv.posIndex{i};
                isLR = ind(1) > ind(end);
                if isLR
                    ind = 6 - ind;
                end
                ind = [ind(1)-1; ind];
                
                % Ignore non-monotonic change
                if isMono
                    ind = cummax(ind);
                end
                
                % Interpolation
                P{i} = interp1(t, ind, tq, 'previous', 'extrap');
                
                % Inverting back
                if isLR && ~isInvert
                    P{i} = 6 - P{i};
                end
                
                % Convert to 1 based
                P{i} = P{i} + 1;
            end
        end
        
        function bv = AddBreakInfo(se, isAdd2SE)
            % Get information about sequence breaks. The following columns will be added to behavValue table
            %   breakStep               The steps after which a break occurs. The starting position is 
            %                           defined as step 1. Drive licks belong to the step being licked at.
            %   breakLen                The number of licks emitted during each break.
            %   preBreakLicks           Lick objects for licks that immediately preceed each break.
            %   firstBreakStep, firstBreakLen, firstPreBreakLick
            %                           The first element of the three above, respectively.
            
            if ~exist('isAdd2SE', 'var')
                isAdd2SE = true;
            end
            
            [bt, bv] = se.GetTable('behavTime', 'behavValue');
            
            for i = height(bt) : -1 : 1
                % Convert position indices to the number of steps traveled
                lickObjs = bt.lickObj{i};
                posInd = [lickObjs.portPos];
                stepInc = abs([0 diff(posInd)]);
                nSteps = cumsum(stepInc) + 1; % +1 to convert to one-based
                if any(nSteps > 13)
                    warning('Epoch %i may have abnormal transitions', i);
                    disp(nSteps);
                    nSteps = min(nSteps, 13);
                end
                
                % Number of licks spent at each step
                stepLicks = accumarray(nSteps', 1)'; % first input must be positive integers and in a column
                stepLicks(1) = 1; % ignore air licks before the first drive
%                 stepLicks(end) = 1; % ignore licks at destination
                
                % Find breaks
                bkStep = find(stepLicks > 1); % at which steps do breaks happen (one-based)
                bkLen = stepLicks(bkStep);
                preBkLicks = repmat(SL.Lick, size(bkStep));
                for j = 1 : numel(preBkLicks)
                    k = find(nSteps == bkStep(j)-1, 1); % -1 again to take the last successful lick
                    preBkLicks(j) = lickObjs(k);
                end
                
                % Save to bkTb
                if isempty(bkStep)
                    bkStep = NaN;
                    bkLen = NaN;
                    preBkLicks = SL.Lick();
                end
                bv.breakStep{i} = bkStep';
                bv.breakLen{i} = bkLen';
                bv.preBreakLicks{i} = preBkLicks';
            end
            
            % First break
            bv.firstBreakStep = cellfun(@(x) x(1), bv.breakStep);
            bv.firstBreakLen = cellfun(@(x) x(1), bv.breakLen);
            bv.firstPreBreakLick = cellfun(@(x) x(1), bv.preBreakLicks);
            
            % Output results
            if isAdd2SE
                se.SetTable('behavValue', bv);
            end
        end
        
        function posNames = TranslatePosInd(posInd, seqType)
            % Convert position indices to position names
            posChar = char(posInd);
            posChar = num2cell(posChar);
            switch seqType
                case 'S'
                    dictInd = num2cell('0123456');
                    dictNames = {'R3', 'R2', 'R1', 'M', 'L1', 'L2', 'L3'};
                case 'Z'
                    dictInd = num2cell('01234');
                    dictNames = {'R2', 'R1', 'M', 'L1', 'L2'};
                otherwise
                    error('%s is not a valid sequence type');
            end
            posNames = cellfun(@(x) replace(x, dictInd, dictNames), posChar, 'Uni', false);
        end
        
        % Control experiments
        function s = ControlStats(se, statName)
            % Compute stats for behavioral control experiments (excluding numbing)
            
            switch statName
                case 'pre_seq_time'
                    [t, val] = SL.Behav.PreSeqTimeOverTrials(se);
                case 'pre_seq_miss'
                    [t, val] = SL.Behav.PreSeqMissOverTrials(se);
                case 'seq_miss'
                    [t, val] = SL.Behav.SeqMissOverTrials(se);
                otherwise
                    error('''%s'' is not a valid statType', statName);
            end
            
            s.t = t;
            s.sample = val;
            [s.mean, s.sd, ~, s.ci] = MMath.MeanStats(val);
            [s.median, s.qt, s.ad] = MMath.MedianStats(val);
        end
        
        function [t, nMiss] = SeqMissOverTrials(se)
            % Find the number of misses during sequence for each trial with global time
            
            % Return placeholders if se is empty
            if se.numEpochs == 0
                t = NaN;
                nMiss = NaN;
                return
            end
            
            % Exclude the last trial
            se = se.Duplicate;
            se.RemoveEpochs(se.numEpochs);
            
            % Find global reference times wrt the first trial
            ref = se.GetReferenceTime();
            t = ref' - ref(1);
            
            % Find the number of misses and mean seq time
            bt = se.GetTable('behavTime');
            for i = se.numEpochs : -1 : 1
                tPos = [bt.posIndex{i}; bt.waterTrig(i)];
                if any(isnan(tPos)) || tPos(end) > 10
                    % Use NaN if animal didn't perfom during HSV
                    nMiss(i) = NaN;
                else
                    tAirOn = bt.airOn{i};
                    nMiss(i) = sum(tAirOn > tPos(1) & tAirOn < tPos(end));
                end
            end
        end
        
        function [t, nMiss] = PreSeqMissOverTrials(se)
            % Find the number of misses before first touch for each trial with global time
            
            % Return placeholders if se is empty
            if se.numEpochs == 0
                t = NaN;
                nMiss = NaN;
                return
            end
            
            % Exclude the last trial
            se = se.Duplicate;
            se.RemoveEpochs(se.numEpochs);
            
            % Find global reference times wrt the first trial
            ref = se.GetReferenceTime();
            t = ref' - ref(1);
            
            % Find the number of misses and mean seq time
            bt = se.GetTable('behavTime');
            for i = se.numEpochs : -1 : 1
                tPos = bt.posIndex{i}(1);
                if isnan(tPos) || tPos > 10
                    % Use NaN if animal didn't start during HSV
                    nMiss(i) = NaN;
                else
                    nMiss(i) = sum(bt.airOn{i} < tPos);
                end
            end
        end
        
        function [t, dur] = PreSeqTimeOverTrials(se)
            % Compute the duration before first touch for each trial with global time
            
            % Return placeholders if se is empty
            if se.numEpochs == 0
                t = NaN;
                dur = NaN;
                return
            end
            
            % Exclude the last trial
            se = se.Duplicate;
            se.RemoveEpochs(se.numEpochs);
            
            % Find global reference times wrt the first trial
            ref = se.GetReferenceTime();
            t = ref' - ref(1);
            
            % Find the number of misses and mean seq time
            bt = se.GetTable('behavTime');
            dur = cellfun(@(x) x(1), bt.posIndex)';
        end
    end
end

