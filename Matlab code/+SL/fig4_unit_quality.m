%% Quality

datDir = SL.Data.analysisRoot;
figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig4');

% Find data
dataSource = SL.Data.FindSessions('fig4_unit_quality');
sePaths = dataSource.path;

xlsTb = MBrowse.ReadXls(SL.Data.metadataSheet, 'Si');


%% Compute unit quality stats

cachePath = fullfile(figDir, 'computed uqTbCell.mat');

if exist(cachePath, 'file')
    % Load previously computed data
    load(cachePath);
else
    % Compute new
    uqTbCell = cell(size(sePaths));
    
    % Loop through sessions
    parfor i = 1 : numel(sePaths)
        % Load SE and add metadata from spreadsheet
        se = SL.SE.LoadSession(sePaths{i}, 'UserFunc', @(x) x.RemoveTable('LFP', 'adc', 'hsv'));
        SL.SE.AddXlsInfo2SE(se, xlsTb);
        disp(SL.SE.GetID(se));
        
        % Compute unit table
        uqTb = SL.Unit.UnitQuality(se);
        uqTbCell{i} = uqTb;
    end
    
    save(cachePath, 'uqTbCell', 'dataSource');
end


%% Session and area summaries

% Remove off-target units
areaList = {'ALM', 'M1TJ', 'M1B', 'S1TJ', 'S1L', 'S1BF'};
for i = 1 : numel(uqTbCell)
    uqTb = uqTbCell{i};
    
    % Group S1FL into S1L
    uqTb.areaName = strrep(uqTb.areaName, 'S1FL', 'S1L');
    
    % Keep units in the area of interest
    uqTb = uqTb(ismember(uqTb.areaName, areaList), :);
    
    uqTbCell{i} = uqTb;
end

% Summarize unit quality by sessions
sqTb = cell(size(uqTbCell));
for i = 1 : numel(uqTbCell)
    uqTb = uqTbCell{i};
    tbRow = uqTb(1,1:3);
    tbRow.numUnits = height(uqTb);
    tbRow.numFA = sum(uqTb.FA > SL.Param.maxFA);
    tbRow.numContam = sum(uqTb.contam > SL.Param.maxContam);
    tbRow.numMulti = sum(uqTb.contam > SL.Param.maxContam | uqTb.FA > SL.Param.maxFA);
    tbRow.numSingle = tbRow.numUnits - tbRow.numMulti;
    sqTb{i} = tbRow;
end
sqTb = vertcat(sqTb{:});

% Set order to the areas
sqTb.areaName = categorical(sqTb.areaName, ...
    {'ALM', 'M1TJ', 'M1B', 'S1TJ', 'S1L', 'S1BF'}, ...
    'Ordinal', true);

% Summarize each area
[groupId, aqTb] = findgroups(sqTb(:,'areaName'));
for i = 1 : width(sqTb)
    vn = sqTb.Properties.VariableNames{i};
    val = sqTb.(vn);
    if isnumeric(val)
        aqTb.(vn) = splitapply(@sum, val, groupId);
    elseif ~strcmp(vn, 'areaName')
        aqTb.(vn) = splitapply(@(x) {unique(x)}, val, groupId);
    end
end

% Add total #unit in each area back to session table
N = splitapply(@sum, sqTb.numUnits, groupId);
sqTb.numAreaUnits = N(groupId);


%% Show summary stats

% Unpack variables
uqTbFull = vertcat(uqTbCell{:});
rMean = uqTbFull.meanSpkRate;
FA = uqTbFull.FA;
C = uqTbFull.contam;
isFA = FA > SL.Param.maxFA;
isContam = C > SL.Param.maxContam;
isSingle = ~(isFA | isContam);


% Print overall percentages
fileID = fopen(fullfile(figDir, 'unit quality stats.txt'), 'w');
fprintf(fileID, '%d sessions\n', height(sqTb));
fprintf(fileID, '%d units (%g ± %g per session)\n', ...
    sum(sqTb.numUnits), mean(sqTb.numUnits), std(sqTb.numUnits));
fprintf(fileID, '%d single-units (%g ± %g per session)\n', ...
    sum(sqTb.numSingle), mean(sqTb.numSingle), std(sqTb.numSingle));
fprintf(fileID, '%d multi-units (%g ± %g per session)\n', ...
    sum(sqTb.numMulti), mean(sqTb.numMulti), std(sqTb.numMulti));
fprintf(fileID, '%.1f%% units failed RP violation threshold at %g%%\n', ...
    mean(isFA)*100, SL.Param.maxFA);
fprintf(fileID, '%.1f%% failed contamination threshold at %g%%\n', ...
    mean(isContam)*100, SL.Param.maxContam);
fprintf(fileID, '%.1f%% failed both\n\n', ...
    mean(isFA | isContam)*100);
fclose(fileID);


% Distributions by units
f = MPlot.Figure(3111); clf

subplot(2,2,1);
FAlim = 3;
FAcut = MMath.Bound(FA, [0 FAlim]);
histogram(FAcut, 0:.02:FAlim, 'Normalization', 'cumcount', ...
    'EdgeColor', 'none', 'FaceColor', [0 0 0]); hold on
