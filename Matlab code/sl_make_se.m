%% Select and check master files

masterPaths = MBrowse.Files([], 'Select master files', {'.mat'});
masterTb = table();

for i = length(masterPaths) : -1 : 1
    disp(masterPaths{i});
    masterObj = matfile(masterPaths{i});
    [~, masterName] = fileparts(masterPaths{i});
    varList = who('-file', masterPaths{i});
    
    masterTb.masterObj{i} = masterObj;
    masterTb.masterName{i} = masterName;
    masterTb.hasSatellites(i) = ismember('satellites_data', varList);
    masterTb.hasIntan(i) = ismember('intan_data', varList);
    masterTb.hasSpike(i) = ismember('spike_data', varList);
    masterTb.hasHsv(i) = ismember('hsv_data', varList);
    masterTb.hasCam(i) = ismember('cam_data', varList);
end

disp(masterTb);


%% Construct MSessionExplorers

% Choose to create new SEs or to update existing ones
answer = questdlg('What to do?', 'MSessionExplorer', ...
	'Create', 'Update', 'Cancel', 'Cancel');

switch answer
    case 'Create'
        seDir = MBrowse.Folder([], 'Select a directory to save SEs');
        sePaths = cell(size(masterPaths));
    case 'Update'
        sePaths = MBrowse.Files([], 'Select SEs to update');
        seDir = fileparts(sePaths{1});
    otherwise
        return;
end


% Loop through master files
seArray = cell(size(masterPaths));

for i = 1 : numel(masterPaths)
    
    masterObj = masterTb.masterObj{i};
    fprintf('%s\n\n', masterTb.masterName{i});
    
    % Construct SE
    if exist(sePaths{i}, 'file')
        load(sePaths{i});
    else
        se = MSessionExplorer();
    end
    
    % Load SatellitesViewer data
    disp('Loading SatellitesViewer data');
    satData = masterObj.satellites_data;
    
    % Process SatellitesViewer data
    disp('Processing SatellitesViewer data');
    SL.Preprocess.SessionInfo2SE(satData, se);
    SL.Preprocess.Satellites2SE(satData, se);
    fprintf('\n');
    
    % Load videography data
    if masterTb.hasHsv(i) && ~ismember('hsv', se.tableNames)
        disp('Loading high-speed video data');
        hsvData = masterObj.hsv_data;
        
        disp('Processing high-speed video data');
        SL.Preprocess.HSV2SE(hsvData, se);
        
        fprintf('\n');
    end
    
    % Load Intan data
    if masterTb.hasIntan(i)
        fprintf('Loading intan data\n');
        intanData = masterObj.intan_data;
        se.userData.intanInfo = intanData.info;
        
        % Process delimiter
        disp('Processing delimiter');
        delimiterData = SL.Preprocess.ComputeDelimiter( ...
            intanData.dig_in_data(:,1), ...
            intanData.info.frequency_parameters.board_dig_in_sample_rate, ...
            'valueFunc', @(x) round(x*1000));
        se.userData.delimiterData = delimiterData;
        trial1 = find(delimiterData.delimiterDur < 2e-3, 1);
%         trialStartTimes = delimiterData.delimiterRiseTime(trial1:trial1+se.numEpochs-1);
        trialStartTimes = delimiterData.delimiterRiseTime;
        fprintf('\n');
        
        % Process ADC signals
        if ~isempty(intanData.adc_data) && ~ismember('adc', se.tableNames)
            disp('Processing ADC signals');
            SL.Preprocess.ADC2SE(intanData, se, trialStartTimes);
            fprintf('\n');
        end
        
        % Process LFP signals
        if ~isempty(intanData.amplifier_data) && ~ismember('LFP', se.tableNames)
            disp('Processing LFP signals');
            SL.Preprocess.LFP2SE(intanData, se, trialStartTimes);
            fprintf('\n');
        end
    end
    
    % Load spike data
    if masterTb.hasSpike(i) && ~ismember('spikeTime', se.tableNames)
        disp('Loading spike data');
        spikeData = masterObj.spike_data;
        
        disp('Processing spike data');
        SL.Preprocess.Spike2SE(spikeData, se, trialStartTimes);
        
        fprintf('\n');
    end
    
    % Set reference time
    if masterTb.hasIntan(i)
        trialMap = se.userData.sessionInfo.intanTrialNum;
        trialStartTimes = SL.Preprocess.MapTrial(trialMap, trialStartTimes);
        se.SetReferenceTime(trialStartTimes);
    else
        se.SetReferenceTime(se.GetReferenceTime('behavTime'));
    end
    
    % Save SE
    disp('Saving SE to disk');
    seArray{i} = se;
    sePaths{i} = fullfile(seDir, [strrep(masterTb.masterName{i}, 'master', 'se') '.mat']);
    save(sePaths{i}, 'se');
    
    fprintf('\n');
end


%% Enrich SEs

% Choose raw SEs
[readPaths, seDir, seNames] = MBrowse.Files([], 'Select source SEs');

% Determine save paths
%   0 - save to the same folder as the raw se
%   1 - replace existing enriched se files in Analysis folder
saveOpt = 0;

savePaths = cell(size(readPaths));
for i = 1 : numel(readPaths)
    seNameRaw = erase(seNames{i}, ' enriched');
    switch saveOpt
        case 0
            savePaths{i} = fullfile(seDir, [seNameRaw ' enriched.mat']);
        case 1
            seSearch = MBrowse.Dir2Table(fullfile(SL.Param.GetAnalysisRoot, '**', [seNames{i} ' enriched.mat']));
            if height(seSearch) == 0
                error('No existing file found');
            elseif height(seSearch) > 1
                error('Found multiple existing files');
            end
            savePaths{i} = fullfile(seSearch.folder{1}, seSearch.name{1});
    end
end

% Processing
for i = 1 : numel(readPaths)
    load(readPaths{i});
    SL.SE.EnrichAll(se);
    save(savePaths{i}, 'se');
end

