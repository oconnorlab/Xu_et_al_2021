%% Backtracking sequence classification

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig5');
if ~exist('areaList', 'var')
    areaList = {'ALM', 'M1TJ', 'S1TJ', 'S1BF'};
end
if ~exist('predName', 'var')
    predName = 'pca';
end


%% Classify sequence type for each session

% Find seTb files
seTbSearch = cell(numel(areaList),1);
mdlsSearch = cell(numel(areaList),1);
for i = 1 : numel(areaList)
    seTbSearch{i} = MBrowse.Dir2Table(fullfile(datDir, ['Data ephys ' areaList{i}], 'seq dt_0*', 'seTb *.mat'));
    mdlsSearch{i} = MBrowse.Dir2Table(fullfile(datDir, ['Data ephys ' areaList{i}], 'seq dt_0*', 'lm *.mat'));
end
seTbSearch = cat(1, seTbSearch{:});
mdlsSearch = cat(1, mdlsSearch{:});

% Compute for each session
isOverwrite = false;

for i = 1 : height(seTbSearch)
    % Check for cached file
    nameParts = strsplit(seTbSearch.name{i}, {' ', '.'});
    sessionId = SL.SE.GetID(nameParts{2}, nameParts{3});
    cacheName = ['cla_' predName ' ' sessionId '.mat'];
    cachePath = fullfile(seTbSearch.folder{i}, cacheName);
    if exist(cachePath, 'file') && ~isOverwrite
        warning('%s already exists and will not be overwritten', cacheName);
        continue
    end
    
    % Load data
    load(fullfile(seTbSearch.folder{i}, seTbSearch.name{i}));
    load(fullfile(mdlsSearch.folder{i}, mdlsSearch.name{i}));
    ops = mdls.ops;
    
    % Only keep sequences of interest
    condTb = table;
    condTb.seqId = SL.Param.CategorizeSeqId([SL.Param.stdSeqs SL.Param.backSeqs]');
    condTb.opto(:) = -1;
    seTb = SL.SE.CombineConditions(condTb, seTb, 'UniformOutput', true);
    
    % Check if session has and only has two std seqs and two backtrack seqs
    if height(seTb) ~= height(condTb)
        fprintf('%s does not have all the required sequences for this analysis\n', sessionId);
        disp(seTb.seqId);
        continue
    end
    disp(['Compute for session ' sessionId]);
    disp(seTb.seqId);
    
    % Combine standard sequences and backtracking sequences, respectively
    seqSets = {SL.Param.stdSeqs, SL.Param.backSeqs};
    for k = 1 : numel(seqSets)
        ind = find(ismember(seTb.seqId, seqSets{k}));
        seTb.se(ind(1)) = Merge(seTb.se(ind));
        seTb.numTrial(ind(1)) = sum(seTb.numTrial(ind));
        seTb.numMatched(ind(1)) = sum(seTb.numMatched(ind));
        seTb.seqId(ind(2)) = categorical(NaN);
    end
    seTb = seTb(~isundefined(seTb.seqId), :);
    
    % Set up options
    ops.adcVars = {};
    ops.valVars = {};
    ops.rsWin = [-.2 .4];
    ops.rsBinSize = 0.015;
    ops.dimCombine = [];
    seTb = SL.SE.SetStimRespArrays(seTb, ops);
    seTb = SL.Pop.SetProjArrays(seTb, mdls, 12); % taking 12 dimensions
    
    % Perform classification
    ops.alpha = 0.05;
    claTb = SL.Error.ClassifyBraching(seTb, predName, ops.alpha);
    
%     cla2Add = SL.Error.ClassifyBraching(seTb, predName, ops.alpha);
%     load(fullfile(seTbSearch.folder{i}, 'bk2 weighted', cacheName));
%     claTb.rShuf = cla2Add.rShuf;
%     claTb.rShufCV = cla2Add.rShufCV;
%     claTb.rShufStats = cla2Add.rShufStats;
    
    % Extract behavioral quantities
    behavTb = claTb(:, {'animalId', 'sessionId', 'time'});
    behavTb.var{1} = cat(3, seTb.stim{:});
    
    % Save results
    disp('Save classification results');
    save(cachePath, 'claTb', 'behavTb', 'ops');
end


%% Hierarchical bootstrap classification for the mean accuracy

isOverwrite = false;

mClaTbCat = table();

for i = 1 : numel(areaList)
    % Check for cached file
    areaName = areaList{i};
    cacheName = ['cla_' predName ' ' areaName '.mat'];
    cachePath = fullfile(figDir, cacheName);
    
    if exist(cachePath, 'file') && ~isOverwrite
        warning('%s has been computed and will not be overwritten', cacheName);
        load(cachePath);
    else
        % Load claTb and behavTb
        claSearch = MBrowse.Dir2Table(fullfile(datDir, ['Data Ephys ' areaName], 'seq dt_0*', ['cla_' predName ' *.mat']));
        claArray = cell(height(claSearch), 2);
        for k = 1 : height(claSearch)
            load(fullfile(claSearch.folder{k}, claSearch.name{k}));
            claArray{k,1} = claTb;
            claArray{k,2} = behavTb;
        end
        claTbCat = vertcat(claArray{:,1});
        behavTbCat = vertcat(claArray{:,2});
        
        % Classification
        nBoot = 200;
        [rBoot, rShufBoot] = SL.Pop.HierBootClassify(nBoot, claTbCat);
        ops.alpha = 0.05;
        ciLims = [ops.alpha/2 1-ops.alpha/2] * 100;
        rStats = [mean(rBoot,2) prctile(rBoot, ciLims, 2)];
        rShufStats = [mean(rShufBoot,2) prctile(rShufBoot, ciLims, 2)];
        
        % Behavioral variables
        B = cat(3, behavTbCat.var{:});
        B = squeeze(B(:,1,:));
        [m, sd, ~, ci] = MMath.MeanStats(B, 2, 'Alpha', 0.01);
        rZero = mean(B==0, 2);
        lenStats = cat(2, m, sd, ci, rZero);
        
        mCla = struct;
        mCla.areaName = areaName;
        mCla.claTb = claTbCat;
        mCla.behavTb = behavTbCat;
        mCla.ops = ops;
        mCla.time = claTbCat.time{1};
        mCla.rBoot = rBoot;
        mCla.rShufBoot = rShufBoot;
        mCla.rStats = rStats;
        mCla.rShufStats = rShufStats;
        mCla.lenStats = lenStats;
        mClaTb = struct2table(mCla, 'AsArray', true);
        save(cachePath, 'mClaTb');
    end
    
    mClaTbCat = [mClaTbCat; mClaTb];
end


%% Plot mean classification accuracy

f = MPlot.Figure(400); clf
SL.PopFig.PlotBranchCla(mClaTbCat);
MPlot.Paperize(f, 'ColumnsWide', 2, 'AspectRatio', .25);
saveFigurePDF(f, fullfile(figDir, "cla_" + predName + " all areas"));


%% Plot classification accuacy of each session

for i = 1 : height(mClaTbCat)
    f = MPlot.Figure(400+i); clf
    SL.PopFig.PlotBranchClaBySession(mClaTbCat.claTb{i});
    MPlot.Paperize(f, 'ColumnsWide', 1.25, 'AspectRatio', .8);
    print(f, fullfile(figDir, ['cla_' predName ' ' mClaTbCat.areaName{i}]), '-dpng', '-r0');
end


%% Plot classification onset time

mClaTbCat = SL.Error.ClaOnsetHist(mClaTbCat);

% f = MPlot.Figure(2374); clf
% SL.PopFig.PlotBootTraces(mClaTbCat);
% MPlot.Paperize(f, 'ColumnsWide', .33, 'AspectRatio', 3);
% print(f, fullfile(figDir, 'bootstrap mean cla traces'), '-dpng', '-r0');

f = MPlot.Figure(2375); clf
SL.PopFig.PlotOnsetDist(mClaTbCat);
MPlot.Paperize(f, 'ColumnsWide', .5, 'AspectRatio', .5);
saveFigurePDF(f, fullfile(figDir, "cla onset CDFs"));


%% Test differences of classification onset time among areas

T = mClaTbCat;
p = zeros(3,1);
d = p;
e = p;
[p(1), d(1), e(1)] = SL.Error.ClaOnsetTest(T.tOnset{1}, T.tOnset{2});
[p(2), d(2), e(2)] = SL.Error.ClaOnsetTest(T.tOnset{1}, T.tOnset{3});
[p(3), d(3), e(3)] = SL.Error.ClaOnsetTest(T.tOnset{2}, T.tOnset{3});
[p d e]

%{

1/31/2021       pVal        dt          sd(dt)
ALM vs M1TJ     0.9108     -0.0040      0.0390
ALM vs S1TJ 	0           0.0847      0.0366
M1TJ vs S1TJ    0           0.0905      0.0411

%}


return
%% 

claTbFiles = MBrowse.Files('C:\Users\yaxig\Dropbox (oconnorlab)\Documents\RnD\OConnor Lab\Project Seqlick\Analysis\Data Ephys ALM\seq dt_0');

claTbCat = cellfun(@load, claTbFiles);
claTbCat = arrayfun(@(x) x.claTb, claTbCat, 'Uni', false);
claTbCat = cat(1, claTbCat{:});

f = MPlot.Figure(400+i); clf
SL.PopFig.PlotBranchClaBySession(claTbCat);
MPlot.Paperize(f, 'ColumnsWide', 1.25, 'AspectRatio', .8);
print(f, fullfile(figDir, ['cla_' predName ' ALM ' datestr(now, 'mmddHHMM')]), '-dpng', '-r0');


%% Update cached file

for i = 1 %: numel(areaList)
    % Load cached file
    areaName = areaList{i};
    cacheName = ['cla_' predName ' ' areaName '.mat'];
    cachePath = fullfile(figDir, cacheName);
    load(cachePath);
%     rBoot = mClaTb.rBoot{1};
%     rShufBoot = mClaTb.rShufBoot{1};
%     rStats = mClaTb.rStats{1};
%     rShufStats = mClaTb.rShufStats{1};
    
    % Load claTb and behavTb
    claSearch = MBrowse.Dir2Table(fullfile(datDir, ['Data Ephys ' areaName], 'seq dt_0*', ['cla_' predName ' *.mat']));
    claArray = cell(height(claSearch), 2);
    for k = 1 : height(claSearch)
        load(fullfile(claSearch.folder{k}, claSearch.name{k}));
        claArray{k,1} = claTb;
        claArray{k,2} = behavTb;
    end
    claTbCat = vertcat(claArray{:,1});
    behavTbCat = vertcat(claArray{:,2});
    
    % Update
    mClaTb.claTb{1} = claTbCat;
    
    save(cachePath, 'mClaTb');
end

