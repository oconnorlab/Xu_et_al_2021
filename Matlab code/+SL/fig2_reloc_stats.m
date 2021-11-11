%% Quantify backtracking performance

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig2');


%% Load lickObjs

% Load data cached from fig1_perf_stats.m
load(fullfile(datDir, SL.Data.figDirName, 'Fig1', 'extracted lick data.mat'));

% Exclude flawed sessions
isBadTouch = ismember(seTbCat.sessionId, SL.Data.excludeFromTouch);

% Exclude sessions without backtracking
[G, sessionId] = findgroups(seTbCat.sessionId);
isBackG = splitapply(@(x) any(ismember(x, {'1231456', '5435210'})), seTbCat.seqId, G);
isBack = ismember(seTbCat.sessionId, sessionId(isBackG));

seTbCat(isBadTouch | ~isBack,:) = [];


%% Group data by animal

% Find normal sequences
isSeq = ismember(seTbCat.seqId, {'123456', '543210'});
[G, animalTb] = findgroups(seTbCat(isSeq, 'animalId'));
lickObjNN = splitapply(@(x) {cat(1,x{:})}, seTbCat.lickObj(isSeq), G);

% Find backtracking sequences
isSeq = ismember(seTbCat.seqId, {'1231456', '5435210'});
G = findgroups(seTbCat(isSeq, 'animalId'));
lickObjBB = splitapply(@(x) {cat(1,x{:})}, seTbCat.lickObj(isSeq), G);


%% Reconstruct partial behavTime tables

btNN = cell(size(lickObjNN));
btBB = cell(size(lickObjBB));

for i = 1 : numel(btNN)
    tb = table();
    lickObj = lickObjNN{i};
    tb.isValid = true(size(lickObj));
    for j = 1 : height(tb)
        licks = lickObj{j};
        tDrive = double(licks([licks.isDrive]'));
        if numel(tDrive) ~= 6
            fprintf('%d positions found in a normal seq at i%d j%d\n', numel(tDrive), i, j);
            tb.isValid(j) = false;
            continue
        end
        tb.posIndex{j} = tDrive;
        tb.waterTrig(j) = double(licks([licks.isReward]'));
        tb.airOn{j} = licks.GetTfield('tOut');
    end
    btNN{i} = tb(tb.isValid,:);
    
    tb = table();
    lickObj = lickObjBB{i};
    tb.isValid = true(size(lickObj));
    for j = 1 : height(tb)
        licks = lickObj{j};
        tDrive = double(licks([licks.isDrive]'));
        if numel(tDrive) ~= 7
            fprintf('%d positions found in a backtracking seq at i%d j%d\n', numel(tDrive), i, j);
            tb.isValid(j) = false;
            continue
        end
        tb.posIndex{j} = tDrive;
        tb.waterTrig(j) = double(licks([licks.isReward]'));
        tb.airOn{j} = licks.GetTfield('tOut');
    end
    btBB{i} = tb(tb.isValid,:);
end


%% 

itvl = 4:5;

sDur(1) = SL.Behav.SeqDurStat(btBB, itvl);
sDur(2) = SL.Behav.SeqDurStat(btNN, itvl);

sMiss(1) = SL.Behav.SeqMissStat(btBB, itvl);
sMiss(2) = SL.Behav.SeqMissStat(btNN, itvl);


%% Plot

f = MPlot.Figure(9723); clf

cc = [SL.Param.backColor; 0 0 0];

ax = subplot(2,1,1);
for i = 1 : 2
    s = sDur(i);
    errorbar(s.x, s.mean, (s.mean-s.ci(:,1)), s.ci(:,2)-s.mean, 'o', 'Color', cc(i,:));
%     errorbar(s.x, s.median, s.median-s.prct25, s.prct75-s.median, 'x', 'Color', cc(i,:));
    hold on
end
ax.XTick = s.x;
ax.XTickLabel = [];
ax.YTick = [0 0.35 0.7];
MPlot.Axes(ax);
xlim([0 length(s.x)+1]);
ylim([0 .7]);
xlabel('Animal');
ylabel('Second');
title('Time to locate');


ax = subplot(2,1,2);
for i = 1 : 2
    s = sMiss(i);
    errorbar(s.x, s.mean, (s.mean-s.ci(:,1)), s.ci(:,2)-s.mean, 'o', 'Color', cc(i,:));
%     errorbar(s.x, s.median, s.median-s.prct25, s.prct75-s.median, 'x', 'Color', cc(i,:));
    hold on
end
ax.XTick = s.x;
ax.XTickLabel = [];
% ax.YTick = [0 0.35 0.7];
MPlot.Axes(ax);
xlim([0 length(s.x)+1]);
ylim([-.3 3]);
xlabel('Animal');
title('# of missed lick');


MPlot.Paperize(f, 'ColumnsWide', .4, 'ColumnsHigh', .6);
saveFigurePDF(f, fullfile(figDir, 'backtracking stats'));

