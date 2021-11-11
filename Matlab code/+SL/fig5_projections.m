%% Linear decoding of behavioral variables

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, figName);


%% Load cached decoding results

if strcmp(figName, 'Fig5')
    dataSource = MBrowse.Dir2Table(fullfile(figDir, 'dec seq-seq-seq *.mat'));
elseif strcmp(figName, 'FigZ')
    dataSource = MBrowse.Dir2Table(fullfile(figDir, 'dec seq_zz-seq_zz-seq_zz *.mat'));
end

decTb = cell(height(dataSource), 1);
for i = 1 : numel(decTb)
    decTb{i} = load(fullfile(dataSource.folder{i}, dataSource.name{i}));
end
decTb = cat(1, decTb{:});
decTb = struct2table(decTb, 'AsArray', true);


%% Plot Projections

for i = 1 : height(decTb)
    % Prepare variables
    sReg = decTb.sReg{i};
    mcomTb = decTb.mcomTb{i};
    mcomTb = SL.PopFig.SetPlotParams(mcomTb);
    
    % Plot Linear Regression
    f = MPlot.Figure(510+i); clf
    if strcmp(figName, 'FigZ')
        SL.PopFig.PlotMeanReg(mcomTb, sReg, 'AxesFun', @SL.PopFig.FormatRegAxesZZ);
    else
        SL.PopFig.PlotMeanReg(mcomTb, sReg, 'AxesFun', @SL.PopFig.FormatRegAxes);
    end
    MPlot.Paperize(f, 'ColumnsWide', .35, 'AspectRatio', 3.3);
    saveFigurePDF(f, fullfile(figDir, "projections " + decTb.areaName{i}));
end


%% Report numbers

fileID = fopen(fullfile(figDir, 'decoding numbers.txt'), 'w');
for i = 1 : height(decTb)
    % Prepare variables
    sReg = decTb.sReg{i};
    mcomTb = decTb.mcomTb{i};
    
    fprintf(fileID, '%s\n', decTb.areaName{i});
    fprintf(fileID, '%i sessions\n', numel(sReg));
    for j = 1 : height(mcomTb)
        fprintf(fileID, 'seq %s: %g\n', mcomTb.seqId(j), sum(mcomTb.numMatched{j}));
    end
    fprintf(fileID, '\n');
end
fclose(fileID);

