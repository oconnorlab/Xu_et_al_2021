%% Example trials

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'FigZ');

% Load data
seSearch = MBrowse.Dir2Table(fullfile(datDir, '**\MX200101 2020-11-26 se enriched.mat'));
sePath = fullfile(seSearch.folder{1}, seSearch.name{1});
se = SL.SE.LoadSession(sePath);
load('sl mp full.mat');

% Extract data
[bt, bv, hsv, adc] = se.GetTable('behavTime', 'behavValue', 'hsv', 'adc');


%% Example trials

% Specify the example trial
trialNums = [70 219]; % also see RL 49; LR 148

f = MPlot.Figure(12002); clf
nRows = numel(trialNums);
for k = 1 : numel(trialNums)
    ax = subplot(nRows,1,k); cla
    trialIdx = find(se.epochInd == trialNums(k), 1);
    SL.BehavFig.TrialAngle(trialIdx, hsv);
    SL.BehavFig.TrialTouch(trialIdx, bt);
    ax.XLim = [0 2.5];
end

MPlot.Paperize(f, 'ColumnsWide', 1, 'AspectRatio', .33);
saveFigurePDF(f, fullfile(figDir, 'example trial angles'));

