%% Functional clustering of unit

% Find se files
figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig4');
dataSource = SL.Data.FindSessions('fig4_nnmf');
sePaths = dataSource.path;

% Load metadata
xlsTb = MBrowse.ReadXls(SL.Data.metadataSheet, 'Si');

% Load previosuly computed unit quality info and select sessions for current analysis
s = load(fullfile(figDir, 'computed uqTbCell.mat'));
I = ismember(s.dataSource.sessionId, dataSource.sessionId);
uqTbCell = s.uqTbCell(I);


%% Compute PETHs

cachePath = fullfile(figDir, 'computed urTbCell.mat');

if exist(cachePath, 'file')
    % Load previously computed data
    load(cachePath);
else
    % Compute new
    urTbCell = cell(size(sePaths));
    
    parfor i = 1 : numel(sePaths)
        % Load SE and add metadata from spreadsheet
        se = SL.SE.LoadSession(sePaths{i}, 'UserFunc', @(x) x.RemoveTable('LFP', 'adc', 'hsv'));
        SL.SE.AddXlsInfo2SE(se, xlsTb);
        disp(SL.SE.GetID(se));
        
        % Computing spike rates, morphing, reslicing, trial exclusion
        ops = SL.Param.Transform;
        ops = SL.Param.Resample(ops);
        ops.isMorph = true;
        ops.tReslice = -1;
        ops.maxReactionTime = 1;
        ops.maxEndTime = 8;
        SL.SE.Transform(se, ops);
        
        % Skip processed steps in later transformation
        ops.isSpkRate = false;
        ops.isMorph = false;
        ops.tReslice = 0;
        
        % Matching
        alignTypes = {'init', 'mid', 'term'};
        seTbCat = cell(size(alignTypes));
        for j = 1 : numel(alignTypes)
            disp(alignTypes{j});
            
            % Complete matching options
            ops.alignType = alignTypes{j};
            ops = SL.Param.FillMatchOptions(ops);
            
            % Transform SE
            seCopy = se.Duplicate;
            seTb = SL.SE.Transform(seCopy, ops);
            
            % Select conditions
            conds = cell2table({ ...
                '123456', -1; ...
                '543210', -1; ...
                }, 'VariableNames', ops.conditionVars);
            conds.seqId = SL.Param.CategorizeSeqId(conds.seqId);
            seTbCat{j} = SL.SE.CombineConditions(conds, seTb, 'Uni', true);
        end
        seTbCat = cat(1, seTbCat{:});
        
        % Compute unit table
        unitInfo = SL.Unit.UnitInfo(se);
        unitPETH = SL.Unit.UnitPETH(seTbCat.se);
        unitPETH.unitNum = [];
        urTbCell{i} = [unitInfo unitPETH];
    end
    
    save(cachePath, 'urTbCell', 'dataSource');
end


%% Construct input

urTb = vertcat(urTbCell{:});
uqTb = vertcat(uqTbCell{:});

% Group S1FL into S1L
urTb.areaName = strrep(urTb.areaName, 'S1FL', 'S1L');

% Select units
isActive = urTb.peakSpkRate >= 10; % Hz
isSingle = uqTb.FA <= SL.Param.maxFA & uqTb.contam <= SL.Param.maxContam;
isInAOI = ismember(urTb.areaName, {'ALM', 'M1TJ', 'S1TJ', 'S1BF', 'M1B', 'S1L'});
unitTb = urTb(isActive & isSingle & isInAOI, :);

