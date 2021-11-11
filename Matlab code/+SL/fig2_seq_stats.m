%% Characterize backtracking sequences

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


%% Process lickObjs

lickObj = seTbCat.lickObj;
nNN = 0;
nBB = 0;

for r = 1 : numel(lickObj)
    for k = 1 : numel(lickObj{r}) % through trials
        % Select licks
        licks = lickObj{r}{k};
        licks = licks(licks.IsTracked);
        
        if ~isempty(licks)
            % Invert direction
            if licks(1).portPos == 0
                licks = licks.InvertDirection;
            end
            
            % Label licks wrt Mid
            tMid = seTbCat.tMid{r}(k);
            tLicks = double(licks);
            [~, iTrig] = min(abs(tLicks - tMid));
            ids = (1 : numel(licks))';
            ids = ids - iTrig;
            ids(tLicks - tMid > 2) = NaN;
            licks = licks.SetVfield('lickId', ids);
        end
        
        lickObj{r}{k} = licks;
    end
    
    % Count trials
    if ismember(seTbCat.seqId(r), {'1231456', '5435210'})
        nBB = nBB + k;
    else
        nNN = nNN + k;
    end
end

lickObj = cellfun(@(x) cat(1,x{:}), lickObj, 'Uni', false);


%% Group data by animal

% Find normal sequences
isSeq = ismember(seTbCat.seqId, {'123456', '543210'});
G = findgroups(seTbCat(isSeq, 'animalId'));
lickObjNN = splitapply(@(x) {cat(1,x{:})}, lickObj(isSeq), G);

% Find backtracking sequences
isSeq = ismember(seTbCat.seqId, {'1231456', '5435210'});
G = findgroups(seTbCat(isSeq, 'animalId'));
lickObjBB = splitapply(@(x) {cat(1,x{:})}, lickObj(isSeq), G);

% Report stats
animalNames = unique(seTbCat.animalId);
fileID = fopen(fullfile(figDir, 'lick stats.txt'), 'w');
fprintf(fileID, 'Include %d mice, %d sessions, %d trials of normal and %d trials of backtracking sequences\n', ...
    numel(animalNames), numel(unique(seTbCat.sessionId)), nNN, nBB);
for i = 1 : numel(animalNames)
    fprintf(fileID, '%s\n', animalNames{i});
end
fclose(fileID);


%% Compute histograms from sequence realted and video tracked licks

lickId = (-1 : 5)';

quantTb = table();
quantTb.name = {'length', 'angle', 'dAngle', 'rate'}';
quantTb.edges = {0:.2:5, -60:5:60, -45:5:45, 0:.5:12}';

[meanTbNN, stdTbNN] = SL.Behav.ComputeMeanLickStats(lickObjNN, quantTb, lickId);
[meanTbBB, stdTbBB] = SL.Behav.ComputeMeanLickStats(lickObjBB, quantTb, lickId);


%% Plot violin histograms

quantTb.centers = cellfun(@(x) x(1:end-1) + diff(x)/2, quantTb.edges, 'Uni', false);

f = MPlot.Figure(7893); clf

for i = 1 : height(quantTb)
    % Prepare data
    qn = quantTb.name{i};
    xn = quantTb.centers{i}';
    xb = quantTb.centers{i}';
    yn = meanTbNN.(qn)';
    yb = meanTbBB.(qn)';
    en = stdTbNN.(qn)';
    eb = stdTbBB.(qn)';
    if ismember(qn, {'dAngle', 'rate'})
        yn = yn(:,2:end);
        yb = yb(:,2:end);
        en = en(:,2:end);
        eb = eb(:,2:end);
    end
    r = 1./max([yn(:); yb(:)])*.33;
    
    % Plot distributions
    ax = subplot(4,1,i); hold on
    ax.XTick = 1 : size(yn,2);
    ax.XTickLabel = lickId;
    ax.XLim = [-.6 .6] + ax.XTick([1 end]);
    ax.YLim = quantTb.edges{i}([1 end]);
    switch qn
        case 'angle'
            plot(ax.XLim', [0 0]', 'Color', [0 0 0]+.8);
            ax.YTick = -45 : 45 : 45;
            ylabel('\Theta_{shoot} (deg)');
        case 'length'
            ax.YLim = [0 4];
            ax.YTick = 0:2:4;
            ylabel('L_{max} (mm)');
        case 'dAngle'
            plot(ax.XLim', [0 0]', 'Color', [0 0 0]+.8);
            ax.XTickLabel = lickId(1:end-1) + "~" + lickId(2:end);
            ax.YTick = -30:30:30;
            ylabel('\Delta\Theta_{shoot}');
        case 'rate'
            ax.XTickLabel = lickId(1:end-1) + "~" + lickId(2:end);
            ax.YLim = [0 10];
            ax.YTick = 0:5:10;
            ylabel('Licks/s');
    end
    MPlot.Axes(ax);
    
    for j = 1 : size(yn,2)
        MPlot.Violin(j-.2, xn, (yn(:,j)+en(:,j)/2)*r, 'Color', [0 0 0], 'Alpha', .15);
        MPlot.Violin(j-.2, xn, yn(:,j)*r, 'Color', [0 0 0]);
        
        MPlot.Violin(j+.2, xb, (yb(:,j)+eb(:,j)/2)*r, 'Color', SL.Param.backColor, 'Alpha', .15);
        MPlot.Violin(j+.2, xb, yb(:,j)*r, 'Color', SL.Param.backColor);
    end
end

MPlot.Paperize(f, 'ColumnsWide', .6, 'AspectRatio', 1.25);
saveFigurePDF(f, fullfile(figDir, 'sequence stats'));

