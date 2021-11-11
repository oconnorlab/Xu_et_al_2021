%% Make and cache seTb for various analyses

% Choose data source and parameters based on analysis
dataSource = SL.Data.FindSessions(analysisName);

switch analysisName
    case {'fig5_seq_coding', 'fig5_t_lag'}
        fitName = 'seq';
        alignType = fitName;
        
    case 'fig6_iti_coding'
        fitName = 'iti';
        alignType = fitName;
        
    case 'fig7_cons_coding'
        fitName = 'cons';
        alignType = fitName;
        
    case 'figZ_seq_coding'
        fitName = 'seq_zz';
        alignType = fitName;
        
    otherwise
        error('''%s'' is not a valid analysisName', analysisName);
end

if strcmp(analysisName, 'fig5_t_lag')
    dt = [-100 -50 -20 -10 -5 0 5 10 20 50 100]; % in ms
else
    dt = 0;
end


%% Tansform SE and cache seTb

% Load metadata
xlsTb = MBrowse.ReadXls(SL.Data.metadataSheet, 'Si');

% Set up options
ops = SL.Param.Transform;
ops.isMorph = true;
ops.tReslice = -2;
ops.maxReactionTime = 1;
ops.maxEndTime = 8;
ops.alignType = alignType;
ops.isMatch = true;
ops = SL.Param.FillMatchOptions(ops);

isOverwrite = false;

for n = 1 : numel(dt)
    % Set parameters
    ops.spkLagInSec = dt(n) * 1e-3;
    
    % Run pipeline
    seTbDirName = [fitName ' dt_' num2str(dt(n))];
    
    for i = 1 : height(dataSource)
        % Get paths
        seDir = dataSource.folder{i};
        sePath = dataSource.path{i};
        sessionId = dataSource.sessionId{i};
        
        seTbDir = fullfile(seDir, seTbDirName);
        seTbPath = fullfile(seTbDir, ['seTb ' sessionId '.mat']);
        
        % Check seTb file
        if exist(seTbPath, 'file') && ~isOverwrite
            warning('seTb for %s already exists and will not be overwritten', sessionId);
            continue
        else
            disp(['Making seTb for ' sessionId]);
        end
        
        % Load SE
        se = SL.SE.LoadSession(sePath);
        
        % Add metadata from spreadsheet to se
        SL.SE.AddXlsInfo2SE(se, xlsTb);
        
        % Screen units
        if strcmp(se.userData.xlsInfo.area1, 'S1FL')
            se.userData.xlsInfo.area1 = 'S1L';
            disp('Changed xlsInfo.area1 from S1FL to S1L');
        end
        SL.Unit.RemoveOffTargetUnits(se, se.userData.xlsInfo.area);
        
        % Transform SE
        seTb = SL.SE.Transform(se, ops);
        
        % Save seTb
        disp(['Saving seTb ' sessionId ' in ' seTbDirName]);
        if ~exist(seTbDir, 'dir')
            mkdir(seTbDir);
        end
        save(seTbPath, 'seTb', 'ops');
        disp(' ');
    end
end

