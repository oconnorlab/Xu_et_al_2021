%% 

isAuto = true;
isAuto = false;

% Find files
if isAuto
    dirPath = pwd;
else
    dirPath = MBrowse.Folder('\\OCONNORDATA10\data10\projectData\SeqLick datastore 1\MX2106\SatellitesViewer');
end
seFiles = MBrowse.Dir2Table(fullfile(dirPath, '*se*.mat'));
progFigs = MBrowse.Dir2Table(fullfile(dirPath, '* prog*.png'));


% Find unique sessions
[~, fileNames] = cellfun(@fileparts, seFiles.name, 'Uni', false);
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
    
    % SE file name
    sessTb.sePath{k} = '';
    if ~isempty(seFiles)
        isFile = contains(seFiles.name, sessionId{k});
        if any(isFile)
            sessTb.sePath{k} = fullfile(dirPath, seFiles.name{isFile});
        end
    end
end


%% 

% Choose sessions to plot progress
sessTb.isSelected = false(height(sessTb), 1);

selectedInd = listdlg('PromptString', 'Choose sessions to plot progress:', ...
    'SelectionMode', 'multi', ...
    'ListSize', [300 200], ...
    'ListString', sessTb.sessionId);

sessTb.isSelected(selectedInd) = true;

% Extract data
seArray = SL.SE.LoadSession(sessTb.sePath(sessTb.isSelected));



return

%% 

% Make an animal table
[G, aniTb] = findgroups(sessTb(:,'animalId'));
aniTb.sessionId = splitapply(@(x) {x}, sessTb.sessionId, G);
aniTb.hasSE = splitapply(@(x) {x}, sessTb.hasSE, G);


% Choose animal to plot progress
aniTb.isSelected = false(height(aniTb), 1);

selectedInd = listdlg('PromptString', 'Which animals to plot learning curves:', ...
    'SelectionMode', 'multi', ...
    'ListSize', [300 200], ...
    'ListString', aniTb.animalId);

aniTb.isSelected(selectedInd) = true;


% 
for k = 1 : height(aniTb)
%     % Find missing progress figures
%     aniTb.hasProgFig(k) = ~isempty(progFigs) && any(contains(progFigs.name, aniTb.animalId{k}));
    
    if ~aniTb.isSelected(k)
        continue
    end
    
    % Load the computed
    cachePath = fullfile(mainDir, [aniTb.animalId{k} ' learn.mat']);
    if exist(cachePath, 'file')
        load(cachePath);
    else
        ssCached = struct;
        ssCached.sessionInfo.sessionId = {};
    end
    
    % Select sessions
    sessId = aniTb.sessionId{k}(aniTb.hasSE{k});
    selectedInd = find(strcmp(sessId, setdiff(sessId, ssCached.sessionInfo.sessionId)));
    selectedInd = listdlg('PromptString', 'Include sessions:', ...
        'SelectionMode', 'multi', ...
        'ListSize', [300 200], ...
        'ListString', sessId, ...
        'InitialValue', selectedInd);
    sessId = sessId(selectedInd);
    if isempty(sessId)
        continue
    end
    
    % Compute learning curves
    seArray = SL.SE.LoadSession(cellfun(@(x) fullfile(mainDir, [x '.mat']), sessId, 'Uni', false));
    lcOps = struct;
    lcOps.binSize = [];
    lcOps.analysisNames = {'numTrials', 'ITI', 'impulseLick_L', 'impulseLick_R', ...
        'firstDrive_L', 'firstDrive_R', 'seqDur_L', 'seqDur_R'};
    ss = SL.Behav.ComputeLearningCurves(seArray, lcOps, ssCached);
    
    
    
    
%     save(cachePath, 'ss', 'lcOps');
    
    
    % Plotting
    f = MPlot.Figure(1000+k); clf
    f.WindowState = 'maximized';
    SL.BehavFig.ProgressReview1(ss);
    
    
    
    
    
end

