%% Quantifications of final performance

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig1');


%% Make and cache a table where a row is a sequence type of a session, and columns contain lickObj and key timestamps

cachePath = fullfile(figDir, 'extracted lick data.mat');

if exist(cachePath, 'file')
    % Load cached data
    load(cachePath);
else
    % Processing parameters
    ops = SL.Param.Transform;
    ops.isSpkRate = false;
    ops.maxReactionTime = Inf;
    ops.maxEndTime = 10;
    conds = cell2table({ ... % specify conditions of interest
        '123456', -1; ...
        '543210', -1; ...
        '1231456', -1; ...
        '5435210', -1; ...
        }, 'VariableNames', ops.conditionVars);
    conds.seqId = SL.Param.CategorizeSeqId(conds.seqId);
    
    % Extract and cache lick data
    dataSource = SL.Data.FindSessions('fig1_seq_stats');
    sePaths = dataSource.path;
    seTbCat = cell(size(sePaths));
    parfor i = 1 : numel(sePaths)
        % Load SE
        se = SL.SE.LoadSession(sePaths{i});
        disp(SL.SE.GetID(se));
        
        % Tranform SE
        seTb = SL.SE.Transform(se, ops);
        seTb = SL.SE.CombineConditions(conds, seTb, 'Uni', true);
        
        % Extract lick data
        seTb = SL.Behav.ExtractLickData(seTb, false); % false for not inverting
        seTbCat{i} = seTb;
    end
    seTbCat = cat(1, seTbCat{:});
    
    % Cache extracted data
    save(cachePath, 'dataSource', 'seTbCat', 'ops', 'conds');
end


%% Select standard seqs and group conditions by animals

% Find normal sequences
isSS = seTbCat.seqId == '123456' | seTbCat.seqId == '543210';

% Group data by animals
[G, AA] = findgroups(seTbCat(isSS, 'animalId'));
AA.lickObj = splitapply(@(x) {cat(1, x{:})}, seTbCat.lickObj(isSS), G);

% Report numbers
fileID = fopen(fullfile(figDir, 'sequence stats.txt'), 'w');
fprintf(fileID, 'Include %d mice, %d sessions, %d trials\n', ...
    height(AA), sum(isSS)/2, sum(cellfun(@numel, AA.lickObj)));
fclose(fileID);


%% Compute histograms from sequence realted and video tracked licks

lenEdges = 0 : .25 : 5;
angEdges = -60 : 5 : 60;
dAngEdges = -30 : 2.5 : 45;
drEdges = 0 : 0.5 : 12;
nPos = 7;


% Compute angle and length histograms
for k = 1 : height(AA)
    % By animals
    licks = AA.lickObj{k};
    licks = cat(1, licks{:});
    licks = licks(([licks.isDrive]' | [licks.isReward]') & licks.IsTracked);
    AA.lenDist{k} = histcounts(licks.MaxLength, lenEdges, 'Normalization', 'probability')';
    AA.angDist{k} = histcounts(licks.AngleAtTouch, angEdges, 'Normalization', 'probability')';
    
    % By port positions
    lenDD = zeros(length(lenEdges)-1, nPos);
    angDD = zeros(length(angEdges)-1, nPos);
    for i = 1 : nPos
        licksAtPos = licks([licks.portPos] == i-1);
        lenDD(:,i) = histcounts(licksAtPos.MaxLength, lenEdges, 'Normalization', 'probability');
        angDD(:,i) = histcounts(licksAtPos.AngleAtTouch, angEdges, 'Normalization', 'probability');
    end
    AA.lenDistByPos{k} = lenDD;
    AA.angDistByPos{k} = angDD;
end

lenDistByPos = cat(3, AA.lenDistByPos{:});
lenDistByPosMean = nanmean(lenDistByPos, 3);
lenDistByPosStd = nanstd(lenDistByPos, 0, 3);

angDistByPos = cat(3, AA.angDistByPos{:});
angDistByPosMean = nanmean(angDistByPos, 3);
angDistByPosStd = nanstd(angDistByPos, 0, 3);


% Compute delta angle and drive rate histograms
for k = 1 : height(AA)
    % Find quantities
    dAng = zeros(numel(AA.lickObj{k}), nPos-1);
    dr = zeros(numel(AA.lickObj{k}), nPos-1);
    
    for m = 1 : size(dAng,1)
        licks = AA.lickObj{k}{m};
        licks = licks([licks.isDrive] | [licks.isReward]);
        if numel(licks) ~= nPos
            fprintf('This trial has %d drive licks. %s, k = %d, m = %d\n', ...
                numel(licks), AA.animalId{k}, k, m);
            continue;
        end
        dr(m,:) = 1 ./ diff(licks);
        
        licks = licks(licks.IsTracked);
        if numel(licks) ~= nPos
            continue;
        end
        dAng(m,:) = diff(licks.AngleAtTouch);
        if diff([licks([1 end]).portPos]) > 0
            dAng(m,:) = -dAng(m,:);
        end
    end
    dAng(all(dAng==0,2),:) = [];
    dr(all(dr==0,2),:) = [];
    
    % By animal
    AA.dAngDist{k} = histcounts(dAng(:), dAngEdges, 'Normalization', 'probability')';
    AA.drDist{k} = histcounts(dr(:), drEdges, 'Normalization', 'probability')';
    
    % By drive intervals
    dAngDD = zeros(length(dAngEdges)-1, size(dAng,2));
    drDD = zeros(length(drEdges)-1, size(dr,2));
    for i = 1 : size(dr,2)
        dAngDD(:,i) = histcounts(dAng(:,i), dAngEdges, 'Normalization', 'probability');
        drDD(:,i) = histcounts(dr(:,i), drEdges, 'Normalization', 'probability');
    end
    AA.dAngDistByItvl{k} = dAngDD;
    AA.drDistByItvl{k} = drDD;
