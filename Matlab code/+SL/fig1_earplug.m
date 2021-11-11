%% Hearing loss experiment

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig1');


%% Load data

dataSource = SL.Data.FindSessions('fig1_earplug');
seArray = SL.SE.LoadSession(dataSource.path);


%% Compute stats

seTbs = cell(size(seArray));

ops = SL.Param.Transform;
ops.isSpkRate = false;
ops.conditionVars = {}; 
% ops.conditionVars = {'earplugType'};
rng(61);

for i = 1 : numel(seArray)
    se = seArray(i).Duplicate();
    isBk = ismember(se.GetColumn('behavValue', 'seqId'), {'1231456', '5435210'});
    se.RemoveEpochs(isBk);
    
    % Transform session
    ops.maxEndTime = Inf;
    seTb = SL.SE.Transform(se, ops);
    
    % Label experiment condition
    seTb.isPlug = mod(i,2) == 1;
    
    % Compute stats
    seTb.tFT = SL.Behav.ControlStats(seTb.se, 'pre_seq_time');
    seTb.mFT = SL.Behav.ControlStats(seTb.se, 'pre_seq_miss');
    seTb.mSQ = SL.Behav.ControlStats(seTb.se, 'seq_miss');
    
    seTbs{i} = seTb;
end
seTb = cat(1, seTbs{:});

% Sort rows in the order of animalId and control->numbing
seTb = sortrows(seTb, {'animalId', 'isPlug'});

% Split rows in seTb by animals
aTb = table;
aTb.animalId = unique(seTb.animalId);
aTb = SL.SE.CombineConditions(aTb, seTb); % t and nMiss must be row vectors to prevent concatenation


%% Plot stats for individual mice

f = MPlot.Figure(1281); clf
SL.BehavFig.ControlStatsByMice(aTb);
MPlot.Paperize(f, 'ColumnsWide', .4, 'ColumnsHigh', 1);
saveFigurePDF(f, fullfile(figDir, "hearing loss by mice"));

%{
tFT MX190602: 1.7e-46
tFT VC010102: 2e-17
tFT VC010103: 2e-25
tFT WO010401: 1.1e-41
tFT WO010402: 3e-20
mFT MX190602: 0.0013
mFT VC010102: 1
mFT VC010103: 3.1e-05
mFT WO010401: 8.4e-15
mFT WO010402: 0.00058
mSQ MX190602: 0.4
mSQ VC010102: 0.85
mSQ VC010103: 0.71
mSQ WO010401: 0.00021
%}


%% Plot stats of grouped results

f = MPlot.Figure(1280); clf
SL.BehavFig.ControlStatsGrouped(aTb);
MPlot.Paperize(f, 'ColumnsWide', .4, 'ColumnsHigh', 1);
MPlot.SavePDF(f, fullfile(figDir, "hearing loss"));


return
%% Summary

f = MPlot.Figure(1479); clf
nSess = numel(seArray);
cc = zeros(nSess/2, 3); % color

ax = subplot(3,1,1);
for i = 1:2:nSess
    s1 = seTbs{i+1}.tFT; % control session
    s2 = seTbs{i}.tFT; % earplug session
    mm = [s1.median s2.median];
    ee = [s1.qt' s2.qt'] - mm;
    [~, p] = kstest2(s1.sample, s2.sample, 'Tail', 'larger');
    
    errorbar([0.5*i+0.25 0.5*i+0.75], mm, ee(1,:), ee(2,:), 'o-', 'Color', cc((i+1)/2,:), 'MarkerSize', 4); hold on
    if p < 0.05/(nSess/2)
        plot((i+1)/2, 10, '*', 'Color', cc((i+1)/2,:));
    end
    fprintf('tFD %s: %.2g\n', seTbs{i}.animalId{1}, p);
end
ax.YScale = 'log';
ax.YGrid = 'on';
ax.XTick = 1:(nSess/2);
xlim([0 nSess/2+1]);
ylim([0.1 10]);
xlabel('Animal');
ylabel('Second');
title('Time to first touch');
MPlot.Axes(ax);

