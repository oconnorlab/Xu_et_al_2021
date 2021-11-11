% Compute changes in lick and touch probability by areas and plot brain overlays

datDir = SL.Param.GetAnalysisRoot;

if ~exist('powerName', 'var')
    powerName = "5V";
end
figDir = fullfile(datDir, SL.Param.figDirName, 'Fig3', powerName);


%% Compute opto manipulation effects

cachePath = fullfile(figDir, 'computed summary.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Find and load extracted data
    cacheSearch = MBrowse.Dir2Table(fullfile(figDir, "aaTb *.mat"));
    cachePaths = fullfile(cacheSearch.folder, cacheSearch.name);
    aaTb = SL.Opto.LoadAnimalAreaTable(cachePaths);
    aaCell = aaTb{:,:};
    clear aaTb
    
    % Label licks
    aaCell = SL.Opto.IndexLicks(aaCell);
    
    resultCell = cell(size(aaCell));
    for i = 1 : numel(aaCell)
        lkTb = aaCell{i};
        s = resultCell{i};
        
        % Configure pipeline
        tEdges = repmat([0 1]', [1 3]);
        s.pLick.tEdges = tEdges;
        s.pLick.pCI = 0;
        s.pTouch.tEdges = tEdges;
        s.pTouch.pCI = 0;
        s.mod.tEdges = tEdges;
        s.len.tEdges = tEdges;
        s.ang.tEdges = repmat((0 : .2 : 1)', [1 3]);
        
        % Run pipeline
        s = SL.Opto.ComputeTraces(lkTb, s);
        
        % Plotting parameters
        s.info.optoDur = 2;
        s.info.optoType = {'Init', 'Mid', 'Cons'};
        
        
%         % Compute lick quantity stats
%         lickObjArray = cellfun(@(x) cat(1,x{:}), condTb.lickObj, 'Uni', false);
%         
%         quantTb = table();
%         quantTb.name = {'angle', 'length'}';
%         quantTb.edges = {30:5:150, 0:.2:5}';
%         
%         lickIds = 1:6;
%         
%         labelList = {'initId', 'midId', 'consId'};
%         nOpto = numel(labelList);
%         s.statOpto = cell(1,nOpto);
%         s.statCtrl = cell(1,nOpto);
%         
%         for j = 1 : numel(labelList)
%             lickObj = lickObjArray{j};
%             lickObj = lickObj.SetVfield('lickId', lickObj.GetVfield(labelList{j}));
%             [~, s.statOpto{1,j}] = SL.Behav.ComputeLickStats(lickObj, quantTb, lickIds);
%             
%             lickObj = lickObjArray{4};
%             lickObj = lickObj.SetVfield('lickId', lickObj.GetVfield(labelList{j}));
%             [~, s.statCtrl{1,j}] = SL.Behav.ComputeLickStats(lickObj, quantTb, lickIds);
%         end
        
        % Store variables
        resultCell{i} = s;
    end
    
    save(cachePath, 'resultCell');
end


%% Compute average differences between opto and ctrl

% Derive values from each result struct
diffCell = cell(size(resultCell));
for i = 1 : numel(resultCell)
    s = resultCell{i};
    r = struct;
    
    % Select window to average
    ind = 1:5;
    
    % Lick and touch probability
    r.pLickRatio = nanmean(s.pLick.opto(:,:,1), 1) ./ nanmean(s.pLick.ctrl(:,:,1), 1);
    r.pTouchRatio = nanmean(s.pTouch.opto(:,:,1), 1) ./ nanmean(s.pTouch.ctrl(:,:,1), 1);
    
    % Kinematics by time
    r.lenDiff = nanmean(s.len.opto(:,:,1) - s.len.ctrl(:,:,1), 1);
    r.modRatio = nanmean(s.mod.opto(:,:,1) ./ s.mod.ctrl(:,:,1), 1);
    r.randRatio = nanmean(s.ang.opto(:,:,2), 1) ./ nanmean(s.ang.ctrl(:,:,2), 1);
    
%     % Kinematics by #licks
%     r.lenDiff = cellfun(@(x,y) nanmean(x.lengthMean(ind) - y.lengthMean(ind)), s.statOpto, s.statCtrl);
%     r.modRatio = cellfun(@(x,y) nanmean(abs(x.angleMean(ind))) / nanmean(abs(y.angleMean(ind))), s.statOpto, s.statCtrl);
%     r.randRatio = cellfun(@(x,y) nanmean(x.angleSD(ind)) / nanmean(y.angleSD(ind)), s.statOpto, s.statCtrl);
    
    diffCell{i} = r;
end

% Reshape numbers into matrices (animal-by-condition-by-area)
sMat = SL.Opto.ReshapeSummaryStats(diffCell);


%% Plot

labelList = { ...
    'pLickRatio',   '{\color[rgb]{0,.6,1}P(lick)} / P(lick)'; ...
    'pTouchRatio',  '{\color[rgb]{0,.6,1}P(touch)} / P(touch)'; ...
    'lenDiff',      '{\color[rgb]{0,.6,1}L_{max}} - L_{max}'; ...
    'modRatio',     '{\color[rgb]{0,.6,1}|\Theta_{shoot}|} / |\Theta_{shoot}|'; ...
    'randRatio',    '{\color[rgb]{0,.6,1}SD(\theta_{shoot})} / SD(\theta_{shoot})'; ...
    };
getLabel = @(x) replace(x, labelList(:,1), labelList(:,2));
quantNames = {'pLickRatio', 'lenDiff', 'modRatio', 'randRatio'};
nQuant = numel(quantNames);

areaInd = [1 2 4 3 5];
areaNames = cellfun(@(x) x.info.area, resultCell(1,areaInd), 'Uni', false);
condNames = resultCell{1}.info.optoType;
[nAnimal, nCond, nArea] = size(sMat.pLickRatio);
ccCond = winter(nCond+1);

f = MPlot.Figure(158); clf

for k = 1 : nQuant
    qn = quantNames{k};
    
    % Format axes
    ax = subplot(nQuant, 1, k);
    MPlot.Axes(ax); hold on
    ax.XLim = [.25 nArea+.75];
    ax.XTick = 1:nArea;
    ax.XTickLabel = areaNames;
    ax.XTickLabelRotation = 0;
    switch qn
        case {'pLickRatio', 'pTouchRatio'}
            plot(ax.XLim, [1 1], 'Color', [0 0 0 .15]);
            ax.YLim = [-.1 1.8];
        case 'lenDiff'
            plot(ax.XLim, [0 0], 'Color', [0 0 0 .15]);
            ax.YLim = [-2 1];
            ylabel('mm');
        case 'modRatio'
            plot(ax.XLim, [1 1], 'Color', [0 0 0 .15]);
            ax.YLim = [.2 1.6];
        case 'randRatio'
            plot(ax.XLim, [1 1], 'Color', [0 0 0 .15]);
            ax.YLim = [-.2 3];
    end
    title(getLabel(qn));
    
    for i = 1 : nCond
        x = (1:nArea)+i*.2-.4;
        xx = repmat(x, [nAnimal 1]);
        yy = squeeze(sMat.(qn)(:,i,areaInd));
        
        p = zeros(size(x));
        g = zeros(size(x));
        for j = 1 : numel(x)
            if size(yy,1) > 4
                g(j) = lillietest(yy(:,j));
            end
            switch qn
                case {'pLickRatio', 'pTouchRatio', 'modRatio', 'randRatio'}
                    [~, p(j)] = ttest(yy(:,j), 1);
                case 'lenDiff'
                    [~, p(j)] = ttest(yy(:,j), 0);
            end
        end
        [~, ~, p] = histcounts(p, [0 .001 .01 .05 1]);
        p = 4-p;
        
        py = ones(size(p))*ax.YLim(2);
        py(p==0) = NaN;
        text(x, py, string(p), 'Horizontal', 'center');
        
        py = ones(size(p))*ax.YLim(2);
        py(g==0) = NaN;
        text(x, py, string(p), 'Horizontal', 'center', 'Color', 'r');
        
        plot(xx, yy, 'x', 'Color', ccCond(i,:));
        MPlot.PlotPointAsLine(x, mean(yy), .2, ...
            'Orientation', 'horizontal', 'Color', 'r', 'LineWidth', 1);
    end
end

MPlot.Paperize(f, 'ColumnsWide', .5, 'ColumnsHigh', 1.4);
saveFigurePDF(f, fullfile(figDir, "summary stats"));




