%% Quantifications of final performance

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig1');


%% Load data

dataSource = SL.Data.FindSessions('fig1_air');
seArray = SL.SE.LoadSession(dataSource.path);


%% Compute stats

seTbs = cell(size(seArray));

ops = SL.Param.Transform;
ops.isSpkRate = false;
ops.conditionVars = {'isAir'};
rng(61);

for i = 1 : numel(seArray)
    % Label trials: 0 is no air, 1 is air, 2 is excluded
    se = seArray(i).Duplicate();
    isAir = zeros(se.numEpochs,1);
    switch se.userData.sessionInfo.animalId
        case {'MX190201', 'VC010103', 'WO010401', 'MX190602'}
            % Air off first
            isAir(101:end) = 1;
        case {'VC010102', 'WO010402'}
            % Air on first
            isAir(1:100) = 1;
        otherwise
            error('Unknown animal ID');
    end
%     isAir(201:end) = 2; % exclude
    se.SetColumn('behavValue', 'isAir', isAir);
    
    % Keep NN seq only
    isNN = ismember(se.GetColumn('behavValue', 'seqId'), {'123456', '543210'});
    se.RemoveEpochs(~isNN);
    
    % Transform session
    ops.maxEndTime = Inf;
    seTb = SL.SE.Transform(se, ops);
    
    seTbs{i} = seTb;
end
seTb = cat(1, seTbs{:});

% Sort rows in the order of animalId and control->numbing
seTb = sortrows(seTb, {'animalId', 'isAir'});

% Split rows in seTb by animals
aTb = table;
aTb.animalId = unique(seTb.animalId);
aTb = SL.SE.CombineConditions(aTb, seTb); % t and nMiss must be row vectors to prevent concatenation


%% Compute stats for each animal

for i = 1 : height(aTb)
    aTb.tFT{i} = arrayfun(@(x) SL.Numb.ControlStats(x, 'pre_seq_time'), aTb.se{i});
    aTb.mFT{i} = arrayfun(@(x) SL.Numb.ControlStats(x, 'pre_seq_miss'), aTb.se{i});
    aTb.mSQ{i} = arrayfun(@(x) SL.Numb.ControlStats(x, 'seq_miss'), aTb.se{i});
end


%% Plot stats for individual mice

f = MPlot.Figure(1281); clf
SL.BehavFig.ControlStatsByMice(aTb);
MPlot.Paperize(f, 'ColumnsWide', .4, 'ColumnsHigh', 1);
saveFigurePDF(f, fullfile(figDir, "odor masking by mice"));

%{
tFT MX190201: 0.51
tFT MX190602: 0.15
tFT VC010102: 0.0057
tFT VC010103: 0.85
tFT WO010401: 0.021
tFT WO010402: 0.039
mFT MX190201: 0.48
mFT MX190602: 0.14
mFT VC010102: 0.0085
mFT VC010103: 0.97
mFT WO010401: 0.00016
mFT WO010402: 0.065
mSQ MX190201: 1
mSQ MX190602: 0.86
mSQ VC010102: 2.3e-09
mSQ VC010103: 0.78
mSQ WO010401: 0.69
mSQ WO010402: 0.4
%}


%% Plot stats of grouped results

f = MPlot.Figure(1280); clf
SL.BehavFig.ControlStatsGrouped(aTb);
MPlot.Paperize(f, 'ColumnsWide', .4, 'ColumnsHigh', 1);
saveFigurePDF(f, fullfile(figDir, "odor masking"));


return
%% Summary

f = MPlot.Figure(1480); clf
nMice = numel(seArray);
% cc = lines(nMice);
cc = zeros(nMice, 3);

ax = subplot(3,1,1);
for i = 1 : nMice
    seTb = seTbs{i};
    s1 = seTb.tFT{1};
    s2 = seTb.tFT{2};
    mm = [s1.median s2.median];
    ee = [s1.qt' s2.qt'] - mm;
    [~, p] = kstest2(s1.sample, s2.sample, 'Tail', 'larger');
    
    errorbar(i+[-.25 .25], mm, ee(1,:), ee(2,:), 'o-', 'Color', cc(i,:), 'MarkerSize', 4); hold on
    if p < 0.05/nMice
        plot(i, 10, '*', 'Color', cc(i,:));
    end
    fprintf('tFT %s: %.2g\n', seTb.animalId{1}, p);
end
ax.YScale = 'log';
ax.YGrid = 'on';
ax.XTick = 1:nMice;
xlim([0 nMice+1]);
ylim([0.1 10]);
xlabel('Animal');
ylabel('Second');
title('Time to first touch');
MPlot.Axes(ax);

ax = subplot(3,1,2);
for i = 1 : nMice
    seTb = seTbs{i};
    s1 = seTb.mFT{1};
    s2 = seTb.mFT{2};
    mm = [s1.mean s2.mean];
    ee = [s1.ci' s2.ci'] - mm;
    [~, p] = kstest2(s1.sample, s2.sample, 'Tail', 'larger');
    
    errorbar(i+[-.25 .25], mm, ee(1,:), ee(2,:), 'o-', 'Color', cc(i,:), 'MarkerSize', 4); hold on
    if p < 0.05/nMice
        plot(i, 6, '*', 'Color', cc(i,:));
    end
    fprintf('mFT %s: %.2g\n', seTb.animalId{1}, p);
end
ax.YGrid = 'on';
ax.XTick = 1:nMice;
xlim([0 nMice+1]);
ylim([0 6]);
xlabel('Animal');
ylabel('# of missed licks');
title('Miss before first touch');
MPlot.Axes(ax);

