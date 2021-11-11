classdef UnitFig
    methods(Static)
        function s = GetExampleInfo(keystr)
            
            unitInd = [];
            trialNum = [];
            areaName = '';
            sessionDatetime = '';
            
            S1TJ = {'S1TJ', 'MX181002 2018-12-29'};
            M1TJ = {'M1TJ', 'MX181302 2019-02-10'};
            ALM = {'ALM', 'MX170903 2018-03-04'};
            S1L = {'S1L', 'MX180601 2018-07-21'};
            Thal = {'VAL', 'MX180203 2018-06-07'};
            stria = {'striatum', 'MX180201 2018-04-04'};
            
            if ismember(keystr, S1TJ)
                [areaName, sessionDatetime] = S1TJ{:};
                unitInd = [10 3 14]; % 3 10 13 14
            elseif ismember(keystr, M1TJ)
                [areaName, sessionDatetime] = M1TJ{:};
                unitInd = [1 2 4];
            elseif ismember(keystr, ALM)
                [areaName, sessionDatetime] = ALM{:};
                unitInd = [45 36 17];
            elseif ismember(keystr, S1L)
                [areaName, sessionDatetime] = S1L{:};
                unitInd = [17 7 3]; % also see 15
                trialNum = [67 44];
            elseif ismember(keystr, Thal)
                [areaName, sessionDatetime] = Thal{:};
                unitInd = [6 10 45];
            elseif ismember(keystr, stria)
                [areaName, sessionDatetime] = stria{:};
                unitInd = [1 7 15]; % also see 10 13 21 22 28
            else
                warning('%s is not an example session.', keystr);
            end
            
            s.areaName = areaName;
            s.sessionDatetime = sessionDatetime;
            s.unitInd = unitInd;
            s.trialNum = trialNum;
        end
        
        function PlotRasterPETHCombo(seTb, unitTb, unitInd, varargin)
            
            p = inputParser;
            p.addParameter('BehavVars', {'air', 'touch'}, @iscellstr);
            p.parse(varargin{:});
            behavVars = p.Results.BehavVars;
            
            f = gcf;
            f.Units = 'normalized';
            
            spXX = repmat(.13/3 : 1/3 : 1, [4 1]);
            spY = cumsum([1.5 3.1 0.8+1.5 3.1]');
            spYY = repmat(1-spY/(spY(end)+1), [1 4]);
            spW = (spXX(1,2) - spXX(1,1)) * .8;
            spH = 1/(spY(end)+1);
            k = 0;
            
            for i = 1 : height(seTb)
                
                ops = seTb.se(i).userData.ops;
                bt = seTb.se(i).GetTable('behavTime');
                
                tCenters = unitTb.(['tt' num2str(i)])(1,:)';
                hh = unitTb.(['hh' num2str(i)])(unitInd,:)';
                ee = unitTb.(['ee' num2str(i)])(unitInd,:)';
                
                hhMax = unitTb.peakSpkRate(unitInd)';
                hh = hh ./ hhMax;
                ee = ee ./ hhMax;
                
                spkSub = seTb.se(i).GetTable('spikeTime');
                spkSub = spkSub(:,unitInd);
                
                k = k + 1;
                ax = axes(); cla
                ax.Units = 'normalized';
                ax.Position = [spXX(k) spYY(k) spW spH];
                
                SL.UnitFig.PlotMatchedTrials(bt, behavVars);
                ax.Title.String = [char(seTb.seqId(i)) ' ' ops.alignType];
                ax.XAxis.Visible = 'off';
                ax.YAxis.Visible = 'off';
                ax.XLim = ops.rsWin;
                ax.XGrid = 'off';
                ax.YGrid = 'off';
                
                k = k + 1;
                ax = axes(); cla
                ax.Units = 'normalized';
                ax.Position = [spXX(k) spYY(k) spW spH*3];
                
                SL.UnitFig.PlotHistStack(tCenters, hh, ee, 'trace', 1);
                SL.UnitFig.PlotRasterStack(spkSub);
                ax.XLim = ops.rsWin;
            end
        end
        
        function PlotRasterStack(spk, unit_c)
            % Plot rasters from a spikeTime table (or its cell array) in one axes with stacking units
            
            if istable(spk)
                spk = spk{:,:};
            end
            [n_trials, n_units] = size(spk);
            
            if nargin < 2
                unit_c = repmat([0 0 0 .7; .3 .3 .3 .7], [ceil(n_units/2) 1]);
            end
            
            hold on
            m = 0;
            y = 0.5;
            for i = 1 : n_units
                m = m + 1;
                y = y + 1/(n_trials+2);
                
                for j = 1 : n_trials
                    y = y + 1/(n_trials+2);
                    
                    spk_t = spk{j,i};
                    spk_y = repelem(y,length(spk_t));
                    spk_h = 1/(n_trials+2) * .8;
                    
                    MPlot.PlotPointAsLine(spk_t, spk_y, spk_h, 'Color', unit_c(m,:), 'LineWidth', .5);
                end
                
                y = y + 1/(n_trials+2);
            end
            
            ax = gca;
            ax.YLim = [.5, n_units+.5];
            ax.YTick = 1 : n_units;
            ax.YDir = 'reverse';
            ax.XGrid = 'on';
%             ax.XMinorGrid = 'on';
        end
        
        function PlotHistStack(t, hh, ee, style, fracHeight)
            % Plot a stack of histograms in one axes
            
            if nargin < 5
                fracHeight = 1;
            end
            if nargin < 4
                style = 'trace';
            end
            n_units = size(hh, 2);
            hh = hh * fracHeight;
            ee = ee * fracHeight;
            binSize = t(2) - t(1);
            binEdges = t - binSize/2;
            binEdges(end+1) = binEdges(end) + binSize;
            
            hold on
            unit_c = repmat({[0 0 0], [0 0 0]+.3}, 1, ceil(n_units/2));
            m = 0;
            y = 0.5;
            
            for i = 1 : n_units
                m = m + 1;
                switch style
                    case 'bar'
                        px = repelem(binEdges, 2);
                        py = [0 repelem(hh(:,i)',2) 0];
                        patch(px, -py+y+1, unit_c{m}, 'FaceAlpha', .1, 'EdgeColor', 'none');
                    case 'trace'
                        plot(t, -hh(:,i)+y+1, 'Color', [unit_c{m} .5], 'LineWidth', 1);
                        MPlot.ErrorShade(t, -hh(:,i)+y+1, ee(:,i), 'Alpha', 0.1);
                    otherwise
                        error('%s is not a supported style', style);
                end
                y = y + 1;
            end
            
            ax = gca;
            ax.YLim = [.5, n_units+.5];
            ax.YTick = 1 : n_units;
            ax.YDir = 'reverse';
            ax.XGrid = 'on';
%             ax.XMinorGrid = 'on';
        end
        
        function PlotHistOverlay(t, hh, ee, cc, fracHeight)
            % Plot an overlay of two PETHs beneath spike rasters. Used in SL.ZZ.PlotRasterPETHs
            
            if nargin < 5
                fracHeight = 1;
            end
            n_units = size(hh, 2);
            if nargin < 4
                cc = lines(n_units);
            end
            hh = -hh * fracHeight + n_units + 1.5;
            ee = ee * fracHeight;
            
            hold on
            for i = 1 : n_units
                MPlot.ErrorShade(t, hh(:,i), ee(:,i), 'Color', cc(i,:), 'Alpha', 0.1);
                plot(t, hh(:,i), 'Color', [cc(i,:) .5], 'LineWidth', 1);
            end
            
            ax = gca;
            ax.YLim = [.5, n_units+1.5];
            ax.YTick = 1 : n_units;
            ax.YDir = 'reverse';
            ax.XGrid = 'on';
%             ax.XMinorGrid = 'on';
        end
        
        function PlotMatchedTrials(bt, varNames)
            
            ax = gca;
            hold(ax, 'on');
            for i = 1 : numel(varNames)
                switch varNames{i}
                    case 'water'
                        [waterOn, waterY] = SL.BehavFig.ConvertEventTimesForRasters(bt.water);
                        plot(ax, Segment(waterOn, waterOn+0.2), Segment(waterY), 'b', 'LineWidth', 2);
                    case 'air'
                        [air, airY] = SL.BehavFig.ConvertEventTimesForRasters(bt.airOn);
                        MPlot.PlotPointAsLine(air, airY, .6, 'Color', [0 0 0 .5], 'Parent', ax);
                    case 'touch'
                        [lick, lickY] = SL.BehavFig.ConvertEventTimesForRasters(bt.lickOn);
                        MPlot.PlotPointAsLine(lick, lickY, .6, 'Color', [0 0 0], 'Parent', ax);
                end
            end
            ax.YLim = [0 height(bt)+1];
            ax.YDir = 'reverse';
            
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
        
        function PlotTrial(varargin)
            
            SL.BehavFig.SingleTrial(varargin{1:end-2});
            [k, spk, unitIdx] = varargin{[1 end-1 end]};
            
            tSpk = spk{k,unitIdx}{1};
            ySpk = repmat(180, size(tSpk));
            MPlot.PlotPointAsLine(tSpk, ySpk, 20, 'Color', 'k');
            
            ax = gca;
            ax.YLim(2) = 200;
            ax.Title.String = [ax.Title.String, ', spike'];
        end
        
        function PlotClusterMean(clustTb)
            % Plot mean PETHs
            numComp = height(clustTb);
            cc = lines(2);
            for i = 1 : numComp
                tt = clustTb.tt{i};
                mm = clustTb.mm{i};
                ee = clustTb.se{i};
                
                for j = 1 : 2 : 6
                    t = tt(:,j);
                    m1 = mm(:,j);
                    e1 = ee(:,j);
                    m2 = mm(:,j+1);
                    e2 = ee(:,j+1);
                    
                    ax = subplot(numComp, 3, (i-1)*3+ceil(j/2)); cla
                    MPlot.ErrorShade(t, m1, e1, 'Color', cc(1,:), 'Alpha', .1); hold on
                    MPlot.ErrorShade(t, m2, e2, 'Color', cc(2,:), 'Alpha', .1);
                    plot(t, m1, 'Color', cc(1,:), 'LineWidth', 1);
                    plot(t, m2, 'Color', cc(2,:), 'LineWidth', 1);
                    plot([0 0]', [0 1]', 'Color', [0 0 0 .3]);
                    dt = diff(t([1 2]));
                    ax.XLim = [t(1)-dt/2 t(end)+dt/2];
                    ax.YLim = [0 1];
%                     ax.XTick = [ax.XLim(1) 0 ax.XLim(2)];
                    ax.XTick = [-.5 0 .5];
                    ax.XTickLabel = [];
                    ax.YTick = [0 1];
                    ax.YTickLabel = [];
                    ylabel("#"+i);
                    MPlot.Axes(ax);
                end
            end
        end
        
        function PlotHeatmap(unitTb, compInd)
            % Plot mean PETHs of individual units across conditions
            
            colInd = [1 3 5 2 4 6];
            for i = 1 : numel(colInd)
                k = colInd(i);
                tt = unitTb.(['tt' num2str(k)])';
                hh = unitTb.(['hh' num2str(k)])';
                hh = hh ./ unitTb.peakSpkRate';
                
                ax = subplot(1,6,i);
                dt = tt(2) - tt(1);
                xTicks = [tt(1)-dt/2, 0, tt(end)+dt/2];
                wRib = xTicks(1) - [.1 .05];
                xLims = [wRib(1) xTicks(end)];
                
                imagesc(tt(:,1), 1:size(hh,2), hh'); hold on
                plot([0 0]', [1 size(hh,2)]', '-', 'Color', [1 1 1 .3]);
                [xSeg, ySeg] = MPlot.GroupRibbon(wRib, unitTb.clustId, 'Groups', compInd, 'Style', 'patch');
                text(xSeg-.1, ySeg, string(compInd), 'Hori', 'right');
                
                xLims(1) = wRib(1);
                axis tight
                colormap copper;
                caxis([0 1]);
                ax.XLim = xLims;
                ax.XTick = [-.5 0 .5];
                ax.YTickLabel = [];
                MPlot.Axes(ax);
                title(height(unitTb));
            end
        end
        
        function PlotPopPETH(unitTb, plotStyle)
            % Plot mean PETHs of individual units across conditions
            
            colInd = [1 3 5 2 4 6];
            for i = 1 : numel(colInd)
                k = colInd(i);
                tt = unitTb.(['tt' num2str(k)])';
                hh = unitTb.(['hh' num2str(k)])';
                if size(hh,2) > 1
                    hh = hh ./ unitTb.peakSpkRate';
                    hMax = 1;
                else
                    hMax = max(unitTb.peakSpkRate, 1);
                end
                dt = tt(2) - tt(1);
                xLims = [tt(1)-dt/2, tt(end)+dt/2];
                xTicks = [xLims(1) 0 xLims(2)];
                if strcmp(plotStyle, 'trace')
                    ax = subplot(6,1,i); cla
                    plot(tt, hh, 'Color', [0 0 0 .15], 'LineWidth', 1); hold on
                    plot(tt(:,1), mean(hh,2), 'Color', [0 0 0], 'LineWidth', 1);
                    ax.YLim = [0 hMax];
                elseif strcmp(plotStyle, 'heatmap')
                    ax = subplot(1,6,i); cla
                    imagesc(tt(:,1), 1:size(hh,2), hh');
                    axis tight
                    colormap copper;
                    caxis([0 hMax]);
                end
                ax.XLim = xLims;
                ax.XTick = xTicks;
                MPlot.Axes(ax);
            end
        end
        
        % Review units
        function ReviewUnits(seTbPaths)
            % Make and save plots for one or more seTbs showing rasters and PETHs of all units along with lick angle
            
            % Find files
            if ~exist('seTbPaths', 'var') || isempty(seTbPaths)
                seTbPaths = MBrowse.Files(SL.Data.analysisRoot, 'Select one or more seTb');
            end
            
            % Go through each seTb
            for k = 1 : numel(seTbPaths)
                % Load seTb
                load(seTbPaths{k});
                sessionId = SL.SE.GetID(seTb.se(1));
                nUnits = width(seTb.se(1).GetTable('spikeTime'));
                
                % Select standard and backtracking sequenes wo opto
                isSelect = ismember(seTb.seqId, [SL.Param.stdSeqs SL.Param.backSeqs]) & seTb.opto == -1;
                seTb = seTb(isSelect,:);
                
                % Split seTb by sequence directions
                seqIdNum = double(seTb.seqId);
                isRL = mod(seqIdNum,2) == 1; % RL if seqIdNum is odd
                seTbs = {seTb(isRL,:); seTb(~isRL,:)};
                
                % Plotting
                unitsPerFig = 8;
                nSet = 2; % two halves
                nRow = 1 + unitsPerFig / nSet;
                nCol = 2 * nSet;
                nFigs = ceil(nUnits / unitsPerFig);
                
                for i = 1 : nFigs
                    f = MPlot.Figure(1); clf
                    f.WindowState = 'maximized';
                    unitInd = (i-1)*unitsPerFig+1 : min(i*unitsPerFig, nUnits);
                    
                    % Lick angle
                    SL.UnitFig.PlotAngleForReview([seTbs; seTbs], 'GridSize', [nRow nCol]);
                    
                    % Unit responses
                    SL.UnitFig.PlotRasterPETHs(seTbs, unitInd, 'GridSize', [nRow nCol], 'StartPos', [2 1]);
                    
                    % Save figure
                    seTbDir = fileparts(seTbPaths{k});
                    figDir = fullfile(seTbDir, [sessionId ' units']);
                    if ~exist([sessionId 'units'], 'dir')
                        mkdir(figDir);
                    end
                    figName = [seTb.sessionId{1} ' unit ' num2str(unitInd(1),' %02i') '-' num2str(unitInd(end),' %02i')];
                    print(f, fullfile(figDir, figName), '-dpng', '-r0');
                end
            end
        end
        
        function PlotAngleForReview(seTbs, varargin)
            % Make subplots of lick angle time series for every conditions
            %   PlotAngleForReview(seTbSft, 'GridSize', [1 height(claTb)], 'StartPos', [1 1])
            
            p = inputParser();
            p.addParameter('GridSize', [1 numel(seTbs)], @isvector);
            p.addParameter('StartPos', [1 1], @isvector);
            p.parse(varargin{:});
            nRow = p.Results.GridSize(1);
            nCol = p.Results.GridSize(2);
            iRow = p.Results.StartPos(1);
            iCol = p.Results.StartPos(2);
            
            iBefore = (iRow-1)*nCol + (iCol-1);
            cc = [0 0 0; SL.Param.backColor];
            
            % Plot through each condition
            for i = 1 : numel(seTbs)
                ax = subplot(nRow, nCol, iBefore+i); cla
                seTb = seTbs{i};
                for k = 1 : height(seTb)
                    hsv = seTb.se(k).GetTable('hsv');
                    tt = hsv.time;
                    aa = hsv.tongue_bottom_angle;
                    SL.Match.PlotAngleOverlay(tt, aa, 'Color', [cc(k,:) .15]);
                end
                ax.XLim = [-.5 .8];
                ax.YLim = [-30 30];
                ax.YTick = -45:15:45;
                ax.XGrid = 'on';
                ax.Box = 'off';
%                 ax.Title.String = ['seq' num2str(iSft)];
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
        
        function PlotRasterPETHs(seTbs, unitInd, varargin)
            % Make subplots of stacked rasters and PETHs for every matching conditions
            %   PlotRasterPETHs(seTbs, unitInd, 'GridSize', [numel(unitInd) numel(seTbs)], 'StartPos', [1 1])
            
            p = inputParser();
            p.addParameter('GridSize', [numel(unitInd) numel(seTbs)], @isvector);
            p.addParameter('StartPos', [1 1], @isvector);
            p.parse(varargin{:});
            nRow = p.Results.GridSize(1);
            nCol = p.Results.GridSize(2);
            iRow = p.Results.StartPos(1);
            iCol = p.Results.StartPos(2);
            
            iBefore = (iRow-1)*nCol + (iCol-1);
            cc = [0 0 0; SL.Param.backColor];
            tWin = [-.5 .8];
            tBinSize = 0.005;
            nCond = numel(seTbs);
            nUnit = numel(unitInd);
            
            % Slice out spike times
            spkCell = cell(size(seTbs));
            for j = 1 : nCond
                seTb = seTbs{j};
                nPlot = min([seTb.numMatched; 20]);
                rng(61);
                spkCell{j} = arrayfun( ...
                    @(x,m) x.SliceEventTimes('spikeTime', tWin, randsample(x.numEpochs,nPlot,false), unitInd), ...
                    seTb.se, 'Uni', false);
            end
            
            % Compute PETHs
            ops.rsWin = tWin;
            ops.rsBinSize = tBinSize;
            hTb = cellfun(@(x) SL.Unit.UnitPETH(x.se, ops), seTbs, 'Uni', false);
            
            % Find peak spike rates across conditions
            hMax = cellfun(@(x) x.peakSpkRate, hTb, 'Uni', false);
            hMax = max(cat(2, hMax{:}), [], 2);
            hMax = max(hMax, eps);
            
            % Make subplots
            iSub = 1;
            for i = 1 : nUnit
                for j = 1 : nCond
                    ax = subplot(nRow, nCol, iBefore+iSub); cla
                    u = unitInd(i);
                    spk = spkCell{j};
                    
                    if numel(spk) == 1
                        % Has std seq only
                        spk = spk{1}.(i);
                        t = hTb{j}.tt1(u,:)';
                        hh = hTb{j}.hh1(u,:)';
                        ee = hTb{j}.ee1(u,:)';
                    else
                        % Has both std and back seqs
                        spk = cat(2, spk{1}.(i), spk{2}.(i));
                        t = hTb{j}.tt1(u,:)';
                        hh = [hTb{j}.hh1(u,:)' hTb{j}.hh2(u,:)'];
                        ee = [hTb{j}.ee1(u,:)' hTb{j}.ee2(u,:)'];
                    end
                    hh = hh ./ hMax(u);
                    ee = ee ./ hMax(u);
                    
                    SL.UnitFig.PlotRasterStack(spk, cc);
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
        
    end
end

