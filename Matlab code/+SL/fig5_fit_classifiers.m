%% Fit classifiers

datDir = SL.Param.GetAnalysisRoot;
% datDir = 'D:\Data';

if ~exist('fitName', 'var')
    fitName = 'bif';
end
if ~exist('areaList', 'var')
    areaList = {'ALM', 'M1TJ', 'S1TJ', 'S1BF'}; % 'M1B', 'S1L'
end


%% Find se files

seSearch = cell(numel(areaList),1);
for i = 1 : numel(areaList)
    seSearch{i} = MBrowse.Dir2Table(fullfile(datDir, ['Data Ephys ' areaList{i}], '* se enriched.mat'));
end
seSearch = cat(1, seSearch{:});


%% Tansform SE and cache seTb

% Set up options
ops = SL.Param.Transform;

ops.isOverwrite = false;

ops.isMorph = true;
ops.tReslice = -2;
ops.maxReactionTime = 1;
ops.maxEndTime = 8;
ops.isMatch = true;
ops.conditionVars = {'isBacktrack', 'opto'};
ops.hsvVars = {};
ops.adcVars = {};
ops.valVars = {'seqId'};

switch fitName
    case 'bif'
        ops.alignType = 'seq';
    otherwise
        error('''%s'' is not a valid fitName', fitName);
end
ops = SL.Param.FillMatchOptions(ops);
ops

% Run pipeline
SL.Pop.MakeSETables(seSearch, ['class ' fitName], ops);


%% Find seTb files

seTbSearch = cell(numel(areaList),1);
for i = 1 : numel(areaList)
    seTbSearch{i} = MBrowse.Dir2Table(fullfile(datDir, ['Data Ephys ' areaList{i}], ['class ' fitName ' tl_*'], 'seTb *.mat'));
end
seTbSearch = cat(1, seTbSearch{:});


%% Model fitting

isOverwrite = false;

for i = 1 : height(seTbSearch)
    % Make paths
    lmDir = seTbSearch.folder{i};
    seTbName = seTbSearch.name{i};
    sessionId = SL.SE.GetID(seTbName);
    
    mdlsPath = fullfile(lmDir, ['mdls ' sessionId '.mat']);
    if exist(mdlsPath, 'file') && ~isOverwrite
        warning('%s already exists and will not be overwritten', ['mdls ' sessionId '.mat']);
        continue
    end
    
    % Load seTb
    load(fullfile(lmDir, seTbName));
    
    % Set up options
    ops.dimAverage = [];
    ops.dimCombine = [3 1];
    ops.conditionTb = cell2table({ ...
        '123456', -1; ...
        '543210', -1; ...
        }, 'VariableNames', ops.conditionVars);
    ops.conditionTb.seqId = SL.Param.CategorizeSeqId(ops.conditionTb.seqId);
    switch fitName
        case 'seq'
            ops.rsWin = [-.5 .5];
            ops.ldaVars = {'seqId'};
            ops.regVars = { ...
                'tongue_bottom_length', 'tongue_bottom_velocity', ...
                'tongue_bottom_angle', ...
                'seqId', 'timeVar'};
        case 'iti'
            ops.rsWin = [-1 0];
            ops.ldaVars = {'seqId'};
            ops.regVars = {'seqId', 'timeVar'};
    end
    ops.derivedVars = {}; % for backward compatibility
    
    % Compute
    mdls = SL.Pop.FitLinearModels(seTb, ops);
    
    % Save result
    disp('Save mdls');
    save(mdlsPath, 'mdls');
end