histogram(FAcut(isSingle), 0:.02:FAlim, 'Normalization', 'cumcount', ...
    'EdgeColor', 'none', 'FaceColor', [0 .7 0]);
ax = MPlot.Axes(gca);
ax.YLim = [0 numel(FA)];
ax.XTick = 0:.5:FAlim;
ax.YTick = linspace(0, numel(FA), numel(0:.2:1));
ax.YTickLabel = 0:.2:1;
xlabel('Refractory period violation rate (%)');
ylabel('Fraction of units');

% subplot(2,2,2);
% histogram(rMean, 0:60, 'EdgeColor', 'none', 'FaceColor', [0 0 0]); hold on
% histogram(rMean(isSingle), 0:60, 'EdgeColor', 'none', 'FaceColor', [0 .7 0]);
% ax = MPlot.Axes(gca);
% xlabel('Mean spike rate (spk/s)');
% ylabel('# of units');

subplot(2,2,3);
MPlot.Blocks([0, FAlim*1.01], [SL.Param.maxContam, 50*1.01], [0 0 0], 'FaceAlpha', .1); hold on
MPlot.Blocks([SL.Param.maxFA, FAlim*1.01], [0, 50*1.01], [0 0 0], 'FaceAlpha', .1);
plot(FAcut(~isSingle), C(~isSingle), 'k.', 'MarkerSize', 3);
plot(FAcut(isSingle), C(isSingle), '.', 'Color', [0 .7 0], 'MarkerSize', 5);
ax = MPlot.Axes(gca);
ax.XTick = 0:.5:FAlim;
ax.YTick = 0:10:50;
axis tight
xlabel('Refractory period violation rate (%)');
ylabel('Contamination rate (%)');

subplot(2,2,4);
histogram(C, 0:.2:50, 'Normalization', 'cumcount', ...
    'EdgeColor', 'none', 'FaceColor', [0 0 0]); hold on
histogram(C(isSingle), 0:.2:50, 'Normalization', 'cumcount', ...
    'EdgeColor', 'none', 'FaceColor', [0 .7 0]);
ax = MPlot.Axes(gca);
ax.YLim = [0 numel(C)];
ax.XTick = 0:10:50;
ax.XTickLabel = ax.XTick;
ax.YTick = linspace(0, numel(C), numel(0:.2:1));
ax.YTickLabel = 0:.2:1;
xlabel('Contamination rate (%)');
ylabel('Fraction of units');


% Number of units for each sessions
aqTbSorted = sortrows(aqTb, 'numUnits', 'descend');
sqTbSorted = sortrows(sqTb, {'numAreaUnits', 'numUnits'}, 'descend');

subplot(2,2,2);
bar(sqTbSorted.numUnits, 'EdgeColor', 'none', 'FaceColor', 'k'); hold on
bar(sqTbSorted.numSingle, 'EdgeColor', 'none', 'FaceColor', [0 .7 0]);
[xGroups, yGroups] = MPlot.GroupRibbon(sqTbSorted.areaName, [-2 0]-2, ...
    SL.Param.GetAreaColors(aqTbSorted.areaName), ...
    'Groups', aqTbSorted.areaName);
text(xGroups, yGroups-5, string(aqTbSorted.areaName), ...
    'Horizontal', 'right', 'Rotation', 45);
ax = MPlot.Axes(gca);
ax.XTick = [];
ylabel('# of units');


MPlot.Paperize(f, 'ColumnsWide', 1, 'AspectRatio', .66);
saveFigurePDF(f, fullfile(figDir, "unit quality summary"));


%% Plot example ISI histograms

% Randomly sample a subset of unit as examples
rng(61);
indEg = randsample(find(isSingle), 30);

f = MPlot.Figure(3116); clf
for i = 1 : numel(indEg)
    subplot(5,6,i);
    k = indEg(i);
    x = uqTbFull.isiEdges{k};
    x = x(1:end-1) + diff(x)/2;
    y = uqTbFull.isiCount{k};
    
    h = bar(x, y, 'histc');
    h.FaceColor = [0 .7 0];
    h.EdgeColor = 'none';
    
    MPlot.Blocks([0 SL.Param.minISI], [0 max(y)], [1 0 0], 'FaceAlpha', .3);
    
    axis tight off
    xlim([0 0.02])
    title([num2str(uqTbFull.FA(k),'%.1f') ' / ' num2str(uqTbFull.contam(k),'%.1f')]);
end

MPlot.Paperize(f, 'FontSize', 4, 'ColumnsWide', 1, 'AspectRatio', .66);
saveFigurePDF(f, fullfile(figDir, "ISI histograms"));


return

%%

% load(fullfile(figDir, 'fig3_heatmaps unitTbFull.mat'));
% urTbFull = unitTbFull;

indPoor = find(C > 15 & FA < 1);

MPlot.Figure(3119); clf
SL.UnitFig.PlotPopPETH(urTbFull(indPoor,:), 'heatmap');


%%

randInd = randsample(indPoor, 1);
randInd
uqTbFull(randInd,[1:3 6 end-2:end])
SL.UnitFig.PlotPopPETH(urTbFull(randInd,:), 'trace');




