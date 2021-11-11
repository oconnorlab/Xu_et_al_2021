classdef Learn
    %LEARN Summary of this class goes here
    %   Detailed explanation goes here
    
    methods(Static)
        function ss = ComputeLearningCurves(seArray, ops)
            
            if ~exist('ops', 'var')
                ops.maxTrials = [];
                ops.binSize = [];
                ops.transRange = 4:5;
                ops.analysisNames = {'numTrials', 'posParam', 'firstDrive', 'ITI', ...
                    'seqDur_S', 'seqDur_B', 'transDur_S', 'transDur_B', 'transMiss_S', 'transMiss_B'};
            end
            
            % Get metadata
%             ss.sessionInfo = arrayfun(@(x) x.userData.sessionInfo, seArray, 'Uni', false);
            ss.sessionInfo.animalId = seArray(1).userData.sessionInfo.animalId;
            ss.sessionInfo.sessionDatetime = arrayfun(@(x) x.userData.sessionInfo.sessionDatetime, seArray);
            ss.sessionInfo.sessionId = arrayfun(@(x) SL.SE.GetID(x), seArray, 'Uni', false);
            
            if isempty(ops.binSize)
                % Keep sessions separate
                [bts, bvs] = arrayfun(@(x) x.GetTable('behavTime', 'behavValue'), seArray, 'Uni', false);
                tRefs = arrayfun(@(x) x.GetReferenceTime(), seArray, 'Uni', false);
                
            else
                % Reslice sessions
                
                % Merge SEs
                se = seArray(1).Merge(seArray(2:end));
                bt = se.GetTable('behavTime');
                bv = se.GetTable('behavValue');
                tRefCat = se.GetReferenceTime('behavTime');
                
                % Split tables
                bsz = round(ops.binSize/2);
                binCenters = 1 : bsz : ops.maxTrials;
                rangeInd = [binCenters' binCenters'] + [-bsz bsz-1];
                rangeInd = MMath.Bound(rangeInd, [1 Inf]);
                nBins = size(rangeInd,1);
                bts = cell(nBins,1);
                bvs = cell(nBins,1);
                tRefs = cell(nBins,1);
                for i = 1 : nBins
                    binInd = rangeInd(i,1) : rangeInd(i,2);
                    bts{i} = bt(binInd,:);
                    bvs{i} = bv(binInd,:);
                    tRefs{i} = tRefCat(binInd);
                end
                
                ss.binCenters = binCenters;
            end
            
            % 
            for k = 1 : numel(ops.analysisNames)
                % Parse analysis name
                nameParts = strsplit(ops.analysisNames{k}, '_');
                quantName = nameParts{1};
                if numel(nameParts) == 1
                    selectionStr = '';
                else
                    selectionStr = nameParts{2};
                end
                
                % Select trials
                btsSelect = getSubTables(bts, bvs, selectionStr);
                
                % Compute stats
                switch quantName
                    case 'numTrials'
                        s = SL.Behav.TrialNumStat(seArray);
                    case 'posParam'
                        s = SL.Behav.PosParamStat(bvs);
                    case 'firstDrive'
                        s = SL.Behav.FirstDriveStat(btsSelect);
                    case 'ITI'
                        s = SL.Behav.InterTrialIntervalStat(bts, tRefs);
                    case 'impulseLick'
                        s = SL.Behav.ImpulsiveLickStat(btsSelect);
                    case 'seqDur'
                        s = SL.Behav.SeqDurStat(btsSelect);
                    case 'transDur'
                        s = SL.Behav.SeqDurStat(btsSelect, ops.transRange);
                    case 'transMiss'
                        s = SL.Behav.SeqMissStat(btsSelect, ops.transRange);
                end
                ss.(ops.analysisNames{k}) = s;
            end
            
            % Helper function
            function [bts, bvs] = getSubTables(bts, bvs, selectionStr)
                
                if isempty(selectionStr)
                    return
                end
                
                for n = numel(bvs) : -1 : 1
                    ind = true(height(bvs{n}), 1);
                    
                    % Select by sequence type
                    if ismember('B', selectionStr)
                        ind = ind & ismember(bvs{n}.seqId, {'1231456', '5435210'});
                    elseif ismember('S', selectionStr)
                        ind = ind & ismember(bvs{n}.seqId, {'123456', '543210'});
                    end
                    
                    % Select by sequence direction
                    if ismember('L', selectionStr)
                        ind = ind & cellfun(@(x) x(1) < x(end), bvs{n}.posIndex); % towards left
                    elseif ismember('R', selectionStr)
                        ind = ind & cellfun(@(x) x(1) > x(end), bvs{n}.posIndex); % towards right
                    end
                    
                    % Select by opto
                    if ismember('N', selectionStr)
                        ind = ind & isnan(bvs{n}.opto);
                    end
                    
                    % Make selection
                    bts{n} = bts{n}(ind,:);
                    bvs{n} = bvs{n}(ind,:);
                end
            end
            
        end
        
        function FormatLearningCurveAxes(ax, x)
            % 
            d = diff(x(1:2));
            MPlot.Axes(ax);
            ax.XLim = [min(x) max(x)] + [-1 1]*d;
            ax.XTick = 0:d*10:max(x)+d;
            ax.XTickLabel = ax.XTick;
            xlabel('# of trials');
        end
        
        function s = PrepareConsecutiveTrialsData(se)
            %
            
            % Re-stamp reference times to make it monotonically increasing
            se = se.Duplicate;
            tRef = se.GetReferenceTime();
            dtRef = diff(tRef);
            tGap = 1e5; % time gap between sessions in second
            dtRef(dtRef < 0 | dtRef > tGap) = tGap;
            tRef = [0; cumsum(dtRef)];
            se.SetReferenceTime(tRef);
            
            % Get data tables
            bv = se.GetTable('behavValue');
            se.SliceSession(0, 'absolute');
            bt = se.GetTable('behavTime');
            
            % Cue
            tCue = bt.cue{1};
            trialIdx = (1:numel(tCue))';
            
            % Port position
            posTime = bt.posIndex{1};
            [posTime, I] = unique(posTime); % duplicates found in MX170903 2018-02-16
            posTime = [posTime posTime([2:end end])]';
            posTime = posTime(:);
            
            posVal = cell2mat(bv.posIndex);
            posVal = posVal(I,[1 1])';
            posVal = posVal(:);
            
            % Lick
            lickTime = bt.lickOn{1};
            lickPos = interp1(posTime(1:2:end), posVal(1:2:end), lickTime);
            lickPos(lickPos > 5) = 6;
            lickPos(lickPos < 1) = 0;
            
