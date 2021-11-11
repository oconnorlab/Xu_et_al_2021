classdef ZZ
    properties(Constant)
        matchWin = [-1 1];
        claWin = [-.25 .25];
        claBinSize = 0.005;
    end
    
    methods(Static)
        % Processing functions
        function MakeSeTable()
            % A wrapper of SL.SE.Transform that tansforms SE and save seTb 
            % using options customized for analyzing zigzag sequence
            
            % Find se files
            dataSource = SL.Data.FindSessions('figZ_seq_coding');
            
            % Metadata
            xlsTb = MBrowse.ReadXls(SL.Data.metadataSheet, 'Si');
            
            % Set up options
            ops = SL.Param.Transform;
            ops.isOverwrite = false;
            ops.isMorph = true;
            ops.lickTimeType = 'mid';
            ops.tReslice = -2;
            ops.maxReactionTime = Inf;
            ops.maxEndTime = 8;
            ops.alignType = 'seq_zz';
            ops.isMatch = true;
            ops.matchWin = [-1 1];
            ops.fracTrials = 1/3;
            ops.algorithm = @SL.Match.AlgorithmZ;
            
            % Process each session
            for i = 1 : height(dataSource)
                % Get paths
                seDir = dataSource.folder{i};
                seName = dataSource.name{i};
                sessionId = SL.SE.GetID(seName);
                
                seTbDir = fullfile(seDir, 'seq_zz dt_0');
                if ~exist(seTbDir, 'dir')
                    mkdir(seTbDir);
                end
                
                seTbPath = fullfile(seTbDir, ['seTb ' sessionId '.mat']);
                if exist(seTbPath, 'file') && ~ops.isOverwrite
                    warning('seTb for %s already exists and will not be overwritten', sessionId);
                    continue
                end
                
                % Load SE
                disp(['Making seTb for ' sessionId]);
                se = SL.SE.LoadSession(fullfile(seDir, seName));
                SL.SE.AddXlsInfo2SE(se, xlsTb);
                
                % Screen units
                SL.Unit.RemoveOffTargetUnits(se, se.userData.xlsInfo.area);
                
                % Transform SE
                seTb = SL.SE.Transform(se, ops);
                
                % Add theta_shoot to hsv table
                SL.ZZ.AddThetaShoot2HSV(seTb.se, ops);
                
                % Prune trials
                seTb = SL.ZZ.PruneTrials(seTb, ops);
                
                % Save seTb
                disp(['Saving seTb for ' sessionId]);
                save(seTbPath, 'seTb', 'ops');
                disp(' ');
            end
        end
        
        function AddThetaShoot2HSV(seArray, ops)
            % Convert theta_shoot in lickObj to time series in hsv table
            
            for i = 1 : numel(seArray)
                % Extract theta_shoot and time from licks
                [bt, hsv] = seArray(i).GetTable('behavTime', 'hsv');
                [theta_shoot, ~, time_shoot] = cellfun(@(x) x(x.IsTracked).ShootingAngle, bt.lickObj, 'Uni', false);
                
                % Interpolate theta_shoot and save it to hsv table
                hsv.theta_shoot = cellfun(@(x,v,xq) interp1(x, v, xq, 'linear', 0), ...
                    time_shoot, theta_shoot, hsv.time, 'Uni', false);
                seArray(i).SetTable('hsv', hsv);
            end
        end
        
        function seTb = PruneTrials(seTb, ops)
            % Remove trials that have most distinguishing theta_shoot
            
            % Shift seTb
            seTbSft = SL.ZZ.ShiftSeTb(seTb);
            
            % Set parameters
            ops = SL.Param.Resample(ops);
            ops.hsvVars = {'theta_shoot'};
            ops.adcVars = {};
            ops.valVars = {};
            ops.derivedVars = {};
            ops.rsWin = [-.3 .3];
            ops.rsBinSize = 0.015;
