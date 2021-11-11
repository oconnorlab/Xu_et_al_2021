classdef PopFig
    methods(Static)
        function PlotExample(sessionIdx, trialInd, comTb, sReg, lims)
            
            m = sReg(sessionIdx);
            nCond = height(comTb);
            
            for condIdx = 1 : nCond
                % Unload variable
                d = table2struct(comTb(condIdx,:));
                
                % Reshape matrice into time by trial by variable
                nTrialTotal = sum(d.numMatched);
                t = reshape(d.time, [], nTrialTotal);
                stim = reshape(d.stim(:,m.sInd), [], nTrialTotal, numel(m.sInd));
                proj = reshape(d.reg, [], nTrialTotal, size(d.reg,2));
                
                % Select the chosen trial
                k = sum(d.numMatched(1:sessionIdx-1)) + trialInd(condIdx);
                if k > sum(d.numMatched(1:sessionIdx))
                    error('Trial index %d exceed the number of trials in this session', trialInd(condIdx));
                end
                t = t(:,k);
                stim = squeeze(stim(:,k,:));
                proj = squeeze(proj(:,k,:));
                nnproj = proj;
                nnproj(isnan(stim)) = NaN;
                
                %
                varNames = SL.PopFig.RenameVariables(m.subNames);
                nVars = numel(varNames);
                r2 = m.r2cv;
                
                for i = 1 : nVars
                    ax = subplot(nVars, nCond, (i-1)*nCond+condIdx);
                    
                    hold on
                    plot(t, stim(:,i), 'Color', [0 0 0 .6], 'LineWidth', 1);
                    plot(t, proj(:,i), 'Color', [d.color .3], 'LineWidth', 1.5);
                    plot(t, nnproj(:,i), 'Color', d.color, 'LineWidth', 1.5);
                    
                    dt = t(2) - t(1);
                    ax.XLim = [t(1)-dt/2 t(end)+dt/2];
                    ax.XTick = [-.5 0 .5];
                    SL.PopFig.FormatRegAxes(ax, varNames{i});
                    ax.YLim = lims{i};
                    plot([ax.XTick; ax.XTick], ax.YLim', 'Color', [0 0 0 .2]);
                    title([varNames{i} ', ' 'R^2 = ' num2str(r2(i), '%.2f')]);
                end
            end
        end
        
        function PlotStim(tb, ops, varargin)
            % 
            
            p = inputParser;
            p.addOptional('subInd', 1 : size(tb.stim{1},2), @isnumeric);
            p.addParameter('AxesFun', @SL.PopFig.FormatStimAxes, @(x) isa(x, 'function_handle'));
            p.addOptional('SessionInd', [], @isnumeric);
            p.parse(varargin{:});
            subInd = p.Results.subInd;
            axesFun = p.Results.AxesFun;
            ssInd = p.Results.SessionInd;
            
            nSub = numel(subInd);
            varNames = [ops.hsvVars ops.adcVars ops.valVars ops.derivedVars];
            varNames = SL.PopFig.RenameVariables(varNames);
            
            T = cell2mat(tb.time);
            nTrace = sum(diff(T) < 0) + 1;
            nTimes = numel(T) / nTrace;
            a = 1 / log2(max(2, nTrace/height(tb)));
            
            for i = 1 : nSub
                k = subInd(i);
                ax = subplot(nSub,1,i); cla
                for j = 1 : height(tb)
                    if isempty(ssInd)
                        spInd = true(size(tb.time{j}));
                    else
                        spInd = [0; cumsum(tb.numMatched{j})*nTimes];
                        spInd = spInd(ssInd(1))+1 : spInd(ssInd(end)+1);
                    end
                    t = tb.time{j}(spInd);
                    s = tb.stim{j}(spInd,k,1);
                    plot(t, s, tb.line{j}, 'Color', [tb.color(j,:) a], 'LineWidth', 1.5); hold on
                end
                dt = t(2) - t(1);
                ax.XLim = [t(1)-dt/2 t(end)+dt/2];
                ax.XTick = [-.5 0 .5];
                axesFun(ax, varNames{k});
                plot([ax.XTick; ax.XTick], ax.YLim', 'Color', [0 0 0 .2]);
                title(varNames{k});
            end
        end
        
        function PlotPC(seTb, sMdl, maxSub)
            % Project data to basis vectors and plot as a function of time
            
            if nargin < 3
                maxSub = Inf;
            end
            nSub = min(numel(sMdl.subNames), maxSub);
            
            T = cell2mat(seTb.time);
            nTrace = sum(diff(T) < 0) + 1;
            a = 1 / log(max(exp(1), nTrace/height(seTb)));
            
            for k = 1 : nSub
                ax = subplot(nSub,1,k); cla
                hold on
                for i = 1 : height(seTb)
                    if size(seTb.pca{i}, 3) == 1
                        % Raw traces
                        t = seTb.time{i};
                        t(diff(t)<0) = NaN;
                        proj = seTb.pca{i}(:,k);
                        plot(t, proj, seTb.line{i}, 'Color', [seTb.color(i,:) a], 'LineWidth', 1);
                    else
                        % Mean and SD
                        t = seTb.time{i};
                        m = seTb.pca{i}(:,k,1);
                        e = seTb.pca{i}(:,k,2);
                        MPlot.ErrorShade(t, m, e, 'Color', seTb.color(i,:), 'Alpha', 0.1);
                        plot(t, m, seTb.line{i}, 'Color', seTb.color(i,:), 'LineWidth', 1.5);
                    end
                end
                ax.XLim = [nanmin(t) nanmax(t)];
                SL.PopFig.FormatRegAxes(ax, sMdl.subNames{k});
                titleStr = [sMdl.subNames{k} ', ' ...
                    num2str(sMdl.varExplained(k), '%.0f') '% VE, ' ...
                    num2str(sMdl.uve(k), '%.1f') ' NVE'];
                title(titleStr);
            end
        end
        
        function PlotReg(seTb, sMdl, maxSub)
            % Project data to basis vectors and plot as a function of time
            
            if nargin < 3
                maxSub = Inf;
            end
            nSub = min(numel(sMdl.subNames), maxSub);
            
            T = cell2mat(seTb.time);
            nTrace = sum(diff(T) < 0) + 1;
            a = 1 / log(max(exp(1), nTrace/height(seTb)));
            
            for k = 1 : nSub
                ax = subplot(nSub,1,k); cla
                for i = 1 : height(seTb)
                    t = seTb.time{i};
                    t(diff(t)<0) = NaN;
                    proj = seTb.reg{i}(:,k);
                    plot(t, proj, seTb.line{i}, 'Color', [seTb.color(i,:) a], 'LineWidth', 1);
                    hold on
                end
                ax.XLim = [nanmin(t) nanmax(t)];
                SL.PopFig.FormatRegAxes(ax, sMdl.subNames{k});
                titleStr = [sMdl.subNames{k} ', R^2 = ' num2str(sMdl.r2cv(k), '%.2f') ', ' ...
                    num2str(sMdl.varExplained(k), '%.0f') '% VE, ' ...
                    num2str(sMdl.uve(k), '%.1f') ' NVE'];
                title(titleStr);
            end
        end
        
        function PlotMeanStim(seTb, ops, subInd, axFunc)
            % 
            
            if ~exist('axFunc', 'var')
                axFunc = @SL.PopFig.FormatStimAxes;
            end
            if ~exist('subInd', 'var') || isempty(subInd)
                subInd = 1 : size(seTb.stim{1},2);
            end
            nSub = numel(subInd);
            
            varNames = [ops.hsvVars ops.adcVars ops.valVars ops.derivedVars];
            varNames = SL.PopFig.RenameVariables(varNames);
            
            for i = 1 : nSub
                k = subInd(i);
                ax = subplot(nSub,1,i); cla
                for j = 1 : height(seTb)
                    t = seTb.time{j};
                    m = seTb.stim{j}(:,k,1);
                    ci1 = seTb.stim{j}(:,k,3);
                    ci2 = seTb.stim{j}(:,k,4);
                    toNaN = seTb.stim{j}(:,k,5) > .8;
                    
                    bb = MMath.Logical2Bounds(~toNaN);
                    for n = 1 : size(bb,1)
                        ind = bb(n,1):bb(n,2);
                        MPlot.ErrorShade(t(ind), m(ind), ci1(ind), ci2(ind), 'IsRelative', false, ...
                            'Color', seTb.color(j,:), 'Alpha', 0.1); hold on
                        plot(t(ind), m(ind), seTb.line{j}, 'Color', seTb.color(j,:), 'LineWidth', 1);
                    end
                end
                dt = t(2) - t(1);
                ax.XLim = [t(1)-dt/2 t(end)+dt/2];
                ax.XTick = [-.5 0 .5];
                axFunc(ax, varNames{k});
                plot([ax.XTick; ax.XTick], ax.YLim', 'Color', [0 0 0 .2]);
                title(varNames{k});
            end
        end
        
        function PlotMeanReg(seTb, sMdl, varargin)
            % Project data to basis vectors and plot as a function of time
            
            p = inputParser;
            p.addOptional('subInd', 1:size(seTb.reg{1},2), @isnumeric);
            p.addParameter('AxesFun', @SL.PopFig.FormatRegAxes, @(x) isa(x, 'function_handle'));
            p.parse(varargin{:});
            subInd = p.Results.subInd;
            axFun = p.Results.AxesFun;
            
            varNames = SL.PopFig.RenameVariables(sMdl(1).subNames);
            nSub = numel(subInd);
            
            r2 = cat(1, sMdl.r2cv);
            [r2m, r2sd] = MMath.MeanStats(r2, 1);
            
            for i = 1 : nSub
                k = subInd(i);
                ax = subplot(nSub,1,i); cla
                for j = 1 : height(seTb)
                    t = seTb.time{j};
                    m = seTb.reg{j}(:,k,1);
                    ci1 = seTb.reg{j}(:,k,3);
                    ci2 = seTb.reg{j}(:,k,4);
                    MPlot.ErrorShade(t, m, ci1, ci2, 'IsRelative', false, ...
                        'Color', seTb.color(j,:), 'Alpha', 0.1); hold on
                    plot(t, m, seTb.line{j}, 'Color', seTb.color(j,:), 'LineWidth', 1);
                end
                dt = t(2) - t(1);
                ax.XLim = [t(1)-dt/2 t(end)+dt/2];
                ax.XTick = [-.5 0 .5];
                axFun(ax, varNames{k});
                plot([ax.XTick; ax.XTick], ax.YLim', 'Color', [0 0 0 .2]);
                titleStr = [varNames{k} ', ' ...
                    'R^2 = ' num2str(r2m(k), '%.2f') ' ± ' num2str(r2sd(k), '%.2f')];
                title(titleStr);
            end
        end
        
        function PlotMeanTraj(tb, info, varargin)
            % Project data to basis vectors and plot as a function of time
            
            p = inputParser;
            p.addParameter('Name', 'reg', @(x) ismember(x, tb.Properties.VariableNames));
            p.addParameter('SubInd', [], @isnumeric);
            p.addParameter('CondInd', (1:height(tb))', @isnumeric); % with row vectors
            p.addParameter('AxesFun', @SL.PopFig.FormatRegAxes, @(x) isa(x, 'function_handle'));
            p.parse(varargin{:});
            datName = p.Results.Name;
            subInd = p.Results.SubInd;
            condInd = p.Results.CondInd;
            axesFun = p.Results.AxesFun;
            
            if isempty(subInd)
                subInd = 1 : size(tb.(datName){1},2);
            end
            nSub = numel(subInd);
            
            switch datName
                case {'reg', 'dreg'}
                    varNames = SL.PopFig.RenameVariables(info(1).subNames);
                    r2 = cat(1, info.r2cv);
                    [r2m, r2sd] = MMath.MeanStats(r2, 1);
                case 'pca'
                    varNames = "PC" + (1 : size(tb.pca{1},2));
                case 'stim'
                    varNames = [info.hsvVars info.adcVars info.valVars info.otherVars];
            end
            varNames = SL.PopFig.RenameVariables(varNames);
            
            for i = 1 : nSub
                k = subInd(i);
                ax = subplot(nSub,1,i);
                for j = 1 : size(condInd,1)
                    % Cache variables
                    t = tb.time{j};
                    idx1 = condInd(j,1);
                    arr1 = tb.(datName){idx1};
                    m1 = arr1(:,k,1);
                    ci1 = arr1(:,k,3:4);
                    
                    if size(condInd,2) == 1
                        m = m1;
                        ci = ci1;
                    else
                        idx2 = condInd(j,2);
                        arr2 = tb.(datName){idx2};
                        m2 = arr2(:,k,1);
                        ci2 = arr2(:,k,3:4);
                        m = m2 - m1;
                        ci = [m m];
                    end
                    
                    MPlot.ErrorShade(t, m, ci(:,1), ci(:,2), 'IsRelative', false, ...
                        'Color', tb.color(idx1,:), 'Alpha', 0.1); hold on
                    plot(t, m, tb.line{idx1}, 'Color', tb.color(idx1,:), 'LineWidth', 1); hold on
                end
                dt = t(2) - t(1);
                ax.XLim = [t(1)-dt/2 t(end)+dt/2];
                ax.XTick = [-1 -.5 0 .5 1]; 
                plot(ax.XLim, [0 0], 'Color', [0 0 0 .2]);
                
                titleStr = varNames{k};
                switch datName
                    case 'reg'
                        titleStr = [varNames{k} ', ' ...
                            'R^2 = ' num2str(r2m(k), '%.2f') '±' num2str(r2sd(k), '%.2f')];
                    case 'stim'
                        
                end
                title(titleStr);
                axesFun(ax, varNames{k});
            end
        end
        
        function PlotRSquared(regAvgTb, regTb)
            
            varNames = SL.PopFig.RenameVariables(regTb.subNames(1,:));
            numVars = numel(varNames);
            numAreas = height(regAvgTb);
            
            for i = 1 : numVars
                ax = subplot(1,numVars,i);
                bar(regAvgTb.r2mean(:,i), 'EdgeColor', [0 0 0]+.7, 'FaceColor', 'none'); hold on
                for j = 1 : numAreas
                    r2 = regTb.r2(regAvgTb.groupInd{j}, i);
                    plot(j, r2, 'o', 'Color', regAvgTb.color(j,:))
                end
                ax.XTick = 1 : numAreas;
                ax.XTickLabel = string(regAvgTb.area);
                ax.XTickLabelRotation = 90;
                ax.XLim = [0 numAreas+1];
                ax.YLim = [0 1];
                ax.YLabel.String = 'R^2';
                ax.Title.String = varNames{i};
                MPlot.Axes(ax);
            end
        end
        
        function PlotRSquaredByTimeLags(sessTb)
            
%             areaNames = unique(sessTb.area);
            areaNames = {'S1TJ', 'M1TJ', 'ALM'};
            numAreas = numel(areaNames);
            varNames = SL.PopFig.RenameVariables(sessTb.subNames(1,:));
            iv = strcmp(varNames, '\theta');
            
            for k = 1 : numAreas
                % Take the subset for the given area
                sessSub = sessTb(sessTb.area == areaNames(k), :);
                tLag = unique(sessSub.tLag);
                
                % Compute normalized R^2 for the variable of interest
                yy = splitapply(@(x) {x(:,iv)'}, sessSub.r2, findgroups(sessSub.tLag));
                yy = cat(1, yy{:});
                yy = yy ./ max(yy, [], 1); % normalize to the max R^2 for each session
                [Y, ~, ~, CI] = MMath.MeanStats(yy, 2);
                
                % Get the x coordinates
                xx = cumsum(ones(size(yy)));
                x = xx(:,1);
                
                % Plotting
                ax = subplot(1, numAreas, k);
                errorbar(x, Y, Y-CI(:,1), CI(:,2)-Y, 'k'); hold on
                plot(xx, yy, 'Color', [0 0 0 .2]);
                ax.XTick = 1 : numel(x);
                ax.XTickLabel = string(tLag * 1e3);
                ax.XTickLabelRotation = 90;
                ax.XLim = [0 numel(x)+1];
                ax.YLim = [.5 1];
                ax.YLabel.String = 'R^2/R^2_{max}';
                ax.XLabel.String = '\Deltat_{spike}';
                ax.Title.String = [char(areaNames(k)) ' ' varNames{iv}];
                MPlot.Axes(ax);
            end
        end
        
        function CompareVarExplained(areaTb, pcaTb, regTb, regInd)
            if ~exist('regInd', 'var')
                regInd = 1 : size(regTb.subNames,2);
            end
            for i = 1 : height(areaTb)
                g = areaTb.groupInd{i};
                vePC = cellfun(@(x) sum(x(1:numel(regInd))), pcaTb.varExplained(g));
                veB = sum(regTb.varExplained(g,regInd), 2);
%                 veB = veB./vePC;
%                 vePC(:) = 1;
                x = [-.3 .3] + i;
                plot(x', [vePC veB]', 'Color', [areaTb.color(i,:) .3]); hold on
                plot(x', mean([vePC veB])', 'Color', areaTb.color(i,:), 'LineWidth', 2);
            end
            title('VE by PCs vs coding axes');
            ax = MPlot.Axes(gca);
            ax.XLim = [0 height(areaTb)+1];
            ax.YLim(1) = 0;
            ax.YLabel.String = 'VE (%)';
            ax.XTick = 1 : height(areaTb);
            ax.XTickLabel = MPlot.Color2Str(areaTb.color, areaTb.area);
            ax.YTick = 0 : 20 : 100;
        end
        
        function varargout = PlotCosine(cosMat, xLabels, yLabels)
            % Plot a matrix of pairwise cosine among bases vectors
            if nargin < 3
                yLabels = xLabels;
            end
            xLabels = SL.PopFig.RenameVariables(xLabels);
            yLabels = SL.PopFig.RenameVariables(yLabels);
            cosMat = flip(abs(cosMat), 1);
            yLabels = flip(yLabels);
            h = heatmap(xLabels, yLabels, cosMat);
            h.Colormap = parula;
            h.CellLabelFormat = '%.2f';
            h.ColorLimits = [0 1];
            h.GridVisible = 'off';
            h.Title = 'Pairwise |cosine| among vectors';
            if nargout > 0
                varargout{1} = h;
            end
        end
        
        function seTb = SetPlotParams(seTb)
            % 
            seTb.color = lines(height(seTb));
            seTb.line = repmat({'-'}, [height(seTb) 1]);
            cc = [0 0 1; 1 0 0];
            for i = 1 : height(seTb)
                if ismember('seqId', seTb.Properties.VariableNames)
                    seqStr = char(seTb.seqId(i));
                    if seqStr(end) - seqStr(1) > 0
                        seTb.color(i,:) = cc(1,:);
                    else
                        seTb.color(i,:) = cc(2,:);
                    end
                    if ismember(seTb.seqId(i), SL.Param.backSeqs)
                        seTb.line{i} = ':';
                    elseif ~ismember(seTb.seqId(i), [SL.Param.stdSeqs, SL.Param.zzSeqs])
                        seTb.line{i} = '--';
                    end
                end
                if ismember('opto', seTb.Properties.VariableNames)
                    if seTb.opto ~= -1
                        seTb.color{i} = '-.';
                    end
                end
            end
        end
        
        function [proj, id, t] = GetSchemProj(mcomTb, ind)
            for i = height(mcomTb) : -1 : 1
                p = mcomTb.reg{i}(:,ind,1);
                for j = 1 : numel(ind)
                    p(:,j) = smooth(p(:,j), 5);
                end
                p(end,:) = NaN;
                proj{i} = p;
                t{i} = mcomTb.time{i};
                id{i} = repmat(mcomTb.seqId(i), size(t{i}));
            end
            proj = cat(1, proj{:});
            proj = normalize(proj);
            if numel(ind) < 3
                proj(:,end+1) = 0;
            end
            id = cat(1, id{:});
            t = cat(1, t{:});
        end
        
        function PlotStateTraj(S, id, tMask, cc, w)
            
            if ~exist('tMask', 'var')
                tMask = true(size(id));
            end
            if ~exist('cc', 'var')
                cc = lines(2);
            end
            if ~exist('w', 'var')
                w = 1;
            end
            
            for i = 1 : size(S,2)
                S(:,i) = smooth(S(:,i), 5);
            end
            
            isRL = ismember(id, {'123456', '1231456', '123432101234'});
            isLR = ismember(id, {'543210', '5435210', '321012343210'});
            isN = ismember(id, [SL.Param.stdSeqs, SL.Param.zzSeqs]);
%             isB = ismember(id, SL.Param.backSeqs);
            
            S = S(tMask,:);
            isRL = isRL(tMask);
            isLR = isLR(tMask);
            isN = isN(tMask);
            
            S1 = S(isRL & isN, :);
            plot3(S1(:,1), S1(:,2), S1(:,3), 'Color', cc(1,:), 'LineWidth', w); hold on
            
            S2 = S(isLR & isN, :);
            plot3(S2(:,1), S2(:,2), S2(:,3), 'Color', cc(2,:), 'LineWidth', w);
            
            L = [S1(end,:); S2(1,:); NaN(1,3); S2(end,:); S1(1,:)];
            plot3(L(:,1), L(:,2), L(:,3), ':', 'Color', [0 0 0]+.3, 'LineWidth', w);
        end
        
        function varNames = RenameVariables(varNames)
            % Rename variables
            dict = { ...
                'timeVar', '\tau'; ...
                'seqId', 'I'; ...
                'tongue_bottom_angle', '\theta'; ...
                'tongue_bottom_length', 'L'; ...
                'tongue_bottom_velocity', 'L'''; ...
                'posUni', 'Target'; ...
                'posUniMono', 'Progress'; ...
                'theta_shoot', '\theta_{shoot}'; ...
                };
            varNames = replace(varNames, dict(:,1), dict(:,2));
        end
        
        function FormatStimAxes(ax, varName)
            % Format the axes according to the variable being plotted
            MPlot.Axes(ax);
            switch varName
                case 'L'
                    ax.YLim = [-.2 3];
                    ax.YLabel.String = 'mm';
                case 'L'''
                    ax.YLim = [-1 1] * 150;
                    ax.YLabel.String = 'mm/s';
                case '\theta'
                    ax.YLim = [-1 1]*40;
                    ax.YTick = [-1 0 1]*30;
                    ax.YLabel.String = 'degree';
                case 'I'
                    ax.YLim = [1 2]+[-1 1]*.3;
                    ax.YTick = [1 2];
                    ax.YTickLabel = {'RL', 'LR'};
                case '\tau'
                    ax.YLim = [-.5 .8];
                case {'Target', 'TargetMono'}
                    ax.YLim = [0 8];
                    ax.YTick = 1:3:7;
                    ax.YLabel.String = '#';
            end
            if startsWith(varName, 'PC')
                ax.YTick = [];
            end
        end
        
        function FormatStimAxesZZ(ax, varName)
            % Format the axes according to the variable being plotted
            MPlot.Axes(ax);
            switch varName
                case 'L'
                    ax.YLim = [-.2 3];
                    ax.YLabel.String = 'mm';
                case 'L'''
                    ax.YLim = [-1 1] * 150;
                    ax.YLabel.String = 'mm/s';
                case '\theta'
                    ax.YLim = [-1 1]*30;
                    ax.YTick = [-1 0 1]*30;
                    ax.YLabel.String = 'degree';
                case 'I'
                    ax.YLim = [7 8]+[-1 1]*.3;
                    ax.YTick = [7 8];
                    ax.YTickLabel = {'RL', 'LR'};
                case '\tau'
                    ax.YLim = [-1 1];
            end
            if startsWith(varName, 'PC')
                ax.YTick = [];
            end
        end
        
        function FormatRegAxes(ax, varName)
            % Format the axes according to the variable being plotted
            MPlot.Axes(ax);
            switch varName
                case 'L'
                    ax.YLim = [0 2.5];
                    ax.YLabel.String = 'mm';
                case 'L'''
                    ax.YLim = [-1 1] * 70;
                    ax.YLabel.String = 'mm/s';
                case '\theta'
                    ax.YLim = [-1 1]*20;
                    ax.YTick = [-1 0 1]*20;
                    ax.YLabel.String = 'degree';
                case 'I'
                    ax.YLim = [1 2]+[-1 1]*.1;
                    ax.YTick = [1 2];
                    ax.YTickLabel = {'RL', 'LR'};
                case '\tau'
                    ax.YLim = [-.5 .5];
                case {'Target', 'TargetMono'}
                    ax.YLim = [0 8];
                    ax.YTick = 1:3:7;
                    ax.YLabel.String = '#';
            end
            if startsWith(varName, 'PC')
                ax.YTick = [];
            end
        end
        
        function FormatRegAxesZZ(ax, varName)
            % Format the axes according to the variable being plotted
            MPlot.Axes(ax);
            switch varName
                case 'L'
                    ax.YLim = [0 2.5];
                    ax.YLabel.String = 'mm';
                case 'L'''
                    ax.YLim = [-1 1] * 70;
                    ax.YLabel.String = 'mm/s';
                case '\theta'
                    ax.YLim = [-1 1]*20;
                    ax.YTick = [-1 0 1]*20;
                    ax.YLabel.String = 'degree';
                case 'I'
                    ax.YLim = [7 8]+[-1 1]*.1;
                    ax.YTick = [7 8];
                    ax.YTickLabel = {'RL', 'LR'};
                case '\tau'
                    ax.YLim = [-.6 .6];
            end
            if startsWith(varName, 'PC')
                ax.YTick = [];
            end
        end
        
        % Classifications
        function PlotBranchClaBySession(claTb)
            % 
            
            for i = 1 : height(claTb)
                ax = subplot(3, 3, i);
                x = claTb.time{i};
                
                y = claTb.r{i};
                plot(x, y(:,1), 'Color', SL.Param.backColor); hold on
%                 yy = claTb.rCV{i};
%                 plot(x, yy, 'Color', [SL.Param.backColor .4]);hold on
                
                if ismember('rBootStats', claTb.Properties.VariableNames)
                    yb = claTb.rBootStats{i};
%                     plot(x, yb(:,1), '--', 'Color', SL.Param.backColor);
                    MPlot.ErrorShade(x, yb(:,1), yb(:,2), yb(:,3), 'Color', SL.Param.backColor, 'IsRelative', false);
%                     yy = claTb.rBootCV{i}(:,:,10:15);
%                     yy = MMath.CombineDims(yy, [2 3]);
%                     plot(x, yy, 'Color', [0 0 1 .1]);
                end
                
                ys = claTb.rShufStats{i};
                plot(x, ys(:,1), 'Color', [0 0 0]);
                MPlot.ErrorShade(x, ys(:,1), ys(:,2), ys(:,3), 'Color', [0 0 0], 'IsRelative', false);
                
                xlim(x([1 end]));
                ylim([.0 1]);
                xlabel('Time from trigger (s)');
                ylabel('Fraction correct');
                title(claTb.sessionId{i});
                MPlot.Axes(ax);
            end
        end
        
        function PlotBranchCla(mClaTb)
            % 
            
            nPlots = height(mClaTb) * 2;
            cc = SL.Param.GetAreaColors(mClaTb.areaName);
            
            for i = 1 : height(mClaTb)
                x = mClaTb.time{i};
                y = mClaTb.lenStats{i};
%                 x_ = x;
%                 x_(y(:,5) > 0.8) = NaN;
                ax = subplot(2, nPlots/2, i);
                plot(x, y(:,1), 'Color', [0 0 0]);
                MPlot.ErrorShade(x, y(:,1), y(:,3), y(:,4), 'Color', [0 0 0], 'IsRelative', false);
                xlim(x([1 end]));
                ylim([1 3]);
                xlabel('Time from trigger (s)');
                ylabel('L (mm)');
                title(mClaTb.areaName{i});
                MPlot.Axes(ax);
            end
            
            for i = 1 : height(mClaTb)
                x = mClaTb.time{i};
                y = mClaTb.rStats{i};
                ys = mClaTb.rShufStats{i};
                ax = subplot(2, nPlots/2, 4+i);
                plot(x, y(:,1), 'Color', cc(i,:)); hold on
                MPlot.ErrorShade(x, y(:,1), y(:,2), y(:,3), 'Color', cc(i,:), 'IsRelative', false);
                plot(x, ys(:,1), 'Color', [0 0 0]);
                MPlot.ErrorShade(x, ys(:,1), ys(:,2), ys(:,3), 'Color', [0 0 0], 'IsRelative', false);
                xlim(x([1 end]));
                ylim([.4 1]);
                xlabel('Time from trigger (s)');
                ylabel('Fraction correct');
                title(mClaTb.areaName{i});
                MPlot.Axes(ax);
            end
        end
        
        function PlotBootTraces(tb)
            nArea = height(tb);
            for i = 1 : nArea
                t = tb.time{i};
                rBoot = tb.rBoot{i};
                rShufStats = tb.rShufStats{i};
                
                ax = subplot(nArea, 1, i);
                MPlot.ErrorShade(t, rShufStats(:,1), rShufStats(:,2), rShufStats(:,3), 'IsRelative', false, 'Color', [0 0 0]); hold on
                plot(t, rBoot, 'Color', [0 0 0 .1]);
                xlim(t([1 end]));
                ylim([.3 1]);
                xlabel('Time from trigger (s)');
                ylabel('Accuracy');
                title(tb.areaName{i});
                MPlot.Axes(ax);
            end
        end
        
        function PlotOnsetDist(tb)
            
            for i = 1 : height(tb)
                % Compute histogram
                t = tb.time{1};
%                 tc = t(1:end-1) + diff(t);
                p = histcounts(tb.tOnset{i}, t, 'Normalization', 'cdf');
                
                % Plot
                color = SL.Param.GetAreaColors(tb.areaName{i});
%                 h = bar(tc, p); hold on
%                 h.BarWidth = 1;
%                 h.EdgeColor = color;
%                 h.FaceColor = color;
%                 h.FaceAlpha = 0.2;
                stairs(t, [p p(end)], 'Color', color); hold on
            end
            xlim([0 t(end)]);
            ylim([0 1]);
            xlabel('Time from trigger (s)');
            ylabel('Fraction of rs');
            legend(tb.areaName, 'Location', 'northwest');
            box off
        end
        
        % Breaks
        function PlotBreakReg(seTb, sMdl, varargin)
            % Plot decoded behavioral variables with different sequence breaks
            
            p = inputParser;
            p.addOptional('varInd', 1 : size(seTb.avgReg{1},2), @isnumeric);
            p.addParameter('AxesFun', @SL.PopFig.FormatRegAxesZZ, @(x) isa(x, 'function_handle'));
            p.parse(varargin{:});
            varInd = p.Results.varInd;
            axesFun = p.Results.AxesFun;
            
            varNames = SL.PopFig.RenameVariables(sMdl(1).subNames);
            nBk = height(seTb) - 1;
            nVar = numel(varInd);
            posColor = lines(5); % for 5 unique positions in ZZ
            posChar = char(seTb.seqId(end));
            posChar = [posChar(1)-diff(posChar([1 2])) posChar];
            axIdx = 0;
            
            L = seTb.avgStim{end}(:,1,1);
            t = seTb.time{end}(:,1,1);
            [~, tLick] = findpeaks(L, t);
            tLick = tLick(1:seTb.firstBreakStep(end));
            
            for b = 1 : nBk
                for v = 1 : nVar
                    k = varInd(v);
                    bkStep = seTb.firstBreakStep(b);
                    axIdx = axIdx + 1;
                    ax = subplot(nBk, nVar, axIdx); cla
                    
                    m = seTb.avgReg{end}(:,:,1);
                    ci1 = seTb.avgReg{end}(:,:,3);
                    ci2 = seTb.avgReg{end}(:,:,4);
                    MPlot.ErrorShade(t, m(:,k), ci1(:,k), ci2(:,k), ...
                        'IsRelative', false, ...
                        'Color', [0 0 0], ...
                        'Alpha', 0.1); hold on
                    plot(t, m(:,k), ...
                        'Color', [0 0 0], ...
                        'LineWidth', 1);
                    
                    m = seTb.avgReg{b}(:,:,1);
                    ci1 = seTb.avgReg{b}(:,:,3);
                    ci2 = seTb.avgReg{b}(:,:,4);
                    MPlot.ErrorShade(t, m(:,k), ci1(:,k), ci2(:,k), ...
                        'IsRelative', false, ...
                        'Color', SL.Param.backColor, ...
                        'Alpha', 0.1); hold on
                    plot(t, m(:,k), ...
                        'Color', SL.Param.backColor, ...
                        'LineWidth', 1);
                    
                    dt = t(2) - t(1);
                    ax.XLim = [t(1)-dt/2 t(end)+dt/2];
                    ax.XTick = [0 1 2];
                    axesFun(ax, varNames{k});
                    
                    for s = 1 : bkStep
                        p = str2double(posChar(s)) + 1;
                        plot(tLick([s s]), ax.YLim', 'Color', posColor(p,:)); hold on
                    end
                    
                    posName = SL.Behav.TranslatePosInd(posChar(bkStep), 'Z');
                    titleStr = [varNames{k} ', break@ step' num2str(seTb.firstBreakStep(b)) ...
                        ' after ' posName{1}];
                    title(titleStr);
                end
            end
        end
        
        function PlotBreakPCA(seTb, varargin)
            % Plot PC projections with different sequence breaks
            
            p = inputParser;
            p.addOptional('subInd', 1 : size(seTb.avgPCA{1},2), @isnumeric);
            p.parse(varargin{:});
            subInd = p.Results.subInd;
            
            varNames = arrayfun(@(x) ['PC' num2str(x)], subInd, 'Uni', false);
            nBk = height(seTb) - 1;
            nSub = numel(subInd);
            posColor = lines(5); % for 5 unique positions in ZZ
            posChar = char(seTb.seqId(end));
            posChar = [posChar(1)-diff(posChar([1 2])) posChar];
            axIdx = 0;
            
            L = seTb.avgStim{end}(:,1,1);
            t = seTb.time{end}(:,1,1);
            [~, tLick] = findpeaks(L, t);
            tLick = tLick(1:seTb.firstBreakStep(end));
            
            for b = 1 : nBk
                for v = 1 : nSub
                    k = subInd(v);
                    bkStep = seTb.firstBreakStep(b);
                    axIdx = axIdx + 1;
                    ax = subplot(nBk, nSub, axIdx); cla
                    
                    m = seTb.avgPCA{end}(:,:,1);
                    ci1 = seTb.avgPCA{end}(:,:,3);
                    ci2 = seTb.avgPCA{end}(:,:,4);
                    MPlot.ErrorShade(t, m(:,k), ci1(:,k), ci2(:,k), ...
                        'IsRelative', false, ...
                        'Color', [0 0 0], ...
                        'Alpha', 0.1); hold on
                    plot(t, m(:,k), ...
                        'Color', [0 0 0], ...
                        'LineWidth', 1);
                    
                    m = seTb.avgPCA{b}(:,:,1);
                    ci1 = seTb.avgPCA{b}(:,:,3);
                    ci2 = seTb.avgPCA{b}(:,:,4);
                    MPlot.ErrorShade(t, m(:,k), ci1(:,k), ci2(:,k), ...
                        'IsRelative', false, ...
                        'Color', SL.Param.backColor, ...
                        'Alpha', 0.1); hold on
                    plot(t, m(:,k), ...
                        'Color', SL.Param.backColor, ...
                        'LineWidth', 1);
                    
                    dt = t(2) - t(1);
                    ax.XLim = [t(1)-dt/2 t(end)+dt/2];
                    ax.XTick = [0 1 2];
                    
                    for s = 1 : bkStep
                        p = str2double(posChar(s)) + 1;
                        plot(tLick([s s]), ax.YLim', 'Color', posColor(p,:)); hold on
                    end
                    
                    posName = SL.Behav.TranslatePosInd(posChar(bkStep), 'Z');
                    titleStr = [varNames{k} ', break@ step' num2str(seTb.firstBreakStep(b)) ...
                        ' after ' posName{1}];
                    title(titleStr);
                end
            end
        end
        
        function PlotBreakDeviation(seTb)
            % 
            
            nBk = height(seTb) - 1;
            posColor = lines(5); % for 5 unique positions in ZZ
            posChar = char(seTb.seqId(end));
            posChar = [posChar(1)-diff(posChar([1 2])) posChar];
            axIdx = 0;
            
            L = seTb.avgStim{end}(:,1,1);
            t = seTb.time{end}(:,1,1);
            [~, tLick] = findpeaks(L, t);
            tLick = tLick(1:seTb.firstBreakStep(end));
            
            for b = 1 : nBk
                bkStep = seTb.firstBreakStep(b);
                axIdx = axIdx + 1;
                ax = subplot(nBk, 1, axIdx); cla
                
                M = squeeze(seTb.avgDevi{end});
                m = M(:,1);
                ci1 = M(:,3);
                ci2 = M(:,4);
                MPlot.ErrorShade(t, m, ci1, ci2, ...
                    'IsRelative', false, ...
                    'Color', [0 0 0], ...
                    'Alpha', 0.1); hold on
                plot(t, m, ...
                    'Color', [0 0 0], ...
                    'LineWidth', 1);
                
                M = squeeze(seTb.avgDevi{b});
                m = M(:,1);
                ci1 = M(:,3);
                ci2 = M(:,4);
                MPlot.ErrorShade(t, m, ci1, ci2, ...
                    'IsRelative', false, ...
                    'Color', SL.Param.backColor, ...
                    'Alpha', 0.1); hold on
                plot(t, m, ...
                    'Color', SL.Param.backColor, ...
                    'LineWidth', 1);
                
                dt = t(2) - t(1);
                ax.XLim = [t(1)-dt/2 t(end)+dt/2];
                ax.XTick = [0 1 2];
                
                for s = 1 : bkStep
                    p = str2double(posChar(s)) + 1;
                    plot(tLick([s s]), ax.YLim', 'Color', posColor(p,:)); hold on
                end
                
                posName = SL.Behav.TranslatePosInd(posChar(bkStep), 'Z');
                titleStr = ['break@ step' num2str(seTb.firstBreakStep(b)) ' after ' posName{1}];
                title(titleStr);
            end
        end
    end
end

