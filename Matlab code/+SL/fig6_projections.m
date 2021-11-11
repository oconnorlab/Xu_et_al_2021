%% Linear decoding of behavioral variables

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig6');


%% Load cached decoding results

areaList = {'ALM'};
decTb = cell(size(areaList));
for a = 1 : numel(areaList)
    cachePath = fullfile(figDir, ['dec iti-iti-iti ' areaList{a}]);
    decTb{a} = load(cachePath);
end
decTb = cat(1, decTb{:});
decTb = struct2table(decTb, 'AsArray', true);


%% Plot Projections

for a = 1 : numel(areaList)
    % Prepare variables
    sReg = decTb.sReg{a};
    mcomTb = decTb.mcomTb{a};
    mcomTb = SL.PopFig.SetPlotParams(mcomTb);
    mcomTb = mcomTb(1:2,:); % only plot NN
    
    % Plot Linear Regression
    f = MPlot.Figure(610+a); clf
    SL.PopFig.PlotMeanReg(mcomTb, sReg, 'AxesFun', @SL.ITI.FormatRegAxes);
    MPlot.Paperize(f, 'ColumnsWide', .4, 'AspectRatio', 1.2);
    saveFigurePDF(f, fullfile(figDir, "projections iti " + decTb.areaName{a}));
end


%% Load cached decoding results

areaList = {'ALM'};
decTb = cell(size(areaList));
for a = 1 : numel(areaList)
    cachePath = fullfile(figDir, ['dec seq-iti-seq ' areaList{a}]);
    decTb{a} = load(cachePath);
end
decTb = cat(1, decTb{:});
decTb = struct2table(decTb, 'AsArray', true);


%% Plot Projections

for a = 1 : numel(areaList)
    % Prepare variables
    sReg = decTb.sReg{a};
    mcomTb = decTb.mcomTb{a};
    mcomTb = SL.PopFig.SetPlotParams(mcomTb);
%     mcomTb = mcomTb(1:2,:); % only plot NN
    
    % Plot Linear Regression
    f = MPlot.Figure(620+a); clf
    SL.PopFig.PlotMeanReg(mcomTb, sReg, 'AxesFun', @SL.ITI.FormatRegAxes);
    MPlot.Paperize(f, 'ColumnsWide', .4, 'AspectRatio', 1.2);
    saveFigurePDF(f, fullfile(figDir, "projections seq " + decTb.areaName{a}));
end


%% Report numbers

fileID = fopen(fullfile(figDir, 'decoding numbers.txt'), 'w');
for a = 1 : numel(areaList)
    % Prepare variables
    sReg = decTb.sReg{a};
    mcomTb = decTb.mcomTb{a};
    
    fprintf(fileID, '%s\n', areaList{a});
    fprintf(fileID, '%i sessions\n', numel(sReg));
    for j = 1 : height(mcomTb)
        fprintf(fileID, 'seq %s: %g\n', mcomTb.seqId(j), sum(mcomTb.numMatched{j}));
    end
    fprintf(fileID, '\n');
end
fclose(fileID);