%             ops.claVars = ops.hsvVars;
%             ops.alpha = 0.05;
            
            % Extract theta_shoot
            nShifts = numel(seTbSft);
            ang = cell(1, nShifts);
            for i = 1 : nShifts
                seMerge = seTbSft{i}.se.Merge();
                ang{i} = SL.SE.GetStimArray(seMerge, ops);
                ang{i} = permute(ang{i}, [3 1 2]); % => trial-by-time
            end
            
            % Compute loss
            angCat = cat(2, ang{:}); % concatenate along time
            angMed = median(angCat);
            angLoss = mean((angCat - angMed).^2, 2);
            
            ind{1} = 1 : seTb.se(1).numEpochs;
            ind{2} = numel(ind{1}) + (1 : seTb.se(2).numEpochs);
            
            for i = 1 : height(seTb)
                % Determine the number of trials to remove
                nKeep = round(seTb.numTrial(i) * ops.fracTrials);
                nKeep = MMath.Bound(nKeep, [ops.minTrials ops.maxTrials]);
                nRm = seTb.numMatched(i) - nKeep;
                
                % Remove trials with the largest loss
                if nRm > 0
                    L = angLoss(ind{i});
                    [~, I] = sort(L, 'descend');
                    iRm = I(1:nRm);
                    seTb.se(i).RemoveEpochs(iRm);
                end
                
                % Update table info
                seTb.numPerfect(i) = seTb.numMatched(i);
                seTb.numMatched(i) = seTb.se(i).numEpochs;
            end
        end
        
        function seTbSft = ShiftSeTb(seTb, ops)
            % Output four seTbs in a cell array, each with a different shift
            %   ops.rsWin           Time window to compute crosscorrelation
            %   ops.rsBinSize       Controls the temporal resolution
            
            assert(height(seTb) == 2, 'Can only match trials between two SEs');
            if ~exist('ops', 'var')
                ops = SL.Param.Resample();
                ops.hsvVars = {'tongue_bottom_angle'};
                ops.adcVars = {};
                ops.valVars = {};
                ops.derivedVars = {};
                ops.isFillAng = true;
                ops.dimCombine = [];
                ops.rsWin = [-1 1];
                ops.rsBinSize = SL.Param.minISI;
                ops.rsArgs = {'Method', 'linear', 'Extrap', 'linear'};
            end
            
            % Extract theta_shoot
            ang = cell(size(seTb.se));
            for i = 1 : height(seTb)
                ang{i} = SL.SE.GetStimArray(seTb.se(i), ops);
                ang{i} = permute(ang{i}, [3 2 1]); % to trial-by-time matrix
            end
            
            % Find shifting parameters
            s = SL.ZZ.FindShifts(median(ang{1}), median(ang{2}), ops.rsBinSize);
            
            % Make shifted seTbs
            nShifts = 4;
            seTbSft = cell(nShifts, 1);
            for i = 1 : nShifts
                % Translate shift group index to se index and delta time
                switch i
                    case 1
                        % fix seq1, shift seq2 forward
                        se2shift = 2;
                        dt = s.dt2(1);
                    case 2
                        % fix seq1, shift seq2 backward
                        se2shift = 2;
                        dt = s.dt2(2);
                    case 3
                        % fix seq2, shift seq1 forward
                        se2shift = 1;
                        dt = s.dt1(1);
                    case 4
                        % fix seq2, shift seq1 backward
                        se2shift = 1;
                        dt = s.dt1(2);
                end
                
                % Shift the time in one of the se
                seTbSft{i} = seTb;
                seTbSft{i}.se = seTb.se.Duplicate();
                seTbSft{i}.se(se2shift).AlignTime(-dt);
                
                % Add info to table
                seTbSft{i}.shiftGroup = [i i]';
                seTbSft{i}.tShifted(se2shift) = dt;
            end
        end
        
        function s = FindShifts(a1, a2, binSize)
            % Find indices to shift that provide peak crosscorrelations
            %   a1 and a2 are vectors of lick angle time series
            %   binSize is the duration of a sample
            
            % Make angle continuous
            a1 = fillmissing(a1(:), 'linear');
            a2 = fillmissing(a2(:), 'linear');
            
            % Compute cross-correlation
            [xc, lags] = xcorr(a1, a2, 'coeff');
            lags = lags';
            
            % Find peak xcorr at negative and positive side respectively
            % lags at peak are indices to shift a2 to best match a1, like circshift(a2, lags)
            % positive indices move a2 forward, negative indices move a2 backward
            pkTb = table();
            [pkTb.pks, pkTb.lags, ~, pkTb.prom] = findpeaks(xc, lags);
            
            % Limit peaks in the vicinity of four licks away
            indPerLick = round(1/6.5/binSize);
            ind = abs(pkTb.lags) > indPerLick*3.5 & abs(pkTb.lags) < indPerLick*4.5;
            pkTb = pkTb(ind,:);
            
            % Take highest peak at negative and positive side
            pkTb = sortrows(pkTb, 'prom', 'descend');
            pkTbNeg = pkTb(pkTb.lags<0, :);
            pkTbPos = pkTb(pkTb.lags>=0, :);
            iShift = [pkTbPos.lags(1) pkTbNeg.lags(1)];
            
            % Pack outputs
            s.a1 = a1;
            s.a2 = a2;
            s.xc = xc;
            s.lags = lags;
            s.pkTb = pkTb;
            s.iShift = iShift; % for compatibility
            s.di2 = iShift;             % shift a2 indices by
            s.di1 = -flip(iShift);      % shift a1 indices by
            s.dt2 = s.di2 * binSize;    % shift a2 time by 
            s.dt1 = s.di1 * binSize;    % shift a1 time by
        end
        
        function cTb = ClassifyShiftMatched(seTb, predType, ops)
            % Classify sequence identity in a session after matching behaviors by shifting time
            %   seTb                One row is LR seqs, one row is RL. The size of predictor matrices 
            %                       are time-by-variable-by-trial.
            %   predType            Predictor name. 'pca' or 'stim'
            %   ops.claVars         Behavioral variables to use
            %   ops.alpha           Significance level
            
            if height(seTb) ~= 2
                error('seTb must have and only have two conditions');
            end
            
            if strcmp(predType, 'stim')
                vars = ops.claVars;
                allVars = SL.Param.GetAllResampleVars(ops);
                varInd = SL.Param.FindVarIndices(vars, allVars);
            else
                varInd = ':';
            end
            alpha = ops.alpha;
            
            % Make a classification table
            isFixed = ~seTb.tShifted;
            cTb = seTb(1, {'animalId', 'sessionId'}); % duplicate info from the first row of seTb
            cTb.fixedSeq = seTb.seqId(isFixed);
            cTb.shiftedSeq = seTb.seqId(~isFixed);
            cTb.tShifted = seTb.tShifted(~isFixed);
            
            % Classification
            for i = 1 : height(cTb)
                % Get timestamps
                t = seTb.time{i}(:,:,1);
                
                % Prepare predictors
                x1 = seTb.(predType){1}(:,varInd,:);
                x2 = seTb.(predType){2}(:,varInd,:);
                x1 = permute(x1, [3 2 1]); % to trial-by-variable-by-time
                x2 = permute(x2, [3 2 1]);
                
                % Classify original data
                [r, rCV] = SL.Pop.SVMClassify(x1, x2);
                rStats = [r NaN(numel(r), 2)];
                
                % Classify shuffled data
                nShuf = 100;
                rShuf = zeros(numel(t), nShuf);
                rShufCV = zeros(numel(t), 10, nShuf); % 10 for 10-fold CV
                for j = 1 : nShuf
                    [rShuf(:,j), rShufCV(:,:,j)] = SL.Pop.SVMClassify(x1, x2, 'Shuffle', true);
                end
                rShufMean = mean(rShuf, 2);
                rShufCI = prctile(rShuf, [alpha/2 1-alpha/2]*100, 2);
                rShufStats = [rShufMean rShufCI];
                
                cTb.time{i} = t;
                cTb.x1{i} = x1;
                cTb.x2{i} = x2;
                cTb.r{i} = r;
                cTb.rCV{i} = rCV;
                cTb.rStats{i} = rStats;
                cTb.rShuf{i} = rShuf;
                cTb.rShufCV{i} = rShufCV;
                cTb.rShufStats{i} = rShufStats;
            end
        end
        
        function mClaTb = GroupByConditions(claTbArray)
            % Group classification results by condition
            mClaTb = claTbArray{1}(:, {'fixedSeq', 'shiftedSeq', 'tShifted', 'time'});
            for i = 1 : height(mClaTb)
                cTbRows = cellfun(@(x) x(i,:), claTbArray, 'Uni', false);
                mClaTb.claTb{i} = vertcat(cTbRows{:});
            end
        end
        
        function seTbs = NormalizeSpikeRateXseTbs(seTbs, timeWin, binSize)
            % Normalize spike rate for each unit by the maximum across all seTbs (e.g. seTbSft)
            
            tEdges = timeWin(1) : binSize : timeWin(2);
            
            % Find max spike rate across all conditions
            seTbCat = cat(1, seTbs{:});
            r = arrayfun(@(x) x.ResampleTimeSeries('spikeRate', tEdges), seTbCat.se, 'Uni', false);
            h = cellfun(@(x) MNeuro.MeanTimeSeries(x(:,2:end)), r, 'Uni', false);
            h = cat(1, h{:});
            hMax = max(h);
            hMax = max(hMax, eps);
            
            % Normalize spike rate
            nUnits = numel(hMax);
            for i = 1 : numel(seTbs)
                for j = 1 : height(seTbs{i})
                    for k = 2 : nUnits
                        seTbs{i}.se(j).SetColumn('spikeRate', k, @(x) x./hMax(k-1), 'each');
                    end
                end
            end
        end
        
        
        % Plotting functions
        function ReviewShiftMatching(seTbPaths)
            % Make and save plots of shift-matched sequences in one or more seTb for quality control
            
            % Find files
            if ~exist('seTbPaths', 'var') || isempty(seTbPaths)
                seTbPaths = MBrowse.Files(SL.Data.analysisRoot, 'Select one or more seTb');
            end
            
            % Go through each seTb
            for i = 1 : numel(seTbPaths)
                % Load seTb
                load(seTbPaths{i});
                
                % Shift seTb
                seTbSft = SL.ZZ.ShiftSeTb(seTb);
                
                % Initialize figure
                f = MPlot.Figure(1); clf
                f.WindowState = 'maximized';
                cc = [SL.Param.RLColor .15; SL.Param.LRColor .15];
                nRow = 3;
                nCol = numel(seTbSft);
                tWin = [-1 1];
                
                % Go through each match
                for j = 1 : nCol
                    seTb = seTbSft{j};
                    iShift = find(seTb.tShifted, 1);
                    dt = seTb.tShifted(iShift);
                    nTrials = seTb.numMatched;
                    
                    % Go through each seq
                    for k = 1 : height(seTb)
                        se = seTb.se(k);