%             % Limit samples in time window
%             [tCue, I] = LimitRange(tCue);
%             trialIdx = trialIdx(I);
%             [posTime, I] = LimitRange(posTime);
%             posVal = posVal(I);
%             [lickTime, I] = LimitRange(lickTime);
%             lickPos = lickPos(I);
%             
%             function [t, ind] = LimitRange(t)
%                 ind = t >= tWin(1) & t <= tWin(2);
%                 t = t(ind);
%             end
            
            % Output
            s.tCue = tCue;
            s.trialIdx = trialIdx;
            s.posTime = posTime;
            s.posVal = posVal;
            s.lickTime = lickTime;
            s.lickPos = lickPos;
        end
        
        function PlotConsecutiveTrials(s, trialStart, dur)
            % 
            
            tCue = s.tCue;
            posTime = s.posTime;
            posVal = s.posVal;
            lickTime = s.lickTime;
            lickPos = s.lickPos;
            
            tWin = [tCue(trialStart) tCue(trialStart)+dur];
            
            plot(posTime, posVal, '-', 'Color', 'k'); hold on
            plot(lickTime, lickPos, '.', 'Color', 'k');
            SL.ITI.FormatExampleAxes(tWin, tCue);
        end
        
        function HighlightExamples(x, y, trialStarts)
            % 
            for i = 1 : numel(trialStarts)
                [~, I] = min(abs(x - trialStarts(i)));
                plot(x(I), y(I), 'r*');
            end
        end
    end
end

