%%

datDir = SL.Param.GetAnalysisRoot;
figDir = fullfile(datDir, SL.Param.figDirName, 'Fig5');


%%

% Find files
areaName = 'M2ALM';
% disp(areaName);
areaDirName = ['Data Ephys ' areaName];
seTbSearch = MBrowse.Dir2Table(fullfile(datDir, areaDirName, 'lm seq', 'seTb*.mat'));

% Load data
seTbArray = cell(height(seTbSearch),1);
for i = 1 : height(seTbSearch)
    load(fullfile(seTbSearch.folder{i}, seTbSearch.name{i}));
    seTbArray{i} = seTb;
end


%% 

% Processing parameters
ops = SL.Param.Transform;
ops.hsvVars = {};
ops.adcVars = {};
ops.valVars = {};
ops.derivedVars = {'posUni', 'posUniMono'};
ops.rsWin = [-.5 .8];
ops.dimAverage = [];
ops.dimCombine = [3 1];

% Compute stim, resp and projection matrices
for i = 1 : numel(seTbArray)
    seTb = seTbArray{i};
    seTb = SL.SE.SetStimRespArrays(seTb, ops);
    seTbArray{i} = seTb;
end

% Combine sessions
seTb = cat(1, seTbArray{:});
seTb.resp = [];
conds = cell2table({ ...
    '123456', -1; ...
    '543210', -1; ...
    '1231456', -1; ...
    '5435210', -1; ...
    }, 'VariableNames', ops.conditionVars);
conds.seqId = SL.Param.CategorizeSeqId(conds.seqId);
comTb = SL.SE.CombineConditions(conds, seTb);

% Reduce data size
comTb.se = [];

% Compute mean stats
mcomTb = SL.Pop.SetMeanArrays(comTb);
mcomTb = SL.PopFig.SetPlotParams(mcomTb);


%% 

f = MPlot.Figure(7537); clf
SL.PopFig.PlotMeanStim(mcomTb, ops);
MPlot.Paperize(f, 'ColumnsWide', .35, 'AspectRatio', 1);
saveFigurePDF(f, fullfile(figDir, "target traces"));




