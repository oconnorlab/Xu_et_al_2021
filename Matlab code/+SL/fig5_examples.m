%% Example single trials decoding

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig5');


%% Load cached decoding results

areaList = {'ALM', 'M1TJ', 'S1TJ', 'S1BF'};
decTb = cell(size(areaList));
for a = 1 : numel(areaList)
    cachePath = fullfile(figDir, ['dec seq-seq-seq ' areaList{a}]);
    decTb{a} = load(cachePath);
end
decTb = cat(1, decTb{:});
decTb = struct2table(decTb);


%% ALM: MX170903 2018-03-04

areaIdx = 1;
rowIdx = [1 2];
sessionIdx = 1;
trialIdx = [2 6];

comTb = decTb.comTb{areaIdx}(rowIdx,:);
comTb = SL.PopFig.SetPlotParams(comTb);
sReg = decTb.sReg{areaIdx};
lims = {[-.3 3.5], [-100 100], [-45 45], [.5 2.5], [-.5 .8]};

f = MPlot.Figure(4935); clf
SL.PopFig.PlotExample(sessionIdx, trialIdx, comTb, sReg, lims);
MPlot.Paperize(f, 'ColumnsWide', .9, 'ColumnsHigh', 1.2);
saveFigurePDF(f, fullfile(figDir, ['single trial ' decTb.areaName{areaIdx}]));


%% S1TJ: MX181002 2018-12-29

areaIdx = 3;
rowIdx = [1 2];
sessionIdx = 4;
trialIdx = [6 2];

comTb = decTb.comTb{areaIdx}(rowIdx,:);
comTb = SL.PopFig.SetPlotParams(comTb);
sReg = decTb.sReg{areaIdx};
lims = {[-.3 3.5], [-100 100], [-55 35], [.5 2.5], [-.5 .8]};

f = MPlot.Figure(4936); clf
SL.PopFig.PlotExample(sessionIdx, trialIdx, comTb, sReg, lims);
MPlot.Paperize(f, 'ColumnsWide', .9, 'ColumnsHigh', 1.2);
saveFigurePDF(f, fullfile(figDir, ['single trial ' decTb.areaName{areaIdx}]));


