%% Behavior at Sequence Initiation

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig6');


%% Load data

dataSource = SL.Data.FindSessions('fig6_behav_stats');
seArray = SL.SE.LoadSession(dataSource.path, 'UserFunc', @(x) x.RemoveTable('adc', 'hsv', 'spikeTime', 'LFP'));

xlsTb = MBrowse.ReadXls(SL.Data.metadataSheet, 'Si');


%% Extract and preprocess data

% Determine animals and areas
animalNames = unique(dataSource.animalId);
areaNames = {'ALM'};

% Iterate through animals
for a = 1 : numel(animalNames)
    % Determine caching location
    cacheName = "extracted data " + animalNames{a} + ".mat";
    cachePath = fullfile(figDir, cacheName);
    if exist(cachePath, 'file')
        warning('%s already exists can will not be generated again', cacheName);
        continue
    end
    
    % Find the subset of data
    seSubArray = seArray(strcmp(dataSource.animalId, animalNames{a})).Duplicate;
    xlsSubTb = SL.SE.AddXlsInfo2SE(seSubArray, xlsTb);
    
    % Exclude the first and the last trial
    ops = SL.Param.Transform;
    arrayfun(@(x) SL.Behav.ExcludeTrials(x, ops), seSubArray);
    
    % Group data
    sCell = cell(size(areaNames));
    for i = 1 : numel(areaNames)
        % Find sessions for the given area
        seInd = find(strcmp(xlsSubTb.area, areaNames{i}));
        if isempty(seInd)
            warning('%s: no session can be found for %s', animalNames{a}, areaNames{i});
            continue
        end
        se = Merge(seSubArray(seInd));
        
        % Extract data
        s = struct;
        [s.ind, s.lickObj] = SL.Opto.ExtractInitData(se);
        
        sCell{i} = s;
    end
    areaTb = cell2table(sCell, 'VariableNames', areaNames, 'RowNames', animalNames(a));
    
    save(cachePath, 'areaTb');
end


%% Find and load extracted data

cacheSearch = MBrowse.Dir2Table(fullfile(figDir, "extracted data *.mat"));
cachePaths = fullfile(cacheSearch.folder, cacheSearch.name);

areaCell = cell(size(cachePaths));
for i = 1 : numel(cachePaths)
    load(cachePaths{i});
    areaCell{i} = areaTb;
end
areaTb = vertcat(areaCell{:});


%% 

% Histogram parameters
lickId = (1 : 3)';
aEdges = -60:5:60;
lEdges = 0:.2:5;
qTb = table();
qTb.name = {'angle', 'length'}';
qTb.edges = {aEdges, lEdges}';

% Preallocation
nId = numel(lickId);
[nMice, nArea] = size(areaTb);
qTb.hist{1} = zeros(numel(aEdges)-1, nId, nArea, nMice);
qTb.hist{2} = zeros(numel(lEdges)-1, nId, nArea, nMice);
cdfExp = zeros(numel(aEdges)-1, nArea, nMice);
cdfTouch = zeros(numel(aEdges)-1, nArea, nMice);

for i = 1 : nMice
    for j = 1 : nArea
        % Get licks from trials with no opto
        s = areaTb{i,j};
        licks = s.lickObj(s.ind.none);
        
        % 
        firstTouch = cellfun(@(x) find(x.IsTouch,1), licks, 'Uni', false);
        
        maxAngle = cellfun(@(x,y) max(x(1:y).ShootingAngle), licks, firstTouch);
        cdfExp(:,j,i) = histcounts(maxAngle, aEdges, 'Normalization', 'cdf');
        
        touchAngle = cellfun(@(x,y) x(y).ShootingAngle, licks, firstTouch);
        cdfTouch(:,j,i) = histcounts(-touchAngle, aEdges, 'Normalization', 'cdf');
        
        % Vectorize all licks
        licks = cat(1, licks{:});
        
        % Label licks
        licks = licks.SetVfield('lickId', licks.GetVfield('startId'));
        
        % Compute histograms
        histTb = SL.Behav.ComputeLickStats(licks, qTb, lickId);
        qTb.hist{1}(:,:,j,i) = histTb.angle';
        qTb.hist{2}(:,:,j,i) = histTb.length';
    end
end

% Compute mean stats
for i = 1 : height(qTb)
    [qTb.mean{i}, qTb.sd{i}] = MMath.MeanStats(qTb.hist{i}, 4);
end

[cdfExpMean, cdfExpSD] = MMath.MeanStats(cdfExp, 3);
pSide = squeeze(mean(cdfExp(12:13,:,:), 1));
pSideMean = mean(pSide);

[cdfTouchMean, cdfTouchSD] = MMath.MeanStats(cdfTouch, 3);


%% Plot

f = MPlot.Figure(446); clf

% Sequential angle and length distributions
for i = 1 : height(qTb)
    [m, sd] = MMath.MeanStats(qTb.hist{i}, 4);
    b = qTb.edges{i}(ones(1,nId),:)';
    cc = [0 0 0]+.1;
    
    ax = subplot(1,3,i); hold on
    ax.XLim = [.3 nId+.7];
    ax.XTick = lickId;
    switch qTb.name{i}
        case 'angle'
            plot(ax.XLim', [0 0]', 'Color', [0 0 0]+.8);
            ax.YLim = [-1 1]*50;
            ax.YTick = [-1 0 1]*30;
            ylabel('\Theta_{shoot} (deg)');
        case 'length'
            ax.YLim = [0 4.5];
            ax.YTick = 0:2:4;
            ylabel('L_{max} (mm)');
    end
    MPlot.Axes(ax);
    
    MPlot.Violin(lickId, b, (m+sd/2)*3, 'Color', [0 0 0], 'Alpha', .15, 'Style', 'patch');
    MPlot.Violin(lickId, b, m*3, 'Percentiles', [25 50 75], 'Color', cc, 'Style', 'patch');
end

% CDF of max exploration
ax = subplot(1,3,3); hold on
c = aEdges(1:end-1) + diff(aEdges)/2;
plot(c', squeeze(cdfExp), 'Color', [0 0 0 .2]);

% MPlot.ErrorShade(c', cdfExpMean, cdfExpSD, 'Color', 'k')
plot(c', cdfExpMean, 'Color', 'k');
plot([-1 1]*50, pSideMean([1 1]), 'b');

% MPlot.ErrorShade(c', cdfTouchMean, cdfTouchSD, 'Color', 'k')
% plot(c', cdfTouchMean, '--', 'Color', 'k');

% MPlot.ErrorShade(c', flip(1-cdfTouchMean), flip(cdfTouchSD), 'Color', 'k')
% plot(c', flip(1-cdfTouchMean), '--', 'Color', 'k');

ax.XLim = [-1 1]*50;
ax.YLim = [0 1];
ax.YTick = [0 .5 round(pSideMean,2) 1];
xlabel('Max \Theta_{shoot} explored (deg)');
ylabel('Probability');

MPlot.Paperize(f, 'ColumnsWide', 1, 'ColumnsHigh', .3);
saveFigurePDF(f, fullfile(figDir, 'init stats'));

