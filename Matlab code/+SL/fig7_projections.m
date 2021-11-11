%% Linear decoding of behavioral variables

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig7');


%% Load cached decoding results

areaList = {'ALM', 'M1TJ', 'S1TJ'};
decTb = cell(size(areaList));
for a = 1 : numel(areaList)
    cachePath = fullfile(figDir, ['dec cons-seq-cons ' areaList{a}]);
    decTb{a} = load(cachePath);
end
decTb = cat(1, decTb{:});
decTb = struct2table(decTb, 'AsArray', true);


%% Plot mean stimuli

comCat = cat(1, decTb.comTb{:});
comCat = comCat(ismember(comCat.seqId, {'123456', '543210'}), :);
comCat.reg = [];
comCat.pca = [];

% Combine data across areas
ops = SL.Param.Transform;
conds = table(-1, 'VariableNames', {'opto'});
comCat = SL.SE.CombineConditions(conds, comCat);

% Compute mean stats
mcomCat = SL.SE.SetMeanArrays(comCat);

%%

f = MPlot.Figure(2200); clf

mcomCat.color = [0 0 0];
mcomCat.line = {'-'};
SL.Reward.PlotProbLick(mcomCat);

MPlot.Paperize(f, 'ColumnsWide', .3, 'AspectRatio', .5);
saveFigurePDF(f, fullfile(figDir, "p lick"));


%% Plot projections

for a = 1 : numel(areaList)
    % Prepare variables
    sReg = decTb.sReg{a};
    subInd = [1 2 3 4 5];
    mcomTb = decTb.mcomTb{a};
    mcomTb = SL.PopFig.SetPlotParams(mcomTb);
    mcomTb = mcomTb(1:2,:); % only plot NN
    
    % Plot Linear Regression
    f = MPlot.Figure(2210+a); clf
    SL.PopFig.PlotMeanReg(mcomTb, sReg, subInd, 'AxesFun', @SL.PopFig.FormatRegAxes);
    ylim([0 .35]);
    MPlot.Paperize(f, 'ColumnsWide', .3, 'AspectRatio', 3.3);
    saveFigurePDF(f, fullfile(figDir, "cons proj " + decTb.areaName{a}));
end


%% Report numbers

fileID = fopen(fullfile(figDir, 'cons decoding numbers.txt'), 'w');
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


return

%% Plot stimuli

for a = 1 : numel(areaList)
    % Prepare variables
    comTb = decTb.comTb{a};
    comTb = SL.PopFig.SetPlotParams(comTb);
    comTb = comTb(1,:); % only plot NN
    ops = SL.Param.Transform;
    subInd = [1 2 3];
    
    % Plot Linear Regression
    f = MPlot.Figure(2300+a); clf
    SL.PopFig.PlotStim(comTb, ops, subInd, 'SessionInd', []); % 1 9 10
%     MPlot.Paperize(f, 'ColumnsWide', .35, 'AspectRatio', 1.8);
%     saveFigurePDF(f, fullfile(figDir, "projections iti " + decTb.areaName{a}));
end


%% Plot mean stimuli

for a = 1 : numel(areaList)
    % Prepare variables
    mcomTb = decTb.mcomTb{a};
    mcomTb = SL.PopFig.SetPlotParams(mcomTb);
    mcomTb = mcomTb(1:2,:); % only plot NN
    ops = SL.Param.Transform;
    subInd = [1 2 3];
    
    % Plot Linear Regression
    f = MPlot.Figure(2200+a); clf
    SL.PopFig.PlotMeanStim(mcomTb, ops, subInd);
    SL.Reward.PlotProbLick(mcomTb);
    ylabel('');
    MPlot.Paperize(f, 'ColumnsWide', .3, 'AspectRatio', 1.8);
    saveFigurePDF(f, fullfile(figDir, "cons stimuli " + decTb.areaName{a}));
end


