% Plot example units
%{
Show the following with example sessions
1) Overlays of matched licking kinematics
2) Rasters and PETHs of example neruons in matched trials
3) Single unit spiking aligned with single trial behavior (S1TJ only)
%}

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig4');


%% Load SEs

seSearch = [ ...
    MBrowse.Dir2Table(fullfile(datDir, '**/MX170903 2018-03-04 se enriched.mat')); ... % ALM
    MBrowse.Dir2Table(fullfile(datDir, '**/MX181302 2019-02-10 se enriched.mat')); ... % M1TJ
    MBrowse.Dir2Table(fullfile(datDir, '**/MX181002 2018-12-29 se enriched.mat')); ... % S1TJ
    ];
sePaths = cellfun(@fullfile, seSearch.folder, seSearch.name, 'Uni', false);
seArray = SL.SE.LoadSession(sePaths);


%% Shared Transformations

ops = SL.Param.Transform;
ops = SL.Param.Resample(ops);
ops.tReslice = -2;
ops.maxReactionTime = 1;
ops.maxEndTime = 8;
disp(ops)

for i = 1 : numel(seArray)
    disp(SL.SE.GetID(seArray(i)));
    SL.SE.Transform(seArray(i), ops);
end


%% Period-specific Transformations

% Skip shared transformations
ops.isSpkRate = false;
ops.tReslice = 0;

% Time alignment
alignTypes = {'init', 'mid', 'term'};
ops.maxTrials = 10;

% Conditions of interest
conds = cell2table({ ...
    '123456', -1; ...
    '543210', -1; ...
    }, 'VariableNames', ops.conditionVars);
conds.seqId = SL.Param.CategorizeSeqId(conds.seqId);

% Transform SEs
seTbCell = cell(size(seArray));
unitTbCell = cell(size(seArray));

for i = 1 : numel(seArray)
    disp(SL.SE.GetID(seArray(i)));
    
    seTbCat = cell(size(alignTypes));
    for j = 1 : numel(alignTypes)
        disp(alignTypes{j});
        
        % Complete matching options
        ops.alignType = alignTypes{j};
        ops = SL.Param.FillMatchOptions(ops);
        
        % Transform SE
        se = seArray(i).Duplicate;
        seTb = SL.SE.Transform(se, ops);
        
        % Select conditions
        seTbCat{j} = SL.SE.CombineConditions(conds, seTb, 'Uni', true);
    end
    seTbCat = cat(1, seTbCat{:});
    
    seTbCell{i} = seTbCat;
    unitTbCell{i} = SL.Unit.UnitPETH(seTbCat.se);
end


%% Plot Matched Neural Activity

for i = 1 : numel(seTbCell)
    % Select examples
    sessionId = SL.SE.GetID(seArray(i));
    egInfo = SL.UnitFig.GetExampleInfo(sessionId);
    
    % Plot
    f = MPlot.Figure(34200+i); clf
    SL.UnitFig.PlotRasterPETHCombo(seTbCell{i}, unitTbCell{i}, egInfo.unitInd);
    MPlot.Paperize(f, 'ColumnsWide', .6, 'ColumnsHigh', .66);
    MPlot.SavePDF(f, fullfile(figDir, "example units " + egInfo.areaName));
end


return
%% Plot Example Trials

% Specify the example trial
se = seArray(3);
sessionId = SL.SE.GetID(se);
egInfo = SL.UnitFig.GetExampleInfo(sessionId);
trialIdx1 = find(se.epochInd == egInfo.trialNum(1), 1);
trialIdx2 = find(se.epochInd == egInfo.trialNum(2), 1);
unitIdx = egInfo.unitInd(1);

% Get data
[bt, bv, hsv, spk] = se.GetTable('behavTime', 'behavValue', 'hsv', 'spikeTime');

% Ploting
MPlot.Figure(32456); clf

ax = subplot(2,1,1); cla
SL.UnitFig.PlotTrial(trialIdx1, bt, bv, hsv, spk, unitIdx);
ax.XLim = [0 2.2];
ax.XAxis.Visible = 'off';

ax = subplot(2,1,2); cla
SL.UnitFig.PlotTrial(trialIdx2, bt, bv, hsv, spk, unitIdx);
ax.XLim = [0 2.2];

MPlot.Paperize(f, 'ColumnsWide', 2, 'ColumnsHigh', 0.2);
saveFigurePDF(f, fullfile(figDir, 'example units'));

