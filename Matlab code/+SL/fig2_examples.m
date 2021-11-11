%% Example trials

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig2');


%% Load data
% 2019/1/3: use MX180803 2018-11-28, trial 16
% 2019/6/8: use MX180804 2018-11-28, trial 23 44

% SE
seSearch = MBrowse.Dir2Table(fullfile(datDir, '**\MX180804 2018-11-28 se enriched.mat'));
sePath = fullfile(seSearch.folder{1}, seSearch.name{1}); % sePath = MBrowse.File();
se = SL.SE.LoadSession(sePath);
load('sl mp full.mat');

% Extract data
[bt, bv, hsv, adc] = se.GetTable('behavTime', 'behavValue', 'hsv', 'adc');


%% Example trials

% Specify the example trial
trialNums = [260 23]; % previously [23 44]

f = MPlot.Figure(12001); clf
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

