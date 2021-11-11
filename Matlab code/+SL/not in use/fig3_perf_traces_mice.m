% Compute changes in lick and touch probability by areas and plot brain overlays

datDir = SL.Param.GetAnalysisRoot;

if ~exist('powerName', 'var')
    powerName = "5V";
end
figDir = fullfile(datDir, SL.Param.figDirName, 'Fig3', powerName);


%% Compute lick probability and quantity traces

cachePath = fullfile(figDir, 'computed perf traces by mice.mat');

if exist(cachePath, 'file')
    % Load previously computed results
    load(cachePath);
else
    % Find and load extracted data
    cacheSearch = MBrowse.Dir2Table(fullfile(figDir, "aaTb *.mat"));
    cachePaths = fullfile(cacheSearch.folder, cacheSearch.name);
    aaTb = SL.Opto.LoadAnimalAreaTable(cachePaths);
    aaCell = aaTb{:,:};
    clear aaTb
    
    % Label licks
    aaCell = SL.Opto.IndexLicks(aaCell);
    
    resultCell = cell(size(aaCell));
    for i = 1 : numel(aaCell)
        lkTb = aaCell{i};
        s = resultCell{i};
        
        % Configure pipeline
        tEdges = repmat((0 : .2 : 1)', [1 3]);
        tEdges(1,:) = -0.002; % include trigger licks
        s.pLick.tEdges = tEdges;
        s.pLick.pCI = 0.05;
        s.ang.tEdges = tEdges;
        s.len.tEdges = tEdges;
        
        % Run pipeline
        s = SL.Opto.ComputeTraces(lkTb, s);
        
        % Restore time bin
        tEdges(1,:) = 0; % include trigger licks
        s.pLick.tEdges = tEdges;
        s.ang.tEdges = tEdges;
        s.len.tEdges = tEdges;
        
        % Derive SD traces from angle
        s.angsd = s.ang;
        s.angsd.opto(:,:,1) = s.angsd.opto(:,:,2);
        s.angsd.opto(:,:,2) = NaN;
        s.angsd.ctrl(:,:,1) = s.angsd.ctrl(:,:,2);
        s.angsd.ctrl(:,:,2) = NaN;
        
        % Plotting parameters
        s.info.optoDur = 2;
        s.info.optoType = {'Init', 'Mid', 'Cons'};
        
        % Store variables
        resultCell{i} = s;
    end
    
    save(cachePath, 'resultCell');
end


%% Plot lick and touch probability

[nMice, nArea] = size(resultCell);
areaInd = 1 : nArea;
miceInd = 1 : nMice;
% miceInd = 5;

ops = struct();
ops.plotOptoBar = false;
ops.plotSig = false;
ops.plotShade = true;


f = MPlot.Figure(23123); clf
for i = 1 : 3
    for j = 1 : nArea
        ax = subplot(nArea, 3, (j-1)*3+i);
        for k = miceInd
            s = resultCell{k,areaInd(j)};
            SL.OptoFig.PlotLickProbTraces(s, i, 'pLick', ops);
        end
    end
end
disp(s.info.animal_id);

MPlot.Paperize(f, 'ColumnsWide', .7, 'ColumnsHigh', nArea*0.24);
saveFigurePDF(f, fullfile(figDir, "rate traces by mice"));


f = MPlot.Figure(23223); clf
for i = 1 : 3
    for j = 1 : nArea
        ax = subplot(nArea, 3, (j-1)*3+i);
        for k = miceInd
            s = resultCell{k,areaInd(j)};
            SL.OptoFig.PlotLickQuantTraces(s, i, 'len', ops);
        end
    end
end
MPlot.Paperize(f, 'ColumnsWide', .7, 'ColumnsHigh', nArea*0.24);
saveFigurePDF(f, fullfile(figDir, "length traces by mice"));

ops.plotShade = false;

f = MPlot.Figure(23224); clf
for i = 1 : 3
    for j = 1 : nArea
        ax = subplot(nArea, 3, (j-1)*3+i);
        for k = miceInd
            s = resultCell{k,areaInd(j)};
            SL.OptoFig.PlotLickQuantTraces(s, i, 'ang', ops);
        end
    end
end
MPlot.Paperize(f, 'ColumnsWide', .7, 'ColumnsHigh', nArea*0.24);
saveFigurePDF(f, fullfile(figDir, "angle traces by mice"));


f = MPlot.Figure(23225); clf
for i = 1 : 3
    for j = 1 : nArea
        ax = subplot(nArea, 3, (j-1)*3+i);
        for k = miceInd
            s = resultCell{k,areaInd(j)};
            SL.OptoFig.PlotLickQuantTraces(s, i, 'angsd', ops);
        end
    end
end
MPlot.Paperize(f, 'ColumnsWide', .7, 'ColumnsHigh', nArea*0.24);
saveFigurePDF(f, fullfile(figDir, "angle sd traces by mice"));



