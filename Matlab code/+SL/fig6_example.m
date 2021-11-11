%% Persistent Activity in ITI

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig6');


%% Load SEs

seSearch = MBrowse.Dir2Table(fullfile(datDir, '**/MX170903 2018-03-04 se enriched.mat'));
seRaw = SL.SE.LoadSession(fullfile(seSearch.folder, seSearch.name));

mdlsSearch = MBrowse.Dir2Table(fullfile(datDir, '**/iti dt_0/lm MX170903 2018-03-04.mat'));
load(fullfile(mdlsSearch.folder{1}, mdlsSearch.name{1}));

%{
% Optionally sort trials for browsing with MPlotter
se = seRaw.Duplicate();
behavET = se.GetTable('behavTime');
behavV = se.GetTable('behavValue');
[~, ind] = sortrows(table(behavV.seqId, behavET.water));
se.SortEpochs(ind);
%}


%% Transform se

% Use default parameters
ops = SL.Param.Transform;
ops

% Work on a copy of SE
se = seRaw.Duplicate;

% Add spike rates
SL.Unit.AddSpikeRateTable(se, ops);

% Exclude the 1st and last trial
SL.Behav.ExcludeTrials(se, ops);

% Linearize session
bv = se.GetTable('behavValue');
tRef = se.GetReferenceTime();
se.SliceSession(0, 'absolute');


%% Compute Example Data

%{
% Select Example Neurons
MPlot.Figure(609); clf

ax = subplot(2,1,1);
isSeqId = strcmp(mdls.reg.subNames, 'seqId');
stem(mdls.reg.B(:,isSeqId));
MPlot.Axes(ax);
ax.XTick = 1 : 5 : size(mdls.reg.B,1);
ax.Title.String = 'Weight of Units for Coding seqId';
grid minor

ax = subplot(2,1,2);
stem(mdls.input.k);
MPlot.Axes(ax);
ax.XTick = 1 : 5 : size(mdls.reg.B,1);
ax.Title.String = 'Standard Deviation of Spike Rate during Sequences';
ax.YLabel.String = 'spike/sec';
grid minor
%}

unitInd = [32 37]; % R 32 15; L 42 37
tCue = tRef(217+(1:15));
tWin = tCue([1 end])';
kerSize = 0.25;

% Port position
bt = se.GetTable('behavTime');
posTime = bt.posIndex{1};
posTime = [posTime posTime([2:end end])]';
posTime = posTime(:);
posVal = cell2mat(bv.posIndex);
posVal = posVal(:,[1 1])';
posVal = posVal(:);

% Lick
lickTime = bt.lickOn{1};
lickPos = interp1(posTime(1:2:end), posVal(1:2:end), lickTime);
lickPos(lickPos > 5) = 6;
lickPos(lickPos < 1) = 0;

% Spike times
st = se.SliceEventTimes('spikeTime', tWin);
st = table2array(st);
st = st(unitInd);

% Spike rate and decoding
sr = se.GetTable('spikeRate');
srTime = sr.time{1};
srMat = cell2mat(sr{1,2:end});
isSeqId = strcmp(mdls.reg.subNames, 'seqId');
proj = (srMat-mdls.input.mu)./mdls.input.k * mdls.reg.B(:,isSeqId) + mdls.reg.C(isSeqId);

egR = MNeuro.Filter1(srMat(:,unitInd), 1/ops.spkBinSize, 'gaussian', kerSize);
proj = MNeuro.Filter1(proj, 1/ops.spkBinSize, 'gaussian', kerSize);

ds = 20;
srTime = downsample(srTime, ds, ds/2);
egR = downsample(egR, ds, ds/2);
proj = downsample(proj, ds, ds/2);

isWin = srTime >= tWin(1) & srTime < tWin(2);
srTime = srTime(isWin);
egR = egR(isWin,:);
proj = proj(isWin);
egR = egR./max(egR);

% Body movement
se.SetColumn('adc', 'tubeVFilt', se.GetColumn('adc', 'tubeV'));
% se.SetColumn('adc', 'tubeVFilt', @(x) SL.Perch.FiltMovement(x, 1e3), 'each');
adc = se.SliceTimeSeries('adc', tWin, [], {'tubeVFilt'});
adcTime = adc.time{1};
tubeV = adc.tubeVFilt{1};
tubeV = normalize(tubeV, 'range') * .8;

ds = 20;
adcTime = downsample(adcTime, ds, ds/2);
tubeV = downsample(tubeV, ds, ds/2);


%% Plotting

f = MPlot.Figure(601); clf
nRows = 5;
i = 0;

i = i + 1;
ax = subplot(nRows, 1, i);
plot(posTime, posVal, '-', 'Color', 'k'); hold on
plot(lickTime, lickPos, '.', 'Color', 'k');
SL.ITI.FormatExampleAxes(tWin, tCue);

i = i + 1;
ax = subplot(nRows, 1, i);
plot(adcTime, tubeV, 'k'); hold on
SL.ITI.FormatExampleAxes(tWin, tCue);

i = i + 1;
ax = subplot(nRows, 1, i);
egCC = [0 0 1; 1 0 0];
MPlot.PlotRaster(st, (1:numel(unitInd))/3-1, 0.2, 'ColorArray', egCC);
SL.ITI.FormatExampleAxes(tWin, tCue);

i = i + 1;
ax = subplot(nRows, 1, i);
areaParams = {'FaceAlpha', .5, 'LineStyle', 'none', 'ShowBaseline', false};
area(srTime, egR(:,1), 'FaceColor', egCC(1,:), areaParams{:}); hold on
area(srTime, egR(:,2), 'FaceColor', egCC(2,:), areaParams{:});
SL.ITI.FormatExampleAxes(tWin, tCue);

i = i + 1;
ax = subplot(nRows, 1, i);
plot(posTime, posVal/max(posVal)+1, '-', 'Color', [0 0 0 .15]); hold on
plot(srTime, proj, 'k-');
SL.ITI.FormatExampleAxes(tWin, tCue);

ax.XAxis.Visible = 'on';
MPlot.Paperize(f, 'ColumnsWide', 1, 'AspectRatio', .66);
saveFigurePDF(f, fullfile(figDir, "example trials"));

