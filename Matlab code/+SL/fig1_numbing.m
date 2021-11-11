%% Quantifications of final performance

figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig1');


%% Load and prepare data

% Load experiment note
seTb = MBrowse.ReadXls(SL.Data.metadataSheet, 'Numbing');
seTb.is_numb = logical(seTb.is_numb);
for i = 3 : width(seTb)
    durStr = arrayfun(@(x) datestr(x, 'HH:MM:SS'), seTb.(i), 'Uni', false);
    seTb.(i) = duration(durStr);
    if ismember(seTb.Properties.VariableNames{i}, {'t2move', 't2engage'})
        seTb.(i) = minutes(seTb.(i));
    end
end

% Add animalId
for i = 1 : height(seTb)
    [~, seTb.animalId{i}] = SL.SE.GetID(seTb.session_id{i});
end

% Sort rows in the order of animalId and control->numbing
seTb = sortrows(seTb, {'animalId', 'is_numb'});

% Load sessions
dataSource = SL.Data.FindSessions('fig1_numbing');
seArray = SL.SE.LoadSession(dataSource.path);

% Put se into corresponding row of seTb
for i = 1 : numel(seArray)
    se = seArray(i);
    sId = SL.SE.GetID(se);
    m = strcmp(sId, seTb.session_id);
    seTb.animalId{m} = se.userData.sessionInfo.animalId;
    seTb.se(m) = se;
end

% Split rows in seTb by animals
aTb = table;
aTb.animalId = unique(seTb.animalId);
aTb = SL.SE.CombineConditions(aTb, seTb); % t and nMiss must be row vectors to prevent concatenation

% Only use animals that have complete data
aTbAll = aTb;
aTb = SL.Numb.RmIncomplete(aTb);


%% Compute stats for each animal

for i = 1 : height(aTb)
    aTb.tFT{i} = arrayfun(@(x) SL.Numb.ControlStats(x, 'pre_seq_time'), aTb.se{i});
    aTb.mFT{i} = arrayfun(@(x) SL.Numb.ControlStats(x, 'pre_seq_miss'), aTb.se{i});
    aTb.mSQ{i} = arrayfun(@(x) SL.Numb.ControlStats(x, 'seq_miss'), aTb.se{i});
end


%% Plot stats for individual mice

f = MPlot.Figure(1481); clf
SL.BehavFig.ControlStatsByMice(aTb);
MPlot.Paperize(f, 'ColumnsWide', .4, 'ColumnsHigh', 1);
saveFigurePDF(f, fullfile(figDir, "tongue numbing by mice"));


%% Plot stats of grouped results

f = MPlot.Figure(1580); clf
SL.BehavFig.ControlStatsGrouped(aTb);
MPlot.Paperize(f, 'ColumnsWide', .4, 'ColumnsHigh', 1);
saveFigurePDF(f, fullfile(figDir, "tongue numbing"));


return
%% Plot sessions

f = MPlot.Figure(1); clf
f.WindowState = 'maximized';
SL.Numb.PlotSessions(aTbAll, 'seq_miss');
% print(f, fullfile(dataSource.folder{1}, 'all sessions miss during seq'), '-dpng', '-r0');

f = MPlot.Figure(2); clf
f.WindowState = 'maximized';
SL.Numb.PlotSessions(aTbAll, 'pre_seq_miss');
% print(f, fullfile(dataSource.folder{1}, 'all sessions miss before seq'), '-dpng', '-r0');

% f = MPlot.Figure(3); clf
% SL.Numb.PlotTime2Engage(aTb);

