%% Load SE

filePaths = MBrowse.Files();
seArray = SL.Util.LoadSession(filePaths, 'Enrich', false);
seInfo = SL.Util.GetSessionInfoTable(seArray)


%% Extract data by sessions

bts = arrayfun(@(x) x.GetTable('behavTime'), seArray, 'Uni', false);
bvs = arrayfun(@(x) x.GetTable('behavValue'), seArray, 'Uni', false);
tRefs = arrayfun(@(x) x.GetReferenceTime('behavTime'), seArray, 'Uni', false);


%% Reslice SEs and extract data

% Merge SEs
seCat = seArray(1).Merge(seArray(2:end));
btCat = seCat.GetTable('behavTime');
bvCat = seCat.GetTable('behavValue');
tRefCat = seCat.GetReferenceTime('behavTime');

% Split tables
nTrials = 2000;
binSize = 100;
nBins = nTrials / binSize;
[~, ~, binInd] = histcounts(seCat.epochInd, 1:binSize:nTrials+1);

bts = cell(nBins,1);
bvs = cell(nBins,1);
tRefs = cell(nBins,1);
for i = 1 : nBins
    isInBin = binInd == i;
    bts{i} = btCat(isInBin,:);
    bvs{i} = bvCat(isInBin,:);
    tRefs{i} = tRefCat(isInBin);
end


%% Animal Summary

f = figure(123); clf
f.Color = 'w';
numPlots = 5;

% Info

subplot(numPlots,2,1); cla
dictStr = arrayfun(@(x,y) ['{\bf' num2str(x) '}' datestr(y, ': mm-dd')], ...
    1:numel(seArray), seInfo.sessionDatetime', 'Uni', false);
text(1:numel(seArray), zeros(size(seArray)), dictStr, ...
    'FontSize', 8, 'HorizontalAlignment', 'center', 'Rotation', 60);
xlim([0 numel(seArray)+1]);
ylim([-1 1]);
title(seInfo.animalId{1});
axis off


% Motivation

subplot(numPlots,2,3); cla
statTN = SL.Behav.TrialNumStat(gca, bts);

subplot(numPlots,2,5); cla
statITI = SL.Behav.InterTrialIntervalStat(gca, bts, tRefs);


% Sequence

subplot(numPlots,2,7); cla
statFD = SL.Behav.FirstDriveStat(gca, bts);
title('Sequence Initiation (or First Drive Touch) Time');

subplot(numPlots,2,9); cla
ind = cellfun(@(tb) tb.seqId == '123456' | tb.seqId == '543210', bvs, 'Uni', false);
btsSub = cellfun(@(tb,i) tb(i,:), bts, ind, 'Uni', false);
statSeqDurN = SL.Behav.SeqDurStat(gca, btsSub);
title('Duration of Normal Sequences')

subplot(numPlots,2,2); cla
ind = cellfun(@(tb) tb.seqId == '1231456' | tb.seqId == '5435210', bvs, 'Uni', false);
btsSub = cellfun(@(tb,i) tb(i,:), bts, ind, 'Uni', false);
statSeqDurP = SL.Behav.SeqDurStat(gca, btsSub);
title('Duration of Perturbed Sequences')

transRange = [4 6];

ax = subplot(numPlots,2,4); cla
ind = cellfun(@(tb) tb.seqId == '123456' | tb.seqId == '543210', bvs, 'Uni', false);
btsSub = cellfun(@(tb,i) tb(i,:), bts, ind, 'Uni', false);
statSeqDurNT = SL.Behav.SeqDurStat(gca, btsSub, transRange);
statSeqDurNT.transRange = transRange;
% ax.YScale = 'linear';
ylim([1e2 2e4]);
title('Interval at Normal Transition')

ax = subplot(numPlots,2,6); cla
ind = cellfun(@(tb) tb.seqId == '1231456' | tb.seqId == '5435210', bvs, 'Uni', false);
btsSub = cellfun(@(tb,i) tb(i,:), bts, ind, 'Uni', false);
statSeqDurPT = SL.Behav.SeqDurStat(gca, btsSub, transRange);
statSeqDurPT.transRange = transRange;
% ax.YScale = 'linear';
ylim([1e2 2e4]);
title('Interval at Perturbed Transition')

if ismember('airOn', bts{1}.Properties.VariableNames)
%     subplot(numPlots,2,8); cla
%     ind = cellfun(@(tb) tb.seqId == '123456' | tb.seqId == '543210', bvs, 'Uni', false);
%     btsSub = cellfun(@(tb,i) tb(i,:), bts, ind, 'Uni', false);
%     statMissN = SL.Behav.SeqMissStat(gca, btsSub);
%     title('Total Number of Miss Lick in Normal Sequences')
%     
%     subplot(numPlots,2,10); cla
%     ind = cellfun(@(tb) tb.seqId == '1231456' | tb.seqId == '5435210', bvs, 'Uni', false);
%     btsSub = cellfun(@(tb,i) tb(i,:), bts, ind, 'Uni', false);
%     statMissP = SL.Behav.SeqMissStat(gca, btsSub);
%     title('Total Number of Miss Lick in Perturbed Sequences')
    
    subplot(numPlots,2,8); cla
    ind = cellfun(@(tb) tb.seqId == '123456' | tb.seqId == '543210', bvs, 'Uni', false);
    btsSub = cellfun(@(tb,i) tb(i,:), bts, ind, 'Uni', false);
    statMissPT = SL.Behav.SeqMissStat(gca, btsSub, transRange);
    statMissPT.transRange = transRange;
    title('Number of Miss Lick at Normal Transition')
    
    subplot(numPlots,2,10); cla
    ind = cellfun(@(tb) tb.seqId == '1231456' | tb.seqId == '5435210', bvs, 'Uni', false);
    btsSub = cellfun(@(tb,i) tb(i,:), bts, ind, 'Uni', false);
    statMissPT = SL.Behav.SeqMissStat(gca, btsSub, transRange);
    statMissPT.transRange = transRange;
    title('Number of Miss Lick at Perturbed Transition')
end

% saveFigurePDF(f, [seInfo.animalId{1} ' overview']);
% print(gcf, [seInfo.animalId{1} ' overview'], '-dpng', '-r0')


%% Save results

var2save = struct();
var2save.sessionInfo = seInfo;

var2save.statTN = statTN;
var2save.statITI = statITI;

var2save.statFD = statFD;
var2save.statSeqDurN = statSeqDurN;
var2save.statSeqDurP = statSeqDurP;
var2save.statSeqDurNT = statSeqDurNT;
var2save.statSeqDurPT = statSeqDurPT;

if exist('statMissN', 'var')
    var2save.statMissN = statMissN;
    var2save.statMissP = statMissP;
    var2save.statMissPT = statMissPT;
end

save(['seArray ' seInfo(1).animalId '.mat'], 'seArray', 'filePaths');
save(['behav_sessions output ' seInfo(1).animalId '.mat'], '-struct', 'var2save');




