%% Fit linear models

% Choose parameters based on analysis
switch analysisName
    case 'fig5_seq_coding'
        fitName = 'seq';
        rsWin = [-.5 .5];
        areaList = {'ALM', 'M1TJ', 'S1TJ', 'S1BF', 'M1B', 'S1L'};
        
    case 'fig5_t_lag'
        fitName = 'seq';
        rsWin = [-.5 .5];
        areaList = {'ALM', 'M1TJ', 'S1TJ'};
        
    case 'fig6_iti_coding'
        fitName = 'iti';
        rsWin = [-1 0];
        areaList = {'ALM', 'M1TJ', 'S1TJ', 'S1BF'};
        
    case 'figZ_seq_coding'
        fitName = 'seq_zz';
        rsWin = [-1 1];
        areaList = {'ZZ'};
        
    otherwise
        error('''%s'' is not a valid analysisName', analysisName);
end

if strcmp(analysisName, 'fig6_iti_coding')
    regVars = {'seqId', 'timeVar'};
else
    regVars = { ...
        'tongue_bottom_length', 'tongue_bottom_velocity', ...
        'tongue_bottom_angle', ...
        'seqId', 'timeVar'};
end


%% Find seTb files

dataSource = cell(numel(areaList),1);
for i = 1 : numel(areaList)
    pathPattern = fullfile(SL.Data.analysisRoot, ['Data ephys ' areaList{i}], [fitName ' dt_*'], 'seTb *.mat');
    dataSource{i} = MBrowse.Dir2Table(pathPattern);
end
dataSource = cat(1, dataSource{:});


%% Model fitting

isOverwrite = false;

for i = 1 : height(dataSource)
    % Make paths
    seTbDir = dataSource.folder{i};
    seTbName = dataSource.name{i};
    
    lmName = strrep(seTbName, 'seTb', 'lm');
    lmPath = fullfile(seTbDir, lmName);
    if exist(lmPath, 'file') && ~isOverwrite
        warning('%s already exists and will not be overwritten', lmName);
        continue
    end
    
    % Load seTb
    load(fullfile(seTbDir, seTbName));
    
    % Set up options
    ops = SL.Param.Resample(ops);
    ops.dimCombine = [1 3];
    ops.conditionTb = cell2table({ ...
        '123456', -1; ...
        '543210', -1; ...
        '123432101234', -1; ...
        '321012343210', -1; ...
        }, 'VariableNames', ops.conditionVars);
    ops.conditionTb.seqId = SL.Param.CategorizeSeqId(ops.conditionTb.seqId);
    ops.regVars = regVars;
    ops.rsWin = rsWin;
    
    % Fit models
    mdls = SL.Pop.FitLinearModels(seTb, ops);
    
    % Save result
    disp('Save mdls');
    save(lmPath, 'mdls');
end

