%% Mean quantities in 

datDir = SL.Data.analysisRoot;
if ~exist('powerName', 'var')
    powerName = "5V";
end
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig3', powerName);


%% Compute quantity traces

cachePath = fullfile(figDir, 'computed quant stats.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Find and load cached animal-area tables
    cacheSearch = MBrowse.Dir2Table(fullfile(figDir, "aaTb *.mat"));
    cachePaths = fullfile(cacheSearch.folder, cacheSearch.name);
    aa = SL.Opto.LoadAnimalAreaTable(cachePaths);
    aa = aa{:,:};
    
    % Set pipeline parameters to compute for individual animals
    tEdges = repmat((0 : .2 : 1)', [1 3]);
    q0 = struct;
    q0.tEdges = tEdges;
    q0.tEdges(1,:) = -0.002; % temporarily change to include trigger licks
    q0.nboot = 0;
    s0 = struct;
    s0.ang = q0;    % angle
    s0.angSD = q0;  % SD of angle
    s0.angAbs = q0; % absolute angle
    s0.len = q0;    % length
    
    aaResults = cell(size(aa));
    parfor i = 1 : numel(aa)
        lkTb = aa{i};
        
        % Run pipeline
        s = SL.Opto.QuantifyPerf(lkTb, s0);
        
        % Restore time bin
        s.ang.tEdges = tEdges;
        s.angsd.tEdges = tEdges;
        s.aang.tEdges = tEdges;
        s.len.tEdges = tEdges;
        
        % Store variables
        aaResults{i} = s;
    end
    
    % Pool data across animals
    A = SL.Opto.CombineAnimalAreaTableRows(aa);
    
    % Modify pipeline parameters
    nboot = 2e3; % enough for up to 99% CI
    s0.ang.nboot = nboot;
    s0.angSD.nboot = nboot;
    s0.angAbs.nboot = nboot;
    s0.len.nboot = nboot;
    
    aResults = cell(size(A));
    parfor i = 1 : numel(A)
        lkTb = A{i};
        
        % Run pipeline
        s = SL.Opto.QuantifyPerf(lkTb, s0);
        
        % Restore time bin
        s.ang.tEdges = tEdges;
        s.angsd.tEdges = tEdges;
        s.aang.tEdges = tEdges;
        s.len.tEdges = tEdges;
        
        % Store variables
        aResults{i} = s;
    end
    
    save(cachePath, 'aaResults', 'aResults');
end


%% Plot quantity traces

[nMice, nArea] = size(aaResults);
areaInd = 1 : nArea;
quantNames = {'angSD', 'angAbs', 'len', 'ang'};
nQuant = numel(quantNames);
nPeriod = 3;
miceInd = 1 : nMice;

% areaInd = 1;
% miceInd = [1:7]; % use this to check data for individual mice

ops = struct();
ops.aCI = 0.05;
ops.optoDur = 2;
ops.optoType = {'Init', 'Mid', 'Cons'};

for a = areaInd
    f = MPlot.Figure(23200+a); clf
    for q = 1 : nQuant
        qName = quantNames{q};
        for p = 1 : nPeriod
            ax = subplot(nQuant, nPeriod, (q-1)*nPeriod+p);
            ops.style = 'mouse_1s';
            for m = miceInd
                s = aaResults{m,a};
                SL.OptoFig.PlotLickQuantTraces(s, p, qName, ops);
            end
            ops.style = 'mean_1s';
            s = aResults{a};
            SL.OptoFig.PlotLickQuantTraces(s, p, qName, ops);
        end
    end
    MPlot.Paperize(f, 'ColumnsWide', .6, 'ColumnsHigh', nQuant*0.22);
    saveFigurePDF(f, fullfile(figDir, "1s quant traces " + s.info.area));
end


%% Summary bar plots for each area, quantity and inhibition period

ops = struct();
ops.aCI = 0.01;
ops.nCompare = nArea * nQuant * nPeriod; % number of comparisons for Bonferroni correction
ops.optoDur = 2;
ops.optoType = {'Init', 'Mid', 'Cons'};

f = MPlot.Figure(9851); clf
k = 0;
rng(61);
for i = 1 : nArea
    k = k + 1;
    
    subplot(nPeriod, nArea, k); cla
    SL.OptoFig.PlotBars(aResults{i}, aaResults(:,i), 'angSD', 'separate', ops)
    
    subplot(nPeriod, nArea, k+nArea); cla
    SL.OptoFig.PlotBars(aResults{i}, aaResults(:,i), 'angAbs', 'separate', ops)
    
    subplot(nPeriod, nArea, k+nArea*2); cla
    SL.OptoFig.PlotBars(aResults{i}, aaResults(:,i), 'len', 'separate', ops)
end

MPlot.Paperize(f, 'ColumnsWide', 1.5, 'ColumnsHigh', .7);
saveFigurePDF(f, fullfile(figDir, "1s quant bars"));


%% Summary bar plots for each area and quantity, across inhibition periods

ops.nCompare = nArea * nQuant; % number of comparisons for Bonferroni correction

f = MPlot.Figure(9852); clf
k = 0;
rng(61);
for i = 1 : nArea
    k = k + 1;
    
    subplot(3, nArea, k); cla
    SL.OptoFig.PlotBars(aResults{i}, aaResults(:,i), 'angSD', 'combined', ops)
    
    subplot(3, nArea, k+nArea); cla
    SL.OptoFig.PlotBars(aResults{i}, aaResults(:,i), 'angAbs', 'combined', ops)
    
    subplot(3, nArea, k+nArea*2); cla
    SL.OptoFig.PlotBars(aResults{i}, aaResults(:,i), 'len', 'combined', ops)
end

MPlot.Paperize(f, 'ColumnsWide', 1.5, 'ColumnsHigh', .7);
saveFigurePDF(f, fullfile(figDir, "1s quant bars combined exact pval"));

%{

5V

ALM angSD
    2.5746

ALM angAbs
     0

ALM len
     0

S1TJ angSD
     0

S1TJ angAbs
   13.6255

S1TJ len
    0.0031

S1BF angSD
   16.0170

S1BF angAbs
    4.1058

S1BF len
    0.0041

M1B angSD
   6.2377e-04

M1B angAbs
   12.9166

M1B len
    0.1467

S1Tr angSD
    0.8838

S1Tr angAbs
    2.8731

S1Tr len
    0.0019



2.5V

ALM angSD
   6.5133e-05

ALM angAbs
     0

ALM len
   3.3070e-06

S1TJ angSD
   2.1176e-10

S1TJ angAbs
   13.2971

S1TJ len
    0.2041

S1BF angSD
   19.4315

S1BF angAbs
   10.0234

S1BF len
    0.7458

M1B angSD
    0.0241

M1B angAbs
    7.1355

M1B len
    0.0056

S1Tr angSD
   12.0052

S1Tr angAbs
    7.2173

S1Tr len
    1.3172

%}