%                         [bt, bv, hsv, adc] = se.GetTable('behavTime', 'behavValue', 'hsv', 'adc');
                        hsv = se.GetTable('hsv');
                        
                        ax = subplot(nRow, nCol, j+nCol*0);
                        SL.Match.PlotAngleOverlay(hsv.time, hsv.theta_shoot, 'Color', cc(k,:));
                        hold on
                        ax.XLim = tWin;
                        
                        ax.Title.String = ['seq' num2str(iShift) ' \Delta' num2str(dt) 's' ...
                            ', N = ' num2str(nTrials(1)) ' seq1, ' num2str(nTrials(2)) ' seq2'];
                        
                        ax = subplot(nRow, nCol, j+nCol*1);
                        SL.Match.PlotAngleOverlay(hsv.time, hsv.tongue_bottom_angle, 'Color', cc(k,:));
                        hold on
                        ax.XLim = tWin;
                        
                        ax = subplot(nRow, nCol, j+nCol*2);
                        SL.Match.PlotLengthOverlay(hsv.time, hsv.tongue_bottom_length, 'Color', cc(k,:));
                        hold on
                        ax.XLim = tWin;
                    end
                end
                
                % Save plot
                seTbDir = fileparts(seTbPaths{i});
                print(f, fullfile(seTbDir, ['shift-matching ' seTb.sessionId{1}]), '-dpng', '-r0');
            end
        end
        
        function ReviewUnits(isAuto)
            % Make and save plots for one or more seTbs showing rasters and PETHs of all units along with lick angle
            
            % Find files
            seTbDir = fullfile(SL.Data.analysisRoot, 'Data ephys ZZ', 'seq_zz dt_0');
            
            if exist('isAuto', 'var') && isAuto
                seTbSearch = MBrowse.Dir2Table(fullfile(seTbDir, 'seTb *.mat'));
                seTbPaths = fullfile(seTbSearch.folder, seTbSearch.name);
            else
                [seTbPaths, seTbDir] = MBrowse.Files(seTbDir, 'Select one or more seTb');
            end
            
            % Go through each seTb
            for k = 1 : numel(seTbPaths)
                % Load seTb
                load(seTbPaths{k});
                sessionId = SL.SE.GetID(seTb.se(1));
                nUnits = width(seTb.se(1).GetTable('spikeTime'));
                
                % Make time-shifted seTbs
                seTbSft = SL.ZZ.ShiftSeTb(seTb);
                
                % Plotting
                unitsPerFig = 8; % two halves
                nRow = 1 + unitsPerFig / 2;
                nCol = numel(seTbSft) * 2;
                nFigs = ceil(nUnits / unitsPerFig);
                
                for i = 1 : nFigs
                    f = MPlot.Figure(1); clf
                    f.WindowState = 'maximized';
                    unitInd = (i-1)*unitsPerFig+1 : min(i*unitsPerFig, nUnits);
                    
                    % Lick angle
                    SL.ZZ.PlotAngleForReview([seTbSft; seTbSft], 'GridSize', [nRow nCol]);
                    
                    % Unit responses
                    SL.ZZ.PlotRasterPETHs(seTbSft, unitInd, 'GridSize', [nRow nCol], 'StartPos', [2 1]);
                    
                    % Save figure
                    figDir = fullfile(seTbDir, [seTb.sessionId{1} ' units']);
                    if ~exist([sessionId 'units'], 'dir')
                        mkdir(figDir);
                    end
                    figName = [seTb.sessionId{1} ' unit ' num2str(unitInd(1),' %02i') '-' num2str(unitInd(end),' %02i')];
