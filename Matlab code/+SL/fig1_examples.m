%% Example trial, frames, and licks from a session

anaDir = SL.Data.analysisRoot;
figDir = fullfile(anaDir, SL.Data.figDirName, 'Fig1');


%% Load data
% SfN 2018: use MX180201 2018-04-08, trial 59
% 2019/1/3: use MX180803 2018-11-28, trial 16
% 2019/6/8: use MX180804 2018-11-28, trial 27, frame 70 800
% 2019/7/4: use MX180203 2018-05-26, trial 51, frame 92 649, trial 62

% SE
seSearch = MBrowse.Dir2Table(fullfile(anaDir, '**\MX180203 2018-05-26 se enriched.mat'));
sePath = fullfile(seSearch.folder{1}, seSearch.name{1}); % sePath = MBrowse.File();
se = SL.SE.LoadSession(sePath);
load('sl mp full.mat');

% Video and cached tracking results
tkPath = fullfile(figDir, 'MX180203_Num51_20180526_164413 tkData.mat');
if exist(tkPath, 'file')
    tkData = load(tkPath);
else
    tkData = SL.HSV.TrackTrial('MX180203_Num51_20180526_164413.avi');
    save(tkPath, '-struct', 'tkData');
end


%% Example trials

% Specify the example trial
trialNum = 51;
trialIdx = find(se.epochInd == trialNum, 1);

% Get data
[bt, bv, hsv, adc] = se.GetTable('behavTime', 'behavValue', 'hsv', 'adc');

% Ploting
f = MPlot.Figure(12123); clf
nRows = 5;
i = 1;

ax = subplot(nRows,1,i); cla
SL.BehavFig.TrialBinary(trialIdx, bt);
SL.BehavFig.TrialTouch(trialIdx, bt);
ax.XLim = [0 2];
i = i + 1;

ax = subplot(nRows,1,i); cla
SL.BehavFig.TrialForce(trialIdx, adc);
SL.BehavFig.TrialTouch(trialIdx, bt);
ax.XLim = [0 2];
i = i + 1;

ax = subplot(nRows,1,i); cla
SL.BehavFig.TrialLength(trialIdx, hsv);
SL.BehavFig.TrialTouch(trialIdx, bt);
ax.XLim = [0 2];
i = i + 1;

ax = subplot(nRows,1,i); cla
SL.BehavFig.TrialVelocity(trialIdx, hsv);
SL.BehavFig.TrialTouch(trialIdx, bt);
ax.XLim = [0 2];
i = i + 1;

ax = subplot(nRows,1,i); cla
SL.BehavFig.TrialAngle(trialIdx, hsv);
SL.BehavFig.TrialTouch(trialIdx, bt);
ax.XLim = [0 2];

MPlot.Paperize(f, 'ColumnsWide', 1, 'AspectRatio', .75);
saveFigurePDF(f, fullfile(figDir, 'example trial quantities'));


%% Lick trajectories

f = MPlot.Figure(12124); clf

subplot(2,1,1);
SL.BehavFig.LickTrajectory(trialIdx, bt);
ax = gca;
ax.XLim = [1.5 8.5];
ax.YLim = [3 6];

subplot(2,1,2);
SL.BehavFig.LickTrajectory(62, bt);
ax = gca;
ax.XLim = [1.5 8.5];
ax.YLim = [3 6];

MPlot.Paperize(f, 'ColumnsWide', .5, 'ColumnsHigh', .33);
saveFigurePDF(f, fullfile(figDir, 'tip trajectories'));


%% Plot example frames

%{
% Browse for example frames
figure(13123); clf
MImgBaseClass.Viewer(tkData(1).img, ...
    'UserFunc', {@SL.HSV.ViewerUserFunc2, tkData(1).C_score(:,2), tkData(1).Y/320*224, tkData(1).S});
%}

frInd = [92 649];

f = MPlot.Figure(13125); clf
f.Position(3:4) = [300 300];

for i = 1 : numel(frInd)
    subplot(2,2,i); cla
    imagesc(tkData.img(:,:,:,frInd(i))); hold on
    axis equal tight off
    colormap gray
end
plot([10 10], [10 3/SL.Param.mmPerPx], 'w', 'LineWidth', 2);
text(15, 30, "3mm", 'Color', 'w');

for i = 1 : numel(frInd)
    subplot(2,2,2+i); cla
    imagesc(tkData.img(:,:,:,frInd(i))); hold on
    SL.HSV.FrameLabels(1, frInd(i), tkData.C_score(:,2), tkData.Y/320*224, tkData.S);
    axis equal tight off
    colormap gray
end

MPlot.Paperize(f, 'ColumnsWide', .5, 'AspectRatio', 1);
saveFigurePDF(f, fullfile(figDir, 'example frames'));

