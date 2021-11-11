%% Mean quantities in 

datDir = SL.Data.analysisRoot;
if ~exist('powerName', 'var')
    powerName = "5V";
end
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig3', powerName);


%% Load results

load(fullfile(figDir, 'computed quant stats.mat'));
sQuant = aResults;

load(fullfile(figDir, 'computed rate stats 1s.mat'));
sRate1 = aResults;

load(fullfile(figDir, 'computed rate stats 2s.mat'));
sRate2 = aResults;


%% Prepare data for plotting

plotData = cell(5,1);

ops = struct;
ops.aCI = 0.05;
ops.nCompare = 15;
period = 'combined';
plotData{1} = SL.OptoFig.PrepareBrainOverlayData(sQuant, 'angSD', period, ops);
plotData{2} = SL.OptoFig.PrepareBrainOverlayData(sQuant, 'angAbs', period, ops);
plotData{3} = SL.OptoFig.PrepareBrainOverlayData(sQuant, 'len', period, ops);

ops.nCompare = 30;
plotData{4} = SL.OptoFig.PrepareBrainOverlayData(sRate1, 'rLick', 'init', ops);
plotData{5} = SL.OptoFig.PrepareBrainOverlayData(sRate2, 'rLick', 'cons', ops);


%% Plot brain overlay

f = MPlot.Figure(125456); clf

for i = 1 : numel(plotData)
    ax = subplot(2,3,i);
    SL.OptoFig.PlotBrainOverlay(plotData{i});
end

MPlot.Paperize(f, 'ColumnsWide', 1, 'ColumnsHigh', 1);
saveFigurePDF(f, fullfile(figDir, "brain overlay"));

