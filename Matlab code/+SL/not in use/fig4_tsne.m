% Compute and plot functional clusters of unit

datDir = SL.Param.GetAnalysisRoot;
figDir = fullfile(datDir, SL.Param.figDirName, 'Fig4');

% Load unit tables
load(fullfile(figDir, 'computed urTbCell.mat'));
load(fullfile(figDir, 'computed uqTbCell.mat'));
urTb = vertcat(urTbCell{:});
qtTb = vertcat(uqTbCell{:});

% Group S1FL into S1L
urTb.areaName = strrep(urTb.areaName, 'S1FL', 'S1L');

% Select units
isActive = urTb.peakSpkRate >= 10; % Hz
isSingle = uqTb.FA <= SL.Param.maxFA & uqTb.contam <= SL.Param.maxContam;
isInAOI = ismember(urTb.areaName, {'ALM', 'M1TJ', 'S1TJ', 'S1BF', 'M1B', 'S1L'});
unitTb = urTb(isActive & isSingle & isInAOI, :);

% t-SNE results
cachePath = fullfile(fullfile(figDir, 'computed tsne.mat'));

if exist(cachePath, 'file')
    % Load Previously computed results
    load(cachePath);
else
    % Select features
    X = unitTb{:,{'hh1', 'hh2', 'hh3', 'hh4', 'hh5', 'hh6'}};
    X = downsample(X', 10, 4)';
    
    % Run with different random number states
    randList = 1:50;
    sClust = cell(numel(randList), 1);
    for i = 1 : numel(randList)
        rng(randList(i));
        sClust{i} = SL.Unit.TsneClustering(X);
        fprintf('%d: BIC %d components\n', i, sClust{i}.gmmBest.NumComponents);
    end
    sClust = cat(1, sClust{:});
    
    save(cachePath, 'sClust');
end


%% Find the best t-SNE clustering

% Show effect of random numbers on the number of components
numCompALL = arrayfun(@(x) x.gmmBest.NumComponents, sClust);
numComp = median(numCompALL);
% numComp = 8;

% Plot distribution
f = MPlot.Figure(119); clf
histogram(numCompALL, 0.5:20.5);
ax = MPlot.Axes(gca);
ax.Title.String = ['Median = ' num2str(median(numCompALL))];
ax.XLabel.String = 'Number of clusters';
ax.YLabel.String = 'Number of runs';
MPlot.Paperize(f, 'ColumnsWide', .5, 'AspectRatio', .66);
saveFigurePDF(f, fullfile(figDir, "tsne num component"));


%% Plot the representative run

% Select the first run with median components
runIdx = find(numCompALL == numComp, 1);
gmmBest = sClust(runIdx).gmmBest;
unitTb.coorEmbed = sClust(runIdx).coorEmbed;
[unitTb.clustId, ~, ~, unitTb.clustScore] = cluster(gmmBest, sClust(runIdx).coorEmbed);

% Plot clustering
areaNames = unique(unitTb.areaName, 'stable');
numAreas = numel(areaNames);
cc = lines(numAreas);
xLims = [min(unitTb.coorEmbed(:,1)) max(unitTb.coorEmbed(:,1))] + [-5 5]*0;
yLims = [min(unitTb.coorEmbed(:,2)) max(unitTb.coorEmbed(:,2))] + [-5 5]*0;

f = MPlot.Figure(126);

ax = subplot(1,2,1); cla
for i = 1 : numAreas
    isArea = strcmp(unitTb.areaName, areaNames{i});
    Y = unitTb.coorEmbed(isArea,:);
    h = plot(Y(:,1), Y(:,2), '.', 'Color', 'k', 'MarkerSize', 3); hold on
    h.Tag = areaNames{i};
end
ax.XLim = xLims;
ax.YLim = yLims;
axis square off

ax = subplot(1,2,2); cla
gscatter(unitTb.coorEmbed(:,1), unitTb.coorEmbed(:,2), unitTb.clustId, [], '.', 3); hold on
fcontour(@(x1,x2) pdf(gmmBest, [x1 x2]), [-40 40 -40 40]);
text(gmmBest.mu(:,1), gmmBest.mu(:,2), arrayfun(@num2str, 1:numComp, 'Uni', false)', ...
    'FontSize', 6, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
ax.XLim = xLims;
ax.YLim = yLims;
axis square off
legend off

brushObj = brush(gcf);
brushObj.ActionPostCallback = {@SL.Unit.PlotClusterCallback, unitTb};

MPlot.Paperize(f, 'ColumnsWide', .75, 'ColumnsHigh', .33);
saveFigurePDF(f, fullfile(figDir, "tsne embedding"));


%% Extract cluster data

clear('clustTb');
for i = numComp : -1 : 1
    isClust = unitTb.clustId == i;
    clustTb(i) = SL.Unit.ClusterStats(unitTb(isClust,:));
end
clustTb = struct2table(clustTb);


%% Reorder clusters

mmMax = cellfun(@(x) max(x(:,1:2:6), x(:,2:2:6)), clustTb.mm, 'Uni', false);
mmMax = cellfun(@(x) x(:), mmMax, 'Uni', false);
mmMax = cat(2, mmMax{:});
[~, compInd] = SL.Unit.SortPETHs(mmMax, 'peak');

newClustId = unitTb.clustId;
for i = 1 : numel(compInd)
    newClustId(unitTb.clustId == compInd(i)) = i;
end
unitTb.clustId = newClustId;
clustTb = clustTb(compInd,:);


%% Plot cluster means

f = MPlot.Figure(225); clf
SL.UnitFig.PlotClusterMean(clustTb);
MPlot.Paperize(f, 'ColumnsWide', 0.5, 'AspectRatio', 2);
saveFigurePDF(f, fullfile(figDir, "tsne cluster mean"));


return

%% Plot Heatmaps

areaNames = clustTb.areaName(1,:);
areaNames = {'M2ALM', 'M1TJ', 'S1TJ', 'S1BF'};
% areaNames = {'S1BF'};

for i = 1 : numel(areaNames)
    isArea = strcmp(areaNames{i}, unitTb.areaName);
    unitSubTb = sortrows(unitTb(isArea,:), {'clustId', 'clustScore'});
%     rng(61);
%     isSampled = sort(randsample(height(unitSubTb), 100));
%     unitSubTb = unitSubTb(isSampled,:);
    
    f = MPlot.Figure(10+i); clf
    SL.UnitFig.PlotHeatmap(unitSubTb, 1:10);
    MPlot.Paperize(f, 'ColumnsWide', 1, 'ColumnsHigh', .5);
    saveFigurePDF(f, fullfile(figDir, "PETH heatmap " + areaNames{i}));
end


%% Area composition

MPlot.Figure(226); clf

areaNames = clustTb.areaName(1,:);
areaP = clustTb.areaNameN;
areaP = areaP(compInd,:);

imagesc(areaP);

ax = MPlot.Axes(gca);
ax.XTick = 1 : numel(areaNames);
ax.XTickLabel = areaNames;
ax.XTickLabelRotation = 60;
ax.YTickLabel = compInd;
ax.TickLength(1) = 0;
colormap copper
cb = colorbar;
cb.TickLength = 0;
cb.Box = 'off';

% MPlot.Paperize(gcf, 'ColumnsWide', .33, 'ColumnsHigh', .5); % 2.8, 4.25




