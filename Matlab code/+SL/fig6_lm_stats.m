%% Summary Statistics of Decoding

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig6');


%% Load and unpack data

itiSearch = MBrowse.Dir2Table(fullfile(datDir, '**\iti dt_0\lm *.mat'));
itiPaths = cellfun(@fullfile, itiSearch.folder, itiSearch.name, 'Uni', false);

% seqSearch = MBrowse.Dir2Table(fullfile(datDir, '**\seq dt_0\lm *.mat'));
% seqPaths = cellfun(@fullfile, seqSearch.folder, seqSearch.name, 'Uni', false);

areaList = {'ALM', 'M1TJ', 'S1TJ', 'S1BF'};
sIti = SL.Pop.UnpackLinearModels(itiPaths, areaList);
% sSeq = SL.Pop.UnpackLinearModels(seqPaths);


%% Plot Distributions of R-squared

f = MPlot.Figure(631); clf
SL.PopFig.PlotRSquared(sIti.regAvgTb, sIti.regTb);
MPlot.Paperize(f, 'ColumnsWide', 0.5, 'AspectRatio', .75);
saveFigurePDF(f, fullfile(figDir, "R-squared iti-iti"));


%% Variance Explained

f = MPlot.Figure(638); clf
SL.PopFig.CompareVarExplained(sIti.regAvgTb, sIti.pcaTb, sIti.regTb);
MPlot.Paperize(f, 'ColumnsWide', .5, 'AspectRatio', .5);
saveFigurePDF(f, fullfile(figDir, "variance explained"));


return
%% Correlation and Cosine

regIti = sIti.regTb(sIti.areaTb.groupInd{1},:);
regSeq = sSeq.regTb(sSeq.areaTb.groupInd{1},:);

isInclude = regIti.r2cv(:,1) > 0.3;
regIti = regIti(isInclude,:);
regSeq = regSeq(isInclude,:);

itiSubIdx = 1; % direction
seqSubInd = [3 4]; % angle, direction
BC = cellfun(@(x,y) MMath.VecCosine(x(:,itiSubIdx), y(:,seqSubInd)), regIti.B, regSeq.B, 'Uni', false);
BC = cat(1, BC{:});
BC = abs(BC);
xx = cumsum(ones(size(BC)), 2);
r2 = regIti.r2cv(:,itiSubIdx);
nUnit = cellfun(@(x) size(x,1), regIti.B);

% [h, p, ks2stat] = kstest2(BC(:,1), BC(:,2));


MPlot.Figure(633); clf
plot(repmat(nUnit, [1 size(BC,2)]), BC, 'o');

% bar(mean(BC)', 'EdgeColor', [0 0 0]+.7, 'FaceColor', 'none'); hold on
% plot(xx, BC, 'ko')
% ax = MPlot.Axes(gca);
% ax.XLim = [0 size(BC,2)+1];
% ax.XTick = 1 : size(BC,2);
% ax.XTickLabel = regSeq.subNames(1,seqSubInd);
% ylabel('|Cosine|');

