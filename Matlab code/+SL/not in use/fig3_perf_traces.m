% Average lick and touch probabilities as a function of time

datDir = SL.Param.GetAnalysisRoot;

if ~exist('powerName', 'var')
    powerName = "5V";
end
figDir = fullfile(datDir, SL.Param.figDirName, 'Fig3', powerName);


%% Find and load extracted data

cacheSearch = MBrowse.Dir2Table(fullfile(figDir, "aaTb *.mat"));
cachePaths = fullfile(cacheSearch.folder, cacheSearch.name);

aaTb = SL.Opto.LoadAnimalAreaTable(cachePaths);
areaCell = SL.Opto.CombineAnimalAreaTableRows(aaTb);
clear aaTb


%% Report the number of trials included

fileID = fopen(fullfile(figDir, 'trials included.txt'), 'w');
for i = 1 : numel(areaCell)
    lkTb = areaCell{i};
    areaName = lkTb.xlsInfo{1}(1).area;
    optoType = lkTb.opto;
    nTrials = cellfun(@sum, lkTb.numTrial);
    
    fprintf(fileID, '%s\n', areaName);
    for j = 1 : height(lkTb)
        fprintf(fileID, 'opto %g: %g\n', optoType(j), nTrials(j));
    end
    fprintf(fileID, 'total: %g\n\n', sum(nTrials));
end
fclose(fileID);


%% Compute lick probability and quantity traces

cachePath = fullfile(figDir, "computed perf traces.mat");

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Compute traces
    resultCell = repmat({struct}, size(areaCell));
    for i = 1 : numel(areaCell)
        lkTb = areaCell{i};
        s = resultCell{i};
        
        % Configure pipeline
        tEdges = repmat((0 : .2 : 3)', [1 3]);
        tEdges = tEdges + [0 -.5 -1];
        s.rLick.tEdges = tEdges;
        s.rLick.aCI = 0.05;
        s.rTouch.tEdges = tEdges;
        s.rTouch.aCI = 0.05;
        s.ang.tEdges = tEdges;
        s.len.tEdges = tEdges;
        
        % Run pipeline
        s = SL.Opto.ComputeTraces(lkTb, s);
        
%         % Derive SD traces from angle
%         s.angsd = s.ang;
%         s.angsd.opto(:,:,1) = s.angsd.opto(:,:,2);
%         s.angsd.opto(:,:,2) = NaN;
%         s.angsd.ctrl(:,:,1) = s.angsd.ctrl(:,:,2);
%         s.angsd.ctrl(:,:,2) = NaN;
        
        % Plotting parameters
        s.info.optoDur = 2;
        s.info.optoType = {'Init', 'Mid', 'Cons'};
        
        % Store variables
        resultCell{i} = s;
    end
    
    save(cachePath, 'resultCell');
end


%% Plot lick and touch probability

areaInd = 1 : numel(resultCell);
% areaInd = [1 2 3];
nArea = numel(areaInd);

ops = struct();
ops.plotOptoBar = true;
ops.plotSig = false;
ops.plotShade = true;

f = MPlot.Figure(23123); clf
for i = 1 : 3
    for j = 1 : nArea
        ax = subplot(nArea, 3, (j-1)*3+i);
        SL.OptoFig.PlotLickRateTraces(resultCell{areaInd(j)}, i, 'rTouch', ops);
        SL.OptoFig.PlotLickRateTraces(resultCell{areaInd(j)}, i, 'rLick', ops);
    end
end
MPlot.Paperize(f, 'ColumnsWide', 1.2, 'ColumnsHigh', 0.2*nArea);
saveFigurePDF(f, fullfile(figDir, "rate traces"));


%% Plot angle and length

ops = struct();
ops.plotOptoBar = true;
ops.plotSig = true;
ops.plotShade = true;

f = MPlot.Figure(23223); clf
for i = 1 : 3
    for j = 1 : nArea
        ax = subplot(nArea, 3, (j-1)*3+i);
        SL.OptoFig.PlotLickQuantTraces(resultCell{areaInd(j)}, i, 'ang', ops);
    end
end
MPlot.Paperize(f, 'ColumnsWide', 1.2, 'ColumnsHigh', 0.24*nArea);
saveFigurePDF(f, fullfile(figDir, "angle traces"));


f = MPlot.Figure(23224); clf
for i = 1 : 3
    for j = 1 : nArea
        ax = subplot(nArea, 3, (j-1)*3+i);
        SL.OptoFig.PlotLickQuantTraces(resultCell{areaInd(j)}, i, 'len', ops);
    end
end
MPlot.Paperize(f, 'ColumnsWide', 1.2, 'ColumnsHigh', 0.24*nArea);
saveFigurePDF(f, fullfile(figDir, "length traces"));


return

%% Plot angle sequences

f = MPlot.Figure(12456); clf

areaInd = [3 2 4];
rng(61);

for i = 1 : numel(areaInd)
    k = areaInd(i);
    for j = 1 : 3
        subplot(numel(areaInd), 3, (i-1)*3+j); cla
        SL.OptoFig.AngleSeq(areaCell{k}, resultCell{k}, j);
    end
end


%% Plot length sequences

f = MPlot.Figure(12457); clf

areaInd = [3 2 4];
rng(61);

for i = 1 : numel(areaInd)
    k = areaInd(i);
    for j = 1 : 3
        subplot(numel(areaInd), 3, (i-1)*3+j); cla
        SL.OptoFig.LengthSeq(areaCell{k}, resultCell{k}, j);
    end
end