ax = subplot(3,1,2);
for i = 1:2:nSess
    s1 = seTbs{i+1}.mFT; % control session
    s2 = seTbs{i}.mFT; % earplug session
    mm = [s1.mean s2.mean];
    ee = [s1.ci' s2.ci'] - mm;
    [~, p] = kstest2(s1.sample, s2.sample);
    
    errorbar([0.5*i+0.25 0.5*i+0.75], mm, ee(1,:), ee(2,:), 'o-', 'Color', cc((i+1)/2,:), 'MarkerSize', 4); hold on
    if p < 0.05/(nSess/2)
        plot((i+1)/2, 6, '*', 'Color', cc((i+1)/2,:));
    end
    fprintf('mFT %s: %.2g\n', seTbs{i}.animalId{1}, p);
end
ax.YGrid = 'on';
ax.XTick = 1:(nSess/2);
xlim([0 nSess/2+1]);
ylim([0 6]);
xlabel('Animal');
ylabel('# of missed licks');
title('Miss before first touch');
MPlot.Axes(ax);

ax = subplot(3,1,3);
for i = 1:2:nSess
    s1 = seTbs{i+1}.mSQ; % control session
    s2 = seTbs{i}.mSQ; % earplug session
    mm = [s1.mean s2.mean];
    ee = [s1.ci' s2.ci'] - mm;
    [~, p] = kstest2(s1.sample, s2.sample);
    
    errorbar([0.5*i+0.25 0.5*i+0.75], mm, ee(1,:), ee(2,:), 'o-', 'Color', cc((i+1)/2,:), 'MarkerSize', 4); hold on
    if p < 0.05/(nSess/2)
        plot((i+1)/2, 15, '*', 'Color', cc((i+1)/2,:));
    end
    fprintf('mSQ %s: %.2g\n', seTbs{i}.animalId{1}, p);
end
ax.YGrid = 'on';
ax.XTick = 1:(nSess/2);
xlim([0 nSess/2+1]);
ylim([0 15]);
xlabel('Animal');
ylabel('# of missed licks');
title('Miss during sequence');
MPlot.Axes(ax);

MPlot.Paperize(f, 'ColumnsWide', .4, 'ColumnsHigh', 1);
saveFigurePDF(f, fullfile(figDir, "hearing loss"));


%% Plot CDF

% f = MPlot.Figure(1479); clf
f = figure;
cc = lines(nSess/2);

for i = 1:2:nSess
    ax = subplot(nSess/2, 2, i);
    
    s1 = seTbs{i}.FT; % earplug session
    s2 = seTbs{i+1}.FT; % control session
    stairs(s1.tEdges(1:end-1)*1e3, s1.N, 'Color', cc((i+1)/2,:)); hold on
    stairs(s2.tEdges(1:end-1)*1e3, s2.N, '--', 'Color', cc((i+1)/2,:));
    
    MPlot.Axes(ax);
    ax.XScale = 'log';
    ax.XTick = 10.^(0:3) * 100; % should be ax.XTick = 10.^(0:2) * 100?
    ax.Box = 'off';
    grid on
    xlim([1e2 1e4]);
    ylim([0 1]);
    xlabel('ms');
    ylabel('Fraction');
    title('First touch time');
end

for i = 1:2:nSess
    ax = subplot(nSess/2,2,i+1);
    
    s1 = seTbs{i}.SP; % earplug session
    s2 = seTbs{i+1}.SP; % control session
    stairs(s1.tEdges(1:end-1), s1.N, 'Color', cc((i+1)/2,:)); hold on
    stairs(s2.tEdges(1:end-1), s2.N, '--', 'Color', cc((i+1)/2,:));
    
    MPlot.Axes(ax);
    ax.Box = 'off';
    grid on
    xlim([0 9]);
    ylim([0 1]);
    xlabel('Positions/s');
    ylabel('Fraction');
    title('Sequence speed');
end

