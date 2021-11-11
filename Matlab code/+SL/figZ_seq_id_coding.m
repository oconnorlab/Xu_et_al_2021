%% Prepare data

rootDir = SL.Data.analysisRoot;
figDir = fullfile(rootDir, SL.Data.figDirName, 'FigZ');

% Load seTb and claTb
sessionID = 'MX210301 2021-05-06';
datDir = fullfile(rootDir, 'Data ephys ZZ', 'seq_zz dt_0');
load(fullfile(datDir, ['seTb ' sessionID '.mat']));
load(fullfile(datDir, ['cla_pca ' sessionID '.mat']));

% Make time-shifted seTbs
seTbSft = SL.ZZ.ShiftSeTb(seTb);

% Load mClaTb
load(fullfile(figDir, 'cla_pca.mat'), 'mClaTb');


%% Plot whole sequence angle match

f = MPlot.Figure(2); clf

SL.ZZ.PlotAngleZoomedOut(seTbSft, 'GridSize', [numel(seTbSft) 1]);

MPlot.Paperize(f, 'ColumnsWide', .5, 'ColumnsHigh', .8);
figPath = fullfile(figDir, ['seq shifts ' seTb.sessionId{1}]);
saveFigurePDF(f, figPath);


%% Plot lick angle, spike raster, PETH for example units

unitInd = [32 12 28];
nUnit = numel(unitInd);
nShift = numel(seTbSft);

nRow = nUnit + 3;
nCol = nShift;

f = MPlot.Figure(1); clf

SL.ZZ.PlotAngleZoomedIn(seTbSft, ...
    'GridSize', [nRow nCol], 'StartPos', [1 1]);

SL.ZZ.PlotRasterPETHs(seTbSft, unitInd, ...
    'GridSize', [nRow nCol], 'StartPos', [2 1]);

SL.ZZ.PlotCla(claTb, 'session', ...
    'GridSize', [nRow nCol], 'StartPos', [nUnit+2 1]);

SL.ZZ.PlotCla(mClaTb, 'mean', ...
    'GridSize', [nRow nCol], 'StartPos', [nUnit+3 1]);

MPlot.Paperize(f, 'ColumnsWide', 1, 'ColumnsHigh', 1.3);
figPath = fullfile(figDir, ['seq id coding w ' seTb.sessionId{1}]);
saveFigurePDF(f, figPath);