%                     print(f, fullfile(figDir, figName), '-dpng', '-r0');
                end
            end
        end
        
        function PlotAngleForReview(seTbSft, varargin)
            % Make subplots of lick angle time series for every matching conditions
            %   PlotAngleForReview(seTbSft, 'GridSize', [1 height(claTb)], 'StartPos', [1 1])
            
            p = inputParser();
            p.addParameter('GridSize', [1 numel(seTbSft)], @isvector);
            p.addParameter('StartPos', [1 1], @isvector);
            p.parse(varargin{:});
            nRow = p.Results.GridSize(1);
            nCol = p.Results.GridSize(2);
            iRow = p.Results.StartPos(1);
            iCol = p.Results.StartPos(2);
            
            iBefore = (iRow-1)*nCol + (iCol-1);
            cc = [SL.Param.RLColor; SL.Param.LRColor];
            
            % Plot through each matching condition
            for i = 1 : numel(seTbSft)
                seTb = seTbSft{i};
                iSft = find(seTb.tShifted, 1);
                dt = seTb.tShifted(iSft);
                
                ax = subplot(nRow, nCol, iBefore+i); cla
                for k = 1 : height(seTb)
                    hsv = seTb.se(k).GetTable('hsv');
                    tt = hsv.time;
                    aa = hsv.tongue_bottom_angle;
                    SL.Match.PlotAngleOverlay(tt, aa, 'Color', [cc(k,:) .15]);
                end
                ax.XLim = SL.ZZ.claWin;
                ax.YLim = [-30 30];
                ax.YTick = -45:15:45;
                ax.XGrid = 'on';
                ax.Box = 'off';
                ax.Title.String = ['seq' num2str(iSft) ' \Deltat ' num2str(dt) 's'];
                ax.YLim = [-45 45];
                ax.YGrid = 'on';
                ax.XMinorGrid = 'on';
                ax.XLabel.String = 'Time (s)';
                if i == 1
                    ax.YLabel.String = 'Angle (deg)';
                end
                MPlot.Axes(ax);
            end
        end
        
        function PlotAngleZoomedOut(seTbSft, varargin)
            % Make subplots of lick angle time series for every matching conditions
            %   PlotAngleZoomedOut(seTbSft, 'GridSize', [1 height(claTb)], 'StartPos', [1 1])
            
            p = inputParser();
            p.addParameter('GridSize', [1 numel(seTbSft)], @isvector);
            p.addParameter('StartPos', [1 1], @isvector);
            p.parse(varargin{:});
            nRow = p.Results.GridSize(1);
            nCol = p.Results.GridSize(2);
            iRow = p.Results.StartPos(1);
            iCol = p.Results.StartPos(2);
            iBefore = (iRow-1)*nCol + (iCol-1);
            
            % Configure style options
            tLim = SL.ZZ.matchWin;
            tWin = [-1.7 1.7];
            tBinSize = 0.005;
            tEdges = tWin(1) : tBinSize : tWin(2);
            cc = [SL.Param.RLColor; SL.Param.LRColor];
            
            % Plot through each matching condition
            for i = 1 : numel(seTbSft)
                seTb = seTbSft{i};
                iSft = find(seTb.tShifted, 1);
                dt = seTb.tShifted(iSft);
                
                ax = subplot(nRow, nCol, iBefore+i); cla
                for k = 1 : height(seTb)
                    se = LimitDataRange(seTb.se(k), tLim, seTb.tShifted(k));
                    SL.ZZ.PlotAngleMeanSD(se, tEdges, 'Color', cc(k,:));
                end
                plot([0 dt]', [0 0]', 'Color', cc(iSft,:));