ax = subplot(3,1,3);
for i = 1 : nMice
    seTb = seTbs{i};
    s1 = seTb.mSQ{1};
    s2 = seTb.mSQ{2};
    mm = [s1.mean s2.mean];
    ee = [s1.ci' s2.ci'] - mm;
    [~, p] = kstest2(s1.sample, s2.sample, 'Tail', 'larger');
    
    errorbar(i+[-.25 .25], mm, ee(1,:), ee(2,:), 'o-', 'Color', cc(i,:), 'MarkerSize', 4); hold on
    if p < 0.05/nMice
        plot(i, 15, '*', 'Color', cc(i,:));
    end
    fprintf('mSQ %s: %.2g\n', seTb.animalId{1}, p);
end
ax.YGrid = 'on';
ax.XTick = 1:nMice;
xlim([0 nMice+1]);
ylim([0 15]);
xlabel('Animal');
ylabel('# of missed licks');
title('Miss during sequence');
MPlot.Axes(ax);

MPlot.Paperize(f, 'ColumnsWide', .4, 'ColumnsHigh', 1);
saveFigurePDF(f, fullfile(figDir, "odor masking"));


%% Plot CDF

f = MPlot.Figure(1479); clf

cc = lines(nMice);

for i = 1 : nMice
    ax = subplot(nMice,2,i*2-1);
    
    seTb = seTbs{i};
    s1 = seTb.FT{1};
    s2 = seTb.FT{2};
    stairs(s1.tEdges(1:end-1)*1e3, s1.N, 'Color', cc(i,:)); hold on
    stairs(s2.tEdges(1:end-1)*1e3, s2.N, '--', 'Color', cc(i,:));
    
    MPlot.Axes(ax);
    ax.XScale = 'log';
    ax.XTick = 10.^(0:3) * 100;
    ax.Box = 'off';
    grid on
    xlim([1e2 1e4]);
    ylim([0 1]);
    xlabel('ms');
    ylabel('Fraction');
    title('First touch time');
end

for i = 1 : nMice
    ax = subplot(nMice,2,i*2);
    
    seTb = seTbs{i};
    s1 = seTb.SP{1};
    s2 = seTb.SP{2};
    stairs(s1.tEdges(1:end-1), s1.N, 'Color', cc(i,:)); hold on
    stairs(s2.tEdges(1:end-1), s2.N, '--', 'Color', cc(i,:));
    
    MPlot.Axes(ax);
    ax.Box = 'off';
    grid on
    xlim([0 9]);
    ylim([0 1]);
    xlabel('Positions/s');
    ylabel('Fraction');
    title('Sequence speed');
end


%% Session Overview

seInfo = SL.SE.GetSessionInfoTable(seArray)

nRows = 4;
numCols = 5;

for k = 1 : numel(seArray)
    f = figure;
    f.Color = 'w';
    
    bt = seArray(k).GetTable('behavTime');
    bv = seArray(k).GetTable('behavValue');
    seqTypes = categories(bv.seqId);
    tPlotEnd = prctile(bt.water(~isnan(bt.water)), 75) + 1.5;
    
    % Print session info
    ax = subplot(nRows, numCols, 1);
    textContent = [seInfo.animalId{k} '\n' datestr(seInfo.sessionDatetime(k), 31) '\n'];
    text(0, 0, sprintf(textContent), 'FontSize', 16, 'VerticalAlignment', 'top');
    ax.YDir = 'reverse';
    axis off
    
    % Plot running averages
    layoutMat = zeros(nRows, numCols);
    layoutMat(2:nRows-1) = 1;
    subplot(nRows, numCols, find(layoutMat'));
    SL.BehavFig.SessionRunAvg(gca, bt);
    
    % Plot CDFs
    layoutMat = zeros(nRows, numCols);
    layoutMat(nRows) = 1;
    subplot(nRows, numCols, find(layoutMat'));
    SL.BehavFig.SessionCDF(gca, bt(bv.opto ~= 0,:));
    
    % Sort and categorize trials
    [~, sortInd] = sortrows([bv.opto, bt.water]);
    bt = bt(sortInd,:);
    bv = bv(sortInd,:);
%     bt = bt(101:200,:);
%     bv = bv(101:200,:);
    
    % Plot regular sequences
    seq2plot = intersect({'123456', '543210'}, seqTypes, 'stable');
    for i = 1 : numel(seq2plot)
        layoutMat = zeros(nRows, numCols);
        layoutMat(:,i+1) = 1;
        subplot(nRows, numCols, find(layoutMat'));
        
        seqInd = bv.seqId == seq2plot{i};
        SL.BehavFig.TrialRaster(bt(seqInd,:));
        xlim([0 tPlotEnd]);
        ylabel([seq2plot{i} ' trials']);
    end
    
    % Plot backtracking sequences
    seq2plot = intersect({'1231456', '5435210'}, seqTypes, 'stable');
    for i = 1 : numel(seq2plot)
        layoutMat = zeros(nRows, numCols);
        layoutMat((i-1)*2+[1 2], 4) = 1;
        subplot(nRows, numCols, find(layoutMat'));
        
        seqInd = bv.seqId == seq2plot{i};
        SL.BehavFig.TrialRaster(bt(seqInd,:));
        xlim([0 tPlotEnd]);
        ylabel([seq2plot{i} ' trials']);
    end
    
    % Plot forward jump sequences
    seq2plot = intersect({'12356', '54310'}, seqTypes, 'stable');
    for i = 1 : numel(seq2plot)
        layoutMat = zeros(nRows, numCols);
        layoutMat((i-1)*2+[1 2], 5) = 1;
        subplot(nRows, numCols, find(layoutMat'));
        
        seqInd = bv.seqId == seq2plot{i};
        SL.BehavFig.TrialRaster(bt(seqInd,:));
        xlim([0 tPlotEnd]);
        ylabel([seq2plot{i} ' trials']);
    end
end

