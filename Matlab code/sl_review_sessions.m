%% 

isAuto = true;
isAuto = false;

% Find files
if isAuto
    dirPath = pwd;
else
    
    dirPath = MBrowse.Folder('\\OCONNORDATA10\data10\projectData\SeqLick datastore 1\MX2106\SatellitesViewer');
end
logFiles = MBrowse.Dir2Table(fullfile(dirPath, '*.txt'));
seFiles = MBrowse.Dir2Table(fullfile(dirPath, '*se*.mat'));
perfFigs = MBrowse.Dir2Table(fullfile(dirPath, '* perf.png'));
progFigs = MBrowse.Dir2Table(fullfile(dirPath, '* learn.png'));


% Find unique sessions
[~, fileNames] = cellfun(@fileparts, [logFiles.name; seFiles.name], 'Uni', false);
sessionId = cell(size(fileNames));
for k = 1 : numel(fileNames)
    fileNameParts = strsplit(fileNames{k}, ' ');
    sessionId{k} = strjoin(fileNameParts(1:3), ' ');
end
sessionId = unique(sessionId);


% Make a session table
sessTb = table();
sessTb.sessionId = sessionId;

for k = 1 : height(sessTb)
    % Animal ID
    sessionIdParts = strsplit(sessionId{k}, ' ');
    sessTb.animalId{k} = sessionIdParts{1};
    
    % Log file path
    sessTb.logPath{k} = '';
    if ~isempty(logFiles)
        isFile = contains(logFiles.name, sessionId{k});
        if any(isFile)
            sessTb.logPath{k} = fullfile(dirPath, logFiles.name{isFile});
        end
    end
    
    % SE file name
    sessTb.sePath{k} = '';
    if ~isempty(seFiles)
        isFile = contains(seFiles.name, sessionId{k});
        if any(isFile)
            sessTb.sePath{k} = fullfile(dirPath, seFiles.name{isFile});
        end
    end
    
    % Check file availability
    sessTb.hasLog(k) = ~isempty(logFiles) && any(contains(logFiles.name, sessionId{k}));
    sessTb.hasSE(k) = ~isempty(seFiles) && any(contains(seFiles.name, sessionId{k}));
    sessTb.hasPerfFig(k) = ~isempty(perfFigs) && any(contains(perfFigs.name, sessionId{k}));
end


%% Generate SEs

% Choose sessions
sessTb.isSelected = false(size(sessTb.hasSE));

if isAuto
    selectedInd = find(~sessTb.hasSE);
else
    selectedInd = listdlg('PromptString', 'Choose sessions to make (or remake) SE: ', ...
        'SelectionMode', 'multi', ...
        'ListSize', [300 400], ...
        'ListString', sessTb.sessionId, ...
        'InitialValue', find(~sessTb.hasSE));
end
sessTb.isSelected(selectedInd) = true;


% Preprocess each session
for k = find(sessTb.isSelected)'
    % Read txt file
    satData = struct();
    satData.file_path = sessTb.logPath{k};
    satData.txt = Satellites.ReadTxt(satData.file_path);
    
    % Construct and enrich SE
    se = MSessionExplorer();
    SL.Preprocess.SessionInfo2SE(satData, se);
    SL.Preprocess.Satellites2SE(satData, se);
    SL.SE.EnrichAll(se);
    
    % Save SE
    sePath = fullfile(dirPath, [sessTb.sessionId{k} ' se enriched lite.mat']);
    save(sePath, 'se');
    sessTb.sePath{k} = sePath;
    sessTb.hasSE(k) = true;
end


%% Plot session performance

% Choose sessions
sessTb.isSelected = false(size(sessTb.hasSE));

if isAuto
    selectedInd = find(~sessTb.hasPerfFig);
else
    selectedInd = listdlg('PromptString', 'Choose sessions to plot (or re-plot) performance: ', ...
        'SelectionMode', 'multi', ...
        'ListSize', [300 600], ...
        'ListString', sessTb.sessionId, ...
        'InitialValue', find(~sessTb.hasPerfFig));
end

sessTb.isSelected(selectedInd) = true;


% Plot performance for each session
for k = find(sessTb.isSelected)'
    % Load existing SE
    load(sessTb.sePath{k})
    disp(['Loaded ' sessTb.sessionId{k}])
    
    % Plotting
    f = MPlot.Figure(100); clf
    f.WindowState = 'maximized';
    SL.BehavFig.ReviewSession(se);
    
    % Save figure
    print(f, fullfile(dirPath, [sessTb.sessionId{k} ' perf']), '-dpng', '-r0');
end

