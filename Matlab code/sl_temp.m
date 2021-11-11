%% 

load('C:\Users\yaxig\Dropbox (oconnorlab)\Documents\RnD\OConnor Lab\Project Seqlick\Analysis\Data opto VGAT-CRE Ai32 2s 5V\old se\MX180803 2018-08-06 se enriched.mat')
seOld = se;

load('C:\Users\yaxig\Dropbox (oconnorlab)\Documents\RnD\OConnor Lab\Project Seqlick\Analysis\Data opto VGAT-CRE Ai32 2s 5V\MX180803 2018-08-06 se enriched.mat')
seNew = se;

%% 

i = 1;

hsv = seOld.GetTable('hsv');
ang1 = hsv.tongue_bottom_angle{i};

hsv = seNew.GetTable('hsv');
ang2 = hsv.tongue_bottom_angle{i};

t = hsv.time{i};

figure(3); clf
plot(t, ang1, 'b'); hold on
plot(t, ang2, 'r');


%% 

i = 1;

bt = seOld.GetTable('behavTime');
L1 = bt.lickObj{i};

bt = seNew.GetTable('behavTime');
L2 = bt.lickObj{i};

figure(3); clf
for n = 1 : numel(L1)
    plot(L1(n).T.tHSV, L1(n).angle, 'b'); hold on
    plot(L2(n).T.tHSV, L2(n).angle, 'r');
end


%% 

basePath = 'C:\Users\yaxig\Dropbox (oconnorlab)\Documents\RnD\OConnor Lab\Project Seqlick\Analysis\Figures Xu et al\Fig3';
oldFiles = MBrowse.Dir2Table(fullfile(basePath, '5V old', 'aaTb *'));
newFiles = MBrowse.Dir2Table(fullfile(basePath, '5V new', 'aaTb *'));

k = 1;
load(fullfile(oldFiles.folder{k}, oldFiles.name{k}));
aaTbOld = aaTb;
load(fullfile(newFiles.folder{k}, newFiles.name{k}));
aaTbNew = aaTb;


%% 

i = 2;
tb1 = aaTbOld.(i){1};
tb2 = aaTbNew.(i){1};

n1 = cell2mat(tb1{:,7:10});
n2 = cell2mat(tb2{:,7:10});
all(n1==n2)


%% 

L1 = cat(1, tb1.lickObj{:});
L2 = cat(1, tb2.lickObj{:});

L1 = cat(1, L1{:});
L2 = cat(1, L2{:});

L1 = L1(L1.IsTracked);
L2 = L2(L2.IsTracked);

A1 = L1.ShootingAngle;
A2 = L2.ShootingAngle;
all(A1==A2)


%% 

figure(1); clf
histogram(A1, -90:2:90)
hold on
histogram(A2, -90:2:90)


%% 

figure(2); clf

for i = 1 : 20
    l1 = L1(i);
    l2 = L2(i);
    plot(l1.T.tHSV, l1.angle, 'b')
    hold on
    plot(l2.T.tHSV, l2.angle, 'r')
end


%% 

% seArray = SL.SE.LoadSession();

clear stats
for i = 1 : numel(seArray)
    L = seArray(i).GetColumn('behavTime', 'lickObj');
    stats(i) = SL.Behav.GetKinematicStats(L);
end

stats = struct2table(stats);
stats.ang0 = stats.ang0 - stats.ang3;
stats.ang6 = stats.ang6 - stats.ang3;
stats.angPrct = stats.angPrct - stats.ang3;

%% 

figure(1); clf
histogram(stats.ang0, -60:2:60); hold on
histogram(stats.angPrct(:,2), -60:2:60);
histogram(stats.ang6, -60:2:60); hold on
histogram(stats.angPrct(:,1), -60:2:60);

%%

figure(2); clf
plot([stats.ang0 stats.angPrct(:,2)]', 'b'); hold on
plot([stats.ang6 stats.angPrct(:,1)]', 'r')


%% 

sePath = fullfile(SL.Data.analysisRoot, 'Data ephys ALM', 'MX170903 2018-03-04 se enriched.mat');
load(sePath);

% Set up options
ops = SL.Param.Transform;
ops.isMorph = true;
ops.tReslice = -2;
ops.maxReactionTime = 1;
ops.maxEndTime = 8;
SL.SE.Transform(se, ops);


%% 

alignTypes = {'init', 'mid', 'cons', 'term', 'seq'};
alignTypes = {'init', 'mid', 'term'};
alignTypes = {'init'};
seTbs = cell(size(alignTypes));

for k = 1 : numel(alignTypes)
    % Set up options
    ops = SL.Param.Transform;
    ops.isSpkRate = false;
    ops.alignType = alignTypes{k};
    ops.isMatch = true;
    ops.algorithm = @SL.Match.Algorithm4;
    ops = SL.Param.FillMatchOptions(ops);
    
    % Compute seTb
    seTb = SL.SE.Transform(se.Duplicate, ops);
    seTbs{k} = seTb;
end


%% 

MPlot.PlotTraceLadder(seTb.se(1).userData.matchInfo.q')


%% Plot matching

for k = 1 : numel(seTbs)
    seTb = seTbs{k};
    f = MPlot.Figure(1); clf
    f.WindowState = 'maximized';
    SL.Match.PlotOverlays(seTb.se)
    print(f, [seTb.sessionId{1} ' ' alignTypes{k} ' alg4'], '-dpng', '-r0');
end


%% 

sessionId = SL.SE.GetID(seTb.se(1));
nUnits = width(seTb.se(1).GetTable('spikeTime'));

% Select standard and backtracking sequenes wo opto
isSelect = ismember(seTb.seqId, [SL.Param.stdSeqs SL.Param.backSeqs]) & seTb.opto == -1;
seTb = seTb(isSelect,:);

% Split seTb by sequence directions
seqIdNum = double(seTb.seqId);
isRL = mod(seqIdNum,2) == 1; % RL if seqIdNum is odd
seTbCell = {seTb(isRL,:); seTb(~isRL,:)};

% Plotting
unitsPerFig = 8;
nSet = 2; % two halves
nRow = 1 + unitsPerFig / nSet;
nCol = 2 * nSet;
nFigs = ceil(nUnits / unitsPerFig);

for i = 1 %: nFigs
    f = MPlot.Figure(2); clf
    f.WindowState = 'maximized';
    unitInd = (i-1)*unitsPerFig+1 : min(i*unitsPerFig, nUnits);
    
    % Lick angle
    SL.UnitFig.PlotAngleForReview([seTbCell; seTbCell], 'GridSize', [nRow nCol]);
    
    % Unit responses
    SL.UnitFig.PlotRasterPETHs(seTbCell, unitInd, 'GridSize', [nRow nCol], 'StartPos', [2 1]);
end

%% 

dataSource = SL.Data.Dir2Table(fullfile(SL.Data.analysisRoot, '**', '* dt_0', 'seTb *.mat'));

SL.Match.ReviewMatching(dataSource.path);


%% Rename stuff

datDir = SL.Param.GetAnalysisRoot;
searchTb = MBrowse.Dir2Table(fullfile(datDir, '**', 'mdls*.mat'));
for i = 1 : height(searchTb)
    movefile( ...
        fullfile(searchTb.folder{i}, searchTb.name{i}), ...
        fullfile(searchTb.folder{i}, strrep(searchTb.name{i}, 'mdls', 'lm')) ...
        );
end