end

dAngDistByItvl = cat(3, AA.dAngDistByItvl{:});
dAngDistByItvlMean = mean(dAngDistByItvl, 3);
dAngDistByItvlStd = std(dAngDistByItvl, 0, 3);

drDistByItvl = cat(3, AA.drDistByItvl{:});
drDistByItvlMean = mean(drDistByItvl, 3);
drDistByItvlStd = std(drDistByItvl, 0, 3);


dAngDistPval = NaN(size(dAngDistByItvlMean,2));
for i = 1 : size(dAngDistPval,2)
    for j = i+1 : size(dAngDistPval,2)
        ecdf1 = cumsum(dAngDistByItvlMean(:,i));
        ecdf2 = cumsum(dAngDistByItvlMean(:,j));
        [~, dAngDistPval(i,j)] = MMath.KStest2CDF(ecdf1, ecdf2);
    end
end


%% Plot violin histograms

f = MPlot.Figure(7293); clf

lenX = (lenEdges(1:end-1) + diff(lenEdges(1:2))/2)';
angX = (angEdges(1:end-1) + diff(angEdges(1:2))/2)';
cMean = [0 0 0];
cSD = [0 0 0]+.7;
prcts = [25 50 75];

% Average Distributions across Animals broken down by Position
ax = subplot(4,1,1); cla
for i = 1 : nPos
    hold on
    MPlot.Violin(i, lenX, (lenDistByPosMean(:,i)+lenDistByPosStd(:,i)/2)*2, 'Color', cSD);
    MPlot.Violin(i, lenX, lenDistByPosMean(:,i)*2, 'Color', cMean);
end
ax.XLim = [0 i+1];
ax.XTick = 1:i;
ax.XTickLabel = ["R"+(3:-1:1), "Mid", "L"+(1:3)];
ax.YLim = [0 4];
ax.YTick = 0:2:4;
ax.Box = 'off';
ylabel('L_{max} (mm)');

ax = subplot(4,1,2); cla
for i = 1 : nPos
    hold on
    MPlot.Violin(i, angX, (angDistByPosMean(:,i)+angDistByPosStd(:,i)/2)*2, 'Color', cSD);
    MPlot.Violin(i, angX, angDistByPosMean(:,i)*2, 'Color', cMean);
end
ax.XLim = [0 i+1];
ax.XTick = 1:i;
ax.XTickLabel = ["R"+(3:-1:1), "Mid", "L"+(1:3)];
ax.YLim = angEdges([1 end]);
ax.YTick = -45 : 45 : 45;
ax.Box = 'off';
ylabel('\theta_{touch} (deg)');
plot(ax.XLim', [0 0]', '-', 'Color', [0 0 0 .15], 'LineWidth', .5);


drX = (drEdges(1:end-1) + diff(drEdges(1:2))/2)';
dAngX = (dAngEdges(1:end-1) + diff(dAngEdges(1:2))/2)';

% Average Distributions across Animals broken down by Position
ax = subplot(4,1,3); cla
for i = 1 : nPos-1
    hold on
    MPlot.Violin(i, dAngX, (dAngDistByItvlMean(:,i)+dAngDistByItvlStd(:,i)/2)*4, 'Color', cSD);
    MPlot.Violin(i, dAngX, dAngDistByItvlMean(:,i)*4, 'Color', cMean);
end
ax.XLim = [0 i+1];
ax.XTick = 1:i;
ax.XTickLabel = string(1:i) + '-' + string(2:i+1);
ax.YLim = [-30 40];
ax.YTick = dAngEdges(1) : 30 : dAngEdges(end);
ax.Box = 'off';
ylabel('\Delta\Theta_{touch}');
plot(ax.XLim', [0 0]', '-', 'Color', [0 0 0 .15], 'LineWidth', .5);

% Average Distributions across Animals broken down by Position
ax = subplot(4,1,4); cla
for i = 1 : nPos-1
    hold on
    MPlot.Violin(i, drX, (drDistByItvlMean(:,i)+drDistByItvlStd(:,i))*3, 'Color', cSD);
    MPlot.Violin(i, drX, drDistByItvlMean(:,i)*3, 'Color', cMean);
end
ax.XLim = [0 i+1];
ax.XTick = 1:i;
ax.XTickLabel = string(1:i) + '-' + string(2:i+1);
ax.YLim = [0 10];
ax.YTick = 0:5:11;
ax.Box = 'off';
ylabel('Positions/s');


MPlot.Paperize(f, 'ColumnsWide', .5, 'ColumnsHigh', .75);
saveFigurePDF(f, fullfile(figDir, 'sequence stats'));