%                 quiver(0, 0, dt, 0, 'Color', cc(iSft,:));
                
                ax.XLim = tWin;
                ax.YLim = [-30 30];
                ax.XTick = SL.ZZ.claWin;
                ax.YTick = -45:15:45;
                ax.XGrid = 'on';
                ax.Box = 'off';
                ax.Title.String = ['seq' num2str(iSft) ' \Deltat ' num2str(dt) 's'];
                if i == 1
                    ax.YLabel.String = 'Angle (deg)';
                end
                MPlot.Axes(ax);
            end
            
            % Helper function
            function se = LimitDataRange(se, tLim, dt)
                se = se.Duplicate({'hsv'}, false);
                tLim = tLim + dt;
                hsv = se.SliceTimeSeries('hsv', tLim);
                se.SetTable('hsv', hsv);
            end
        end
        
        function PlotAngleZoomedIn(seTbSft, varargin)
            % Make subplots of lick angle time series for every matching conditions
            %   PlotAngleZoomedIn(seTbSft, 'GridSize', [1 height(claTb)], 'StartPos', [1 1])
            
            p = inputParser();
            p.addParameter('GridSize', [1 numel(seTbSft)], @isvector);
            p.addParameter('StartPos', [1 1], @isvector);
            p.parse(varargin{:});
            nRow = p.Results.GridSize(1);
            nCol = p.Results.GridSize(2);
            iRow = p.Results.StartPos(1);
            iCol = p.Results.StartPos(2);
            iBefore = (iRow-1)*nCol + (iCol-1);
            
            % Configure style options
            tWin = SL.ZZ.claWin;
            tBinSize = 0.005;
            tEdges = tWin(1) : tBinSize : tWin(2);
            cc = [SL.Param.RLColor; SL.Param.LRColor];
            
            % Plot through each matching condition
            for i = 1 : numel(seTbSft)
                seTb = seTbSft{i};
                iSft = find(seTb.tShifted, 1);
                dt = seTb.tShifted(iSft);
                
                ax = subplot(nRow, nCol, iBefore+i); cla
                for k = 1 : height(seTb)
                    SL.ZZ.PlotAngleMeanSD(seTb.se(k), tEdges, 'Color', cc(k,:));
                end
                ax.XLim = tWin;
                ax.YLim = [-30 30];
                ax.YTick = -45:15:45;
                ax.XGrid = 'on';
                ax.Box = 'off';
                ax.Title.String = ['seq' num2str(iSft) ' \Deltat ' num2str(dt) 's'];
                if i == 1
                    ax.YLabel.String = 'Angle (deg)';
                end
                MPlot.Axes(ax);
            end
        end
        
        function PlotAngleMeanSD(se, tEdges, varargin)
            % Compute and plot mean±sd of lick angle across trials
            hsv = se.ResampleTimeSeries('hsv', tEdges, [], {'tongue_bottom_angle', 'theta_shoot'});
            t = hsv.time{1};
            aa = cat(2, hsv.tongue_bottom_angle{:});
            [m, sd] = MMath.MeanStats(aa, 2);
            fracN = mean(~isnan(aa), 2);
            seg = ~isnan(m) & fracN > .8; % requires a minimal frac of data available
            seg = MMath.Logical2Bounds(seg);
            for n = 1 : size(seg,1)
                I = seg(n,1) : seg(n,2);
                MPlot.ErrorShade(t(I), m(I), sd(I), varargin{:}); hold on
                plot(t(I), m(I), varargin{:});
            end
