%% Make and cache seTb for various analyses

% Choose data source and parameters based on analysis
dataSource = SL.Data.FindSessions('fig5_t_lag');


%% Tansform SE and cache seTb

% Load metadata
xlsTb = MBrowse.ReadXls(SL.Data.metadataSheet, 'Si');

% Set up options
ops = SL.Param.Transform;
ops.isMorph = true;
ops.tReslice = -2;
ops.maxReactionTime = 1;
ops.maxEndTime = 8;
ops.alignType = 'seq';
ops.isMatch = true;
ops = SL.Param.FillMatchOptions(ops);

isOverwrite = false;

% Run pipeline
for i = 1 : height(dataSource)
    % Get paths
    seDir = dataSource.folder{i};
    sePath = dataSource.path{i};
    sessionId = dataSource.sessionId{i};
    
    % Time lags
    dt = [-50 -20 -10 -5 0 5 10 20 50]; % in millisecond
    
    clear se
    
    for n = 1 : numel(dt)
        % Make seTb paths
        seTbDirName = ['seq dt_' num2str(dt(n))];
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
        if ~exist('se', 'var')
            se = SL.SE.LoadSession(sePath);
            
            % Add metadata to se
            SL.SE.AddXlsInfo2SE(se, xlsTb);
            
            % Screen units
            if strcmp(se.userData.xlsInfo.area1, 'S1FL')
                se.userData.xlsInfo.area1 = 'S1L';
                disp('Changed xlsInfo.area1 from S1FL to S1L');
            end
            SL.Unit.RemoveOffTargetUnits(se, se.userData.xlsInfo.area);
        end
        
        % Transform SE
        ops.spkLagInSec = dt(n) * 1e-3;
        seTb = SL.SE.Transform(se.Duplicate, ops);
        
        % Save seTb
        disp(['Saving seTb ' sessionId ' in ' seTbDirName]);
        if ~exist(seTbDir, 'dir')
            mkdir(seTbDir);
        end
        save(seTbPath, 'seTb', 'ops');
        disp(' ');
    end
end

