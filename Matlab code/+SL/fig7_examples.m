% Plot example units

datDir = SL.Data.analysisRoot;
figDir = fullfile(datDir, SL.Data.figDirName, 'Fig7');


%% Load SEs

seSearch = MBrowse.Dir2Table(fullfile(datDir, '**/MX170903 2018-03-04 se enriched.mat'));
sePaths = cellfun(@fullfile, seSearch.folder, seSearch.name, 'Uni', false);
seArray = SL.SE.LoadSession(sePaths);


%% Shared Transformations

ops = SL.Param.Transform;
ops.tReslice = -2;
ops.maxReactionTime = 1;
ops.maxEndTime = 8;

for i = 1 : numel(seArray)
    disp(SL.SE.GetID(seArray(i)));
    SL.SE.Transform(seArray(i), ops);
end


%% Period-specific Transformations

% Skip shared transformations
ops.isSpkRate = false;
ops.tReslice = 0;

% Add resampling options
ops = SL.Param.Resample(ops);

% Time alignment
alignTypes = {'mid', 'cons'};
ops.maxTrials = 20;

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
    egInfo = SL.Reward.GetExampleInfo(sessionId);
    
    % Plot
    f = MPlot.Figure(4230+i); clf
    SL.UnitFig.PlotRasterPETHCombo(seTbCell{i}, unitTbCell{i}, egInfo.unitInd, ...
        'BehavVars', {'water', 'air', 'touch'});
    MPlot.Paperize(f, 'ColumnsWide', 1, 'ColumnsHigh', .75);
    saveFigurePDF(f, fullfile(figDir, "example units " + egInfo.areaName));
end