%             plot(t, fracN*30, 'k');
        end
        
        function PlotRasterPETHs(seTbSft, unitInd, varargin)
            % Make subplots of stacked rasters and PETHs for every matching conditions
            %   PlotRasterPETHs(seTbSft, unitInd, 'GridSize', [numel(unitInd) numel(seTbSft)], 'StartPos', [1 1])
            
            p = inputParser();
            p.addParameter('GridSize', [numel(unitInd) numel(seTbSft)], @isvector);
            p.addParameter('StartPos', [1 1], @isvector);
            p.parse(varargin{:});
            nRow = p.Results.GridSize(1);
            nCol = p.Results.GridSize(2);
            iRow = p.Results.StartPos(1);
            iCol = p.Results.StartPos(2);
            
            iBefore = (iRow-1)*nCol + (iCol-1);
            cc = [SL.Param.RLColor; SL.Param.LRColor];
            tWin = SL.ZZ.claWin;
            tBinSize = SL.ZZ.claBinSize;
            nSft = numel(seTbSft);
            nUnit = numel(unitInd);
            
            % Slice out spike times
            spkSft = cell(size(seTbSft));
            for j = 1 : nSft
                seTb = seTbSft{j};
                nPlot = min([seTb.numMatched; 20]);
                rng(61);
                spkSft{j} = arrayfun( ...
                    @(x,m) x.SliceEventTimes('spikeTime', tWin, randsample(x.numEpochs,nPlot,false), unitInd), ...
                    seTb.se, 'Uni', false);
            end
            
            % Compute PETHs
            ops.rsWin = tWin;
            ops.rsBinSize = tBinSize;
            hTb = cellfun(@(x) SL.Unit.UnitPETH(x.se, ops), seTbSft, 'Uni', false);
            
            % Find peak spike rates across conditions
            hMax = cellfun(@(x) x.peakSpkRate, hTb, 'Uni', false);
            hMax = max(cat(2, hMax{:}), [], 2);
            hMax = max(hMax, eps);
            
            % Make subplots
            iSub = 1;
            for i = 1 : nUnit
                for j = 1 : nSft
                    ax = subplot(nRow, nCol, iBefore+iSub); cla
                    u = unitInd(i);
                    
                    % Spike times
                    spk = spkSft{j};
                    spk = cat(2, spk{1}.(i), spk{2}.(i));
                    SL.UnitFig.PlotRasterStack(spk, cc);
                    
                    % PETH
                    t = hTb{j}.tt1(u,:)';
                    hh = [hTb{j}.hh1(u,:)' hTb{j}.hh2(u,:)'];
                    ee = [hTb{j}.ee1(u,:)' hTb{j}.ee2(u,:)'];
                    hh = hh ./ hMax(u);
                    ee = ee ./ hMax(u);
                    SL.UnitFig.PlotHistOverlay(t, hh, ee, cc, 0.8);
                    
                    if j == 1
                        ax.YLabel.String = ['Unit ' num2str(u)];
                    end
                    ax.XLim = tWin;
                    MPlot.Axes(ax);
                    
                    iSub = iSub + 1;
                end
            end
        end
        
        function PlotCla(claTb, style, varargin)
            % Make subplots of classification accuracy for every matching conditions
            %   SL.ZZ.PlotCla(claTb, style, 'GridSize', [1 height(claTb)], 'StartPos', [1 1])
            
            p = inputParser();
            p.addParameter('GridSize', [1 height(claTb)], @isvector);
            p.addParameter('StartPos', [1 1], @isvector);
            p.parse(varargin{:});
            nRow = p.Results.GridSize(1);
            nCol = p.Results.GridSize(2);
            iRow = p.Results.StartPos(1);
            iCol = p.Results.StartPos(2);
            
            iBefore = (iRow-1)*nCol + (iCol-1);
            
            switch style
                case 'mean'
                    cc = repmat(SL.Param.backColor, [nCol 1]);
                case {'session', 'review'}
                    cc = zeros(nCol, 3);
                otherwise
                    error('''%s'' is not a valid style', style);
            end
            
            for i = 1 : height(claTb)
                x = claTb.time{i};
                y = claTb.rStats{i};
                ys = claTb.rShufStats{i};
                
                ax = subplot(nRow, nCol, iBefore+i); cla
                
                plot(x, y(:,1), 'Color', cc(i,:)); hold on
                MPlot.ErrorShade(x, y(:,1), y(:,2), y(:,3), 'Color', cc(i,:), 'IsRelative', false);
%                 plot(x, ys(:,1), 'Color', [0 0 0]);
                MPlot.ErrorShade(x, ys(:,1), ys(:,2), ys(:,3), 'Color', [0 0 0], 'IsRelative', false);
                
                ax.XLim = x([1 end]);
                ax.YLim = [.5 1];
                ax.YTick = 0 : .1 : 1;
                ax.XGrid = 'on';
                if i == 1
                    ax.YLabel.String = 'Frac. correct';
                end
                switch style
                    case 'review'
                        ax.YLim = [.3 1];
                        ax.YTick = 0 : .2 : 1;
                        ax.XLabel.String = 'Time to mid-seq (s)';
                        iSft = find(claTb.shiftedSeq(i) == SL.Param.zzSeqs, 1);
                        dt = claTb.tShifted(i);
                        ax.Title.String = ['seq' num2str(iSft) ' \Deltat ' num2str(dt) 's'];
                    case {'session', 'mean'}
                        
                end
                MPlot.Axes(ax);
            end
        end
        
        function ReviewCla(isAuto)
            % Plot and save classification reuslts and predictor overlay of matched sequences for each session
            
            % Find files
            datDir = fullfile(SL.Param.GetAnalysisRoot, 'Data Ephys ZZ', 'seq_zz dt_0');
            
            if exist('isAuto', 'var') && isAuto
                stimSearch = MBrowse.Dir2Table(fullfile(datDir, 'cla_stim *.mat'));
                stimPaths = fullfile(stimSearch.folder, stimSearch.name);
            else
                [stimPaths, datDir] = MBrowse.Files(datDir, 'Select one or more cla_stim files');
            end
            
            for k = 1 : numel(stimPaths)
                % Load tables
                sStim = load(stimPaths{k});
                stimTb = sStim.claTb;
                ops = sStim.ops;
                
                pcaPath = strrep(stimPaths{k}, 'stim', 'pca');
                if exist(pcaPath, 'file')
                    sPCA = load(pcaPath);
                    pcaTb = sPCA.claTb;
                end
                
                varNames = SL.Param.GetAllResampleVars(ops);
                varNames = SL.PopFig.RenameVariables(varNames);
                
                f = MPlot.Figure(1); clf
                f.WindowState = 'maximized';
                
                for i = 1 : height(stimTb)
                    t = stimTb.time{i};
                    nRow = numel(varNames) + 2;
                    nCol = height(stimTb);
                    
                    % Plot neural classification
                    if exist(pcaPath, 'file')
                        SL.ZZ.PlotCla(pcaTb, 'pca', 'GridSize', [nRow nCol]);
                    end
                    
                    % Plot behavioral classifaction
                    SL.ZZ.PlotCla(stimTb, 'stim', 'GridSize', [nRow nCol], 'StartPos', [2 1]);
                    
                    % Plot matched behavioral variables
                    x1 = stimTb.stim1{i};
                    x2 = stimTb.stim2{i};
                    
                    for j = 1 : numel(varNames)
                        ax = subplot(nRow, nCol, i+nCol*(j+1));
                        plot(t, squeeze(x1(:,j,:))', 'Color', [SL.Param.RLColor .2]); hold on
                        plot(t, squeeze(x2(:,j,:))', 'Color', [SL.Param.LRColor .2]);
                        xlim(t([1 end]));
                        ylabel(varNames{j});
                        MPlot.Axes(ax);
                    end
                end
                
                % Save plot
                plotName = ['cla ' stimTb.sessionId{i}];
%                 print(f, fullfile(datDir, plotName), '-dpng', '-r0');
            end
        end
        
        function PlotShifted(t, aa, s)
            % Visualize the result of FindShifts
            %   s is the output of the FindShifts function
            
            t = t(:,1);
            if isempty(aa)
                aa = [s.a1 s.a2];
            end
            lags = s.lags;
            xc = s.xc;
            iShift = s.iShift;
            tShift = t(iShift+round(numel(t)/2));
            
            ax = subplot(3,1,1);
            findpeaks(xc, lags);
%             plot(lags, xc, 'k');
            MPlot.Axes(ax);
            
            ax = subplot(3,1,2);
            plot(t+tShift(1), aa(:,2)); hold on
            plot(t+tShift(2), aa(:,2)); hold on
            plot(t, aa(:,1), 'k'); hold on
            MPlot.Axes(ax);
            
            ax = subplot(3,1,3);
            plot(t-tShift(2), aa(:,1)); hold on
            plot(t-tShift(1), aa(:,1)); hold on
            plot(t, aa(:,2), 'k'); hold on
            MPlot.Axes(ax);
        end
        
        % Not in use
        function [d, t, varNames] = GetStimArray(se)
            % A wrapper of SL.SE.GetStimArray with customized parameters
            
            % Set parameters
            ops = SL.Param.Resample();
            ops.hsvVars = {'theta_shoot'};
            ops.adcVars = {};
            ops.valVars = {};
            ops.derivedVars = {};
            ops.rsWin = [-.3 .3];
            ops.rsBinSize = 0.015;
            
            % Extract variables
            [d, t, varNames] = SL.SE.GetStimArray(se, ops);
            d = permute(d, [3 1 2]); % => trial-by-time-by-variable
        end
    end
end

