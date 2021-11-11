%% Summary Statistics of Decoding

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig5');


%% Load and unpack data

seqSearch = MBrowse.Dir2Table(fullfile(datDir, '**\seq dt_0\lm *.mat'));
seqPaths = cellfun(@fullfile, seqSearch.folder, seqSearch.name, 'Uni', false);
sSeq = SL.Pop.UnpackLinearModels(seqPaths);

regAvgTb = sSeq.regAvgTb;
inputTb = sSeq.inputTb;
regTb = sSeq.regTb;
pcaTb = sSeq.pcaTb;


%% Plot Distributions of R-squared

f = MPlot.Figure(521); clf
SL.PopFig.PlotRSquared(regAvgTb, regTb);
MPlot.Paperize(f, 'ColumnsWide', 1.3, 'AspectRatio', .26);
saveFigurePDF(f, fullfile(figDir, "R-squared"));


%% Variance Explained

f = MPlot.Figure(522); clf

% subplot(3,1,1)
SL.PopFig.CompareVarExplained(regAvgTb, pcaTb, regTb);

% subplot(3,1,2)
% SL.PopFig.CompareVarExplained(areaTb, pcaTb, regTb, 1:3);
% 
% subplot(3,1,3)
% SL.PopFig.CompareVarExplained(areaTb, pcaTb, regTb, 3:5);

MPlot.Paperize(f, 'ColumnsWide', .5, 'AspectRatio', 0.5);
saveFigurePDF(f, fullfile(figDir, "variance explained"));


%% Correlation and Cosine

varNames = regTb.subNames(1,:);

S = cellfun(@(x) x(:,regTb.sInd(1,:)), inputTb.S, 'Uni', false);
SC = cellfun(@(x) corr(x, 'Rows', 'pairwise', 'Type', 'Spearman'), S, 'Uni', false);
SC = cat(3, SC{:});
SC = mean(SC,3);

BC = cellfun(@MMath.VecCosine, regTb.B, 'Uni', false);
BC = cat(3, BC{:});
BC(BC==0) = NaN;
BC = nanmean(BC,3);


f = MPlot.Figure(523); clf

subplot(1,2,1);
h = SL.PopFig.PlotCosine(SC, varNames);
h.Title = 'Pairwise |r| among stimuli';

subplot(1,2,2);
SL.PopFig.PlotCosine(BC, varNames);

MPlot.Paperize(f, 'ColumnsWide', 1, 'AspectRatio', .36);
saveFigurePDF(f, fullfile(figDir, "corr and cos"));