% Construct input
X = unitTb{:,{'hh1', 'hh2', 'hh3', 'hh4', 'hh5', 'hh6'}};
X = downsample(X', 10, 4)';
% X = X ./ (max(X, [], 2) + SL.Param.normAddMax);
X = X ./ max(X, [], 2);


%% NNMF clustering with bootstrap crossvalidation

cachePath = fullfile(figDir, 'boot nnmfs.mat');

if exist(cachePath, 'file')
    % Load cached result
    load(cachePath);
else
    % Choose the number of clusters to compute
    nCompList = 6 : 20;
    
    % Bootstrap clustering
    sClust = cell(numel(nCompList),1);
    for i = 1 : numel(nCompList)
        sClust{i} = SL.Unit.NNMFBoot(X, 'nComp', nCompList(i), 'nBoot', 1e3, 'fraction', .5);
    end
    sClust = cat(1, sClust{:});
    save(cachePath, 'nCompList', 'sClust');
end


%% Component templates of different cluster #

f = MPlot.Figure(46534); clf
f.WindowState = 'maximized';
nComp2Plot = 9 : 14;
for i = 1 : numel(nComp2Plot)
    subplot(1, numel(nComp2Plot), i);
    k = nCompList == nComp2Plot(i);
    W = SL.Unit.SplitVectorized(sClust(k).W0);
    x = (1:144)';
    h = 10:10:size(W,2)*10;
    MPlot.PlotTraceLadder(x, W(:,:,1), h, 'Color', 'r'); hold on
    MPlot.PlotTraceLadder(x, W(:,:,2), h, 'Color', 'b');
    ylim([0 max(nComp2Plot)*10]+10);
    title([num2str(nComp2Plot(i)) ' comp']);
end
MPlot.SavePNG(f, fullfile(figDir, 'nnmf templates'));


%% Consistency of cluster membership

% The probability of a unit being groups in the same cluster across bootstrap iterations
P = cat(2, sClust.maxProb);
[Pmean, ~, ~, Pci] = MMath.MeanStats(P);

% Mean±CI probability across different cluster #
f = MPlot.Figure(46533); clf
errorbar(nCompList, Pmean, Pmean-Pci(1,:), Pci(2,:)-Pmean, 'Color', 'k'); hold on
% plot(nCompList, 1./nCompList, 'Color', [0 0 0 .5]);
ax = gca;
ax.XLim = [-1 1] + nCompList([1 end]);
ax.XTick = nCompList;
xlabel('# of clusters');
ylabel('P(same cluster)');
title('Consistency of cluster membership');
MPlot.Axes(gca);
MPlot.Paperize(f, 'ColumnsWide', .5, 'ColumnsHigh', .3);
MPlot.SavePDF(f, fullfile(figDir, 'nnmf p same mean'));

% CDFs of the probability with different cluster #
f = MPlot.Figure(46532); clf
f.WindowState = 'maximized';
for i = 1 : numel(nCompList)
    ax = subplot(3,5,i);
    binEdges = 0:.02:1;
    N = histcounts(P(:,i), binEdges, 'Normalization', 'cdf');
    stairs(binEdges(1:end-1), N); hold on
    plot(1./nCompList([i i]), [0 1], '--', 'Color', [0 0 0]);
    xlim([0 1]);
    ylim([0 1]);
    title([num2str(nCompList(i)) ' comp, mean P(same) = ' num2str(Pmean(i),2)]);
    grid on
end
MPlot.SavePNG(f, fullfile(figDir, 'nnmf p same cdf'));


%% 

% rng(13);
% s = SL.Unit.NNMFClustering(X, 13);
% W = SL.Unit.SplitVectorized(s.W);
% h = 10:10:size(W,2)*10;
% 
% figure(1); clf
% MPlot.PlotTraceLadder(x, W(:,:,1), h, 'Color', 'r'); hold on
% MPlot.PlotTraceLadder(x, W(:,:,2), h, 'Color', 'b');
% ylim([0 max(h)+10]);
% title(num2str(size(W,2)));


%% Extract cluster data

[~, k] = max(Pmean);
nComp = nCompList(k);
unitTb.clustId = sClust(k).maxId;
unitTb.clustScore = -sClust(k).maxIdScore;

clear clustTb
for i = nComp : -1 : 1
    isClust = unitTb.clustId == i;
    clustTb(i) = SL.Unit.ClusterStats(unitTb(isClust,:));
end
clustTb = struct2table(clustTb);

cachePath = fullfile(figDir, 'extracted nnmf.mat');
save(cachePath, 'unitTb', 'clustTb');


%% Plot cluster means

f = MPlot.Figure(225); clf
SL.UnitFig.PlotClusterMean(clustTb);
MPlot.Paperize(f, 'ColumnsWide', 0.5, 'AspectRatio', 2.5);
MPlot.SavePDF(f, fullfile(figDir, "nnmf cluster mean"));


%% Plot Heatmaps

% areaNames = clustTb.areaName(1,:);
areaNames = {'S1TJ', 'M1TJ', 'ALM', 'S1BF'};

for i = 1 : numel(areaNames)
    isArea = strcmp(areaNames{i}, unitTb.areaName);
    unitSubTb = sortrows(unitTb(isArea,:), {'clustId', 'clustScore'});
%     rng(61);
%     isSampled = sort(randsample(height(unitSubTb), 100));
%     unitSubTb = unitSubTb(isSampled,:);
    
    f = MPlot.Figure(10+i); clf
    SL.UnitFig.PlotHeatmap(unitSubTb, 1:nComp);
    MPlot.Paperize(f, 'ColumnsWide', 1, 'ColumnsHigh', .5);
    MPlot.SavePDF(f, fullfile(figDir, "PETH heatmap " + areaNames{i}));
end


return

%% Plot clustering stats

f = MPlot.Figure(224); clf

numPerNotch = 25;
MPlot.Violin(1:nComp, clustTb.clustScore', clustTb.clustScoreN'/numPerNotch, ...
    'Alignment', 'center');
text((1:nComp)', repmat(0.23, [nComp 1]), num2str(clustTb.numUnits), ...
    'Horizontal', 'center');

ax = MPlot.Axes(gca);
ax.XLim = [0 nComp+1];
ax.YLim = [0 .25];
ax.XTick = 1 : nComp;
xlabel("Cluster ID, " + numPerNotch + " units/notch");
ylabel('Coefficient');

MPlot.Paperize(f, 'ColumnsWide', .75, 'ColumnsHigh', .33);
% saveFigurePDF(f, fullfile(figDir, "nnmf cluster stats"));

