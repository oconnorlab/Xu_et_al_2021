%% Summary Statistics of Decoding

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig5');


%% Load and unpack data

searchResult = [ ...
    MBrowse.Dir2Table(fullfile(datDir, 'Data ephys ALM\seq dt_*\lm *.mat')); ...
    MBrowse.Dir2Table(fullfile(datDir, 'Data ephys M1TJ\seq dt_*\lm *.mat')); ...
    MBrowse.Dir2Table(fullfile(datDir, 'Data ephys S1TJ\seq dt_*\lm *.mat')); ...
    ];
mdlsPaths = cellfun(@fullfile, searchResult.folder, searchResult.name, 'Uni', false);
M = SL.Pop.UnpackLinearModels(mdlsPaths);


%% Plot R-squared by spike time lags

f = MPlot.Figure(531); clf
SL.PopFig.PlotRSquaredByTimeLags(M.regTb);
MPlot.Paperize(f, 'ColumnsWide', 1.3, 'AspectRatio', .25);
saveFigurePDF(f, fullfile(figDir, "angle R-squared given time lags"));


return
%% Plot Distributions of R-squared

f = MPlot.Figure(521); clf
SL.PopFig.PlotRSquared(M.regAvgTb, M.regTb);
MPlot.Paperize(f, 'ColumnsWide', 1.3, 'AspectRatio', .26);
saveFigurePDF(f, fullfile(figDir, "R-squared"));

