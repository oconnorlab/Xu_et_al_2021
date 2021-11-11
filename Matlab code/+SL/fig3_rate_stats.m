% Compute changes in lick and touch probability by areas and plot brain overlays

datDir = SL.Data.analysisRoot;
if ~exist('powerName', 'var')
    powerName = "5V";
end
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig3', powerName);


%% Compute 3s-long traces of lick and touch rate (for plotting)

cachePath = fullfile(figDir, 'computed rate stats 3s.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Find and load extracted data
    cacheSearch = MBrowse.Dir2Table(fullfile(figDir, "aaTb *.mat"));
    cachePaths = fullfile(cacheSearch.folder, cacheSearch.name);
    aa = SL.Opto.LoadAnimalAreaTable(cachePaths); % for individual animals
    aa = aa{:,:};
    
    % Set pipeline parameters
    tEdges = repmat((0 : .2 : 3)', [1 3]);
    tEdges = tEdges + [0 -.5 -1];
    q0 = struct;
    q0.tEdges = tEdges;
    q0.nboot = 0;
    s0 = struct;
    s0.rLick = q0;
    s0.rTouch = q0;
    
    aaResults = cell(size(aa));
    parfor i = 1 : numel(aa)
        lkTb = aa{i};
        s = SL.Opto.QuantifyPerf(lkTb, s0);
        aaResults{i} = s;
    end
    
    % Pool data across animals
    A = SL.Opto.CombineAnimalAreaTableRows(aa);
    
    % Modify pipeline parameters
    nboot = 2e3; % enough for up to 99% CI
    s0.rLick.nboot = nboot;
    s0.rTouch.nboot = nboot;
    
    aResults = cell(size(A));
    parfor i = 1 : numel(A)
        lkTb = A{i};
        s = SL.Opto.QuantifyPerf(lkTb, s0);
        aResults{i} = s;
    end
    
    save(cachePath, 'aaResults', 'aResults');
end


%% Plot 3s-long traces of lick and touch rate

[nMice, nArea] = size(aaResults);
areaInd = 1 : nArea;
miceInd = 1 : nMice;

ops = struct();
ops.aCI = 0.05;
ops.optoDur = 2;
ops.optoType = {'Init', 'Mid', 'Cons'};
ops.plotOptoBar = true;
ops.plotSig = false;
ops.plotShade = true;

f = MPlot.Figure(23123); clf
for i = 1 : 3
    for j = 1 : nArea
        ax = subplot(nArea, 3, (j-1)*3+i);
        SL.OptoFig.PlotLickRateTraces(aResults{areaInd(j)}, i, 'rTouch', ops);
        SL.OptoFig.PlotLickRateTraces(aResults{areaInd(j)}, i, 'rLick', ops);
    end
end
MPlot.Paperize(f, 'ColumnsWide', 1.2, 'ColumnsHigh', 0.2*nArea);
saveFigurePDF(f, fullfile(figDir, "3s rate traces"));

% f = MPlot.Figure(23124); clf
% for i = 1 : 3
%     for j = 1 : nArea
%         ax = subplot(nArea, 3, (j-1)*3+i);
%         for k = miceInd
%             SL.OptoFig.PlotLickRateTraces(aaResults{k,areaInd(j)}, i, 'rLick', ops);
%         end
%         SL.OptoFig.PlotLickRateTraces(aResults{areaInd(j)}, i, 'rLick', ops);
%     end
% end
% MPlot.Paperize(f, 'ColumnsWide', 1.2, 'ColumnsHigh', 0.2*nArea);
% saveFigurePDF(f, fullfile(figDir, "3s rate by mice"));


%% Compute 2s-long traces of lick and touch rate (for computing scalar stats)

cachePath = fullfile(figDir, 'computed rate stats 2s.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Find and load extracted data
    cacheSearch = MBrowse.Dir2Table(fullfile(figDir, "aaTb *.mat"));
    cachePaths = fullfile(cacheSearch.folder, cacheSearch.name);
    aa = SL.Opto.LoadAnimalAreaTable(cachePaths); % for individual animals
    aa = aa{:,:};
    
    % Set pipeline parameters
    tEdges = repmat((0 : .2 : 2)', [1 3]);
    q0 = struct;
    q0.tEdges = tEdges;
    q0.nboot = 0;
    s0 = struct;
    s0.rLick = q0;
    s0.rTouch = q0;
    
    aaResults = cell(size(aa));
    parfor i = 1 : numel(aa)
        lkTb = aa{i};
        s = SL.Opto.QuantifyPerf(lkTb, s0);
        aaResults{i} = s;
    end
    
    % Pool data across animals
    A = SL.Opto.CombineAnimalAreaTableRows(aa);
    
    % Modify pipeline parameters
    nboot = 2e3; % enough for up to 99% CI
    s0.rLick.nboot = nboot;
    s0.rTouch.nboot = nboot;
    
    aResults = cell(size(A));
    parfor i = 1 : numel(A)
        lkTb = A{i};
        s = SL.Opto.QuantifyPerf(lkTb, s0);
        aResults{i} = s;
    end
    
    save(cachePath, 'aaResults', 'aResults');
end


%% Plot scalar stats with 2s window

[nMice, nArea] = size(aaResults);
nQuant = 2;
nPeriod = 3;

ops = struct();
ops.aCI = 0.01;
ops.nCompare = nArea * nQuant * nPeriod; % number of comparisons for Bonferroni correction
ops.optoDur = 2;
ops.optoType = {'Init', 'Mid', 'Cons'};

f = MPlot.Figure(9811); clf
k = 0;
for i = 1 : nArea
    s = aResults{i};
    ss = aaResults(:,i);
    
%     tWin = [0 2];
%     s = SL.Opto.SliceStats(s, tWin);
%     ss = cellfun(@(x) SL.Opto.SliceStats(x, tWin), ss, 'Uni', false);
    
    s = SL.Opto.MixRateStats(s);
    ss = cellfun(@(x) SL.Opto.MixRateStats(x), ss, 'Uni', false);
    
    k = k + 1;
    
%     subplot(3, nArea, k); cla
%     SL.OptoFig.PlotBars(s, ss, 'rInit', 'scalar3', ops)
%     
%     subplot(3, nArea, k+nArea); cla
%     SL.OptoFig.PlotBars(s, ss, 'rMid', 'scalar3', ops)
    
    subplot(3, nArea, k+nArea*2); cla
    SL.OptoFig.PlotBars(s, ss, 'rCons', 'scalar3', ops)
end

MPlot.Paperize(f, 'ColumnsWide', 1.5, 'ColumnsHigh', .7);
saveFigurePDF(f, fullfile(figDir, "2s rate bars"));

%{

5V

ALM rCons
   11.0046    6.1546

S1TJ rCons
    0.0000    0.0029

S1BF rCons
    0.0696    0.1482

M1B rCons
   1.0e-13 *

    0.7994    0.3331

S1Tr rCons
    0.0448    0.8820



2.5V

ALM rCons
    0.4893   13.0974

S1TJ rCons
   1.0e-06 *

         0    0.7574

S1BF rCons
    5.2278    7.1472

M1B rCons
    0.0000    0.0065

S1Tr rCons
    5.7995    6.8575

%}


%% Compute 1s-long traces of lick and touch rate (for computing scalar stats)

cachePath = fullfile(figDir, 'computed rate stats 1s.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Find and load extracted data
    cacheSearch = MBrowse.Dir2Table(fullfile(figDir, "aaTb *.mat"));
    cachePaths = fullfile(cacheSearch.folder, cacheSearch.name);
    aa = SL.Opto.LoadAnimalAreaTable(cachePaths); % for individual animals
    aa = aa{:,:};
    
    % Set pipeline parameters
    tEdges = repmat((0 : .2 : 1)', [1 3]);
    q0 = struct;
    q0.tEdges = tEdges;
    q0.nboot = 0;
    s0 = struct;
    s0.rLick = q0;
    s0.rTouch = q0;
    
    aaResults = cell(size(aa));
    parfor i = 1 : numel(aa)
        lkTb = aa{i};
        s = SL.Opto.QuantifyPerf(lkTb, s0);
        aaResults{i} = s;
    end
    
    % Pool data across animals
    A = SL.Opto.CombineAnimalAreaTableRows(aa);
    
    % Modify pipeline parameters
    nboot = 2e3; % enough for up to 99% CI
    s0.rLick.nboot = nboot;
    s0.rTouch.nboot = nboot;
    
    aResults = cell(size(A));
    parfor i = 1 : numel(A)
        lkTb = A{i};
        s = SL.Opto.QuantifyPerf(lkTb, s0);
        aResults{i} = s;
    end
    
    save(cachePath, 'aaResults', 'aResults');
end


%% Plot scalar stats with 1s window

[nMice, nArea] = size(aaResults);
nQuant = 2;
nPeriod = 3;

ops = struct();
ops.aCI = 0.01;
ops.nCompare = nArea * nQuant * nPeriod; % number of comparisons for Bonferroni correction
ops.optoDur = 2;
ops.optoType = {'Init', 'Mid', 'Cons'};

f = MPlot.Figure(9812); clf
k = 0;
for i = 1 : nArea
    s = aResults{i};
    ss = aaResults(:,i);
    
    s = SL.Opto.MixRateStats(s);
    ss = cellfun(@(x) SL.Opto.MixRateStats(x), ss, 'Uni', false);
    
    k = k + 1;
    
    subplot(3, nArea, k); cla
    SL.OptoFig.PlotBars(s, ss, 'rInit', 'scalar3', ops)
    
    subplot(3, nArea, k+nArea); cla
    SL.OptoFig.PlotBars(s, ss, 'rMid', 'scalar3', ops)
    
%     subplot(3, nArea, k+nArea*2); cla
%     SL.OptoFig.PlotBars(s, ss, 'rCons', 'scalar3', ops)
end

MPlot.Paperize(f, 'ColumnsWide', 1.5, 'ColumnsHigh', .7);
saveFigurePDF(f, fullfile(figDir, "1s rate bars"));

%{

5V

ALM rInit
     0     0

ALM rMid
   1.0e-03 *

    0.7219    0.0000

S1TJ rInit
    0.1421         0

S1TJ rMid
    0.0086    0.0000

S1BF rInit
    7.0475   29.6048

S1BF rMid
    0.4299    0.3605

M1B rInit
    2.9800    0.0004

M1B rMid
   13.7946    2.5542

S1Tr rInit
    2.7642   16.0948

S1Tr rMid
    3.6169    4.2619



2.5V

ALM rInit
    1.4816    0.0004

ALM rMid
    4.8766    0.7582

S1TJ rInit
   26.4950         0

S1TJ rMid
    0.9209    0.0387

S1BF rInit
   12.9152   23.6654

S1BF rMid
    0.7782    0.7366

M1B rInit
   10.9850    3.4465

M1B rMid
   10.1200    3.5832

S1Tr rInit
    1.7494    9.0136

S1Tr rMid
    1.9212    1.8358

%}

